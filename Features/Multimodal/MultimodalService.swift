import Foundation
import UIKit

/// Executes on-demand multimodal visual reasoning requests via native URLSession.
final class MultimodalService: Sendable {
    
    // MARK: - Types
    
    enum ResponseStatus: Equatable {
        case idle
        case success
        case rateLimited(Int?) // HTTP 429 with optional Retry-After seconds
        case authenticationError(Int) // HTTP 401 / 403
        case serverError(Int) // HTTP 5xx
        case networkError(String)
        case parsingError(String)
        case error(String)
        
        var isRateLimited: Bool {
            if case .rateLimited = self { return true }
            return false
        }
        
        var displayTelemetryTitle: String {
            switch self {
            case .idle: return "Idle"
            case .success: return "Success (200 OK)"
            case .rateLimited(let retrySecs):
                if let s = retrySecs { return "Rate Limited (429, retry: \(s)s)" }
                return "Rate Limited (HTTP 429)"
            case .authenticationError(let code): return "Auth Failed (HTTP \(code))"
            case .serverError(let code): return "Server Error (HTTP \(code))"
            case .networkError(let err): return "Network: \(err)"
            case .parsingError(let err): return "Parsing: \(err)"
            case .error(let msg): return msg
            }
        }
    }
    
    struct MultimodalResult: Equatable {
        var text: String = ""
        var latencyMs: Double = 0.0
        var status: ResponseStatus = .idle
    }
    
    // MARK: - Structured Plain-Text Accessibility Prompts
    
    static let defaultPrompt = """
    You are an intelligent visual accessibility assistant for a user who is blind or visually impaired. Identify and describe the main object in front of the camera.
    Return plain text only without any Markdown syntax (do not use asterisks, bold markers, bullet points, or empty placeholders like ****).
    Provide your answer strictly in two labeled sections:

    HEADLINE: <A concise 1 to 4 word name of the object or main finding, e.g. "Shaker Bottle", "Rp50,000 Banknote", "Galangal">
    DESCRIPTION: <A concise 2 to 3 sentence natural explanation describing what it is, its purpose, key visual features, and plausible alternatives if ambiguous.>
    """
    
    /// Constructs a structured, grounded multimodal prompt for an explicit spoken user question, tailored for an accessibility assistant.
    static func buildVoiceQuestionPrompt(userQuestion: String, previousContext: String? = nil) -> String {
        var contextSection = ""
        if let context = previousContext, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextSection = """
            
            ACTIVE SCENE CONTEXT:
            Previously identified in this scene: "\(context)"
            (Use this context to resolve pronouns like "it", "this", or "that", but answer the new question directly without re-identifying the object from scratch.)
            """
        }
        
        return """
        You are an intelligent visual accessibility assistant explaining physical visual surroundings to a person who is blind or visually impaired.
        Analyze the provided image to answer the user's specific question directly, naturally, and concisely using progressive disclosure.
        \(contextSection)
        USER'S QUESTION:
        "\(userQuestion)"

        PROGRESSIVE DISCLOSURE & ANSWER SCOPE RULES:
        1. ANSWER ONLY WHAT IS ASKED: Do not answer questions the user did not ask. Do not volunteer unsolicited visual details (color, material, shape, dimensions, OCR, background) unless specifically requested or essential for safety/understanding. The user is in control and will ask follow-up questions if they need more detail.
        2. INTENT-CONTROLLED INFORMATION SCOPE:
           - Identification ("What is this?"): Provide the concise name ("It's a hydration bottle.") and at most one short functional note. Do NOT describe color, shape, material, or size.
           - Purpose / Function ("What is this used for?"): State its practical use directly ("It's designed for carrying water and other beverages."). Do not describe appearance or color.
           - Appearance ("What does it look like?"): Describe physical form, material, and key visible features concretely ("It's tall and cylindrical, with a translucent body and a black lid.").
           - Color ("What color is it?"): State the colors directly ("The body is clear, and the lid is black.").
           - Material ("What is it made of?"): State the visible material with honest certainty ("It appears to be made of plastic." or "It looks like plastic, but I can't confirm the exact material from the image.").
           - Label / Text / OCR ("What's written on it?"): Read the relevant visible text directly without unrelated object commentary.
           - Location / Spatial ("Where is the button?"): Use clear relative positions (top-right, near the bottom, left, center, beside).
           - Specific Feature ("Does it have a handle?"): Answer directly with yes/no and supporting visible evidence ("Yes, there's a handle on the side." or "No, I don't see a handle.").
           - Safety / Practical ("Can I put hot water in it?"): Combine visible material with general knowledge and honest caution ("It looks like an ordinary plastic bottle. Unless it's specifically labeled heat-safe, I'd avoid hot water because ordinary plastics may not be designed for hot liquids.").
           - Unanswerable ("What is the exact price?"): Clearly state that the information cannot be determined from the image alone. Never invent prices, dates, model numbers, or hidden properties.
           - Comprehensive Description Exception ("Describe everything you see"): ONLY when the user explicitly requests full visual details, provide a broader, well-organized overview of the main subject and its immediate surroundings.
        3. NATURAL HUMAN PHRASING: Speak like a helpful person explaining something to a friend. NEVER use robotic filler phrases like:
           - "The image shows..."
           - "The main object visible in the image is..."
           - "Based on the image..."
           - "Upon analyzing the image..."
           - "I can see that..."
           - "Object classification:"
        4. CUMULATIVE CONVERSATION: If the object was already identified in the active context, do NOT repeat the identification. Answer the new question directly (e.g. "It's used for..." rather than "The hydration bottle is...").
        5. GROUNDED REASONING & UNCERTAINTY: Distinguish what is clearly visible from reasonable inference ("It appears to be...", "Generally...", "Unless labeled otherwise..."). Never claim certainty that the image does not support.
        6. PLAIN TEXT ONLY: No Markdown formatting (no asterisks **, no hashes #, no bullets, no empty placeholders ****).

        OUTPUT CONTRACT:
        Provide your response strictly in two clearly labeled plain-text sections:

        HEADLINE: [Direct answer or main idea in 1 to 4 words, e.g. "Carrying Drinks", "Rp50,000", "Top-Right Button", "Clear And Black", "Price Not Visible"]
        DESCRIPTION: [1 to 3 clear, natural sentences directly answering the user's question, providing relevant reasoning, practical guidance, or appropriate uncertainty]
        """
    }
    
    // MARK: - Execution
    
    /// Sends a single JPEG frame to the Gemini multimodal endpoint and returns the natural language analysis.
    func analyzeImage(
        jpegData: Data,
        prompt: String = defaultPrompt,
        apiKey: String
    ) async -> MultimodalResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedKey.isEmpty else {
            return MultimodalResult(
                text: "API Key not configured. Please tap the key icon to configure your API key.",
                latencyMs: 0.0,
                status: .authenticationError(401)
            )
        }
        
        // Active multimodal model: gemini-2.5-flash
        let endpointString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(cleanedKey)"
        guard let url = URL(string: endpointString) else {
            return MultimodalResult(
                text: "Invalid endpoint URL configuration.",
                latencyMs: 0.0,
                status: .error("Invalid URL")
            )
        }
        
        let base64Image = jpegData.base64EncodedString()
        
        let payload: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt],
                        [
                            "inline_data": [
                                "mime_type": "image/jpeg",
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15.0
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            let (data, response) = try await URLSession.shared.data(for: request)
            let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            
            guard let httpResponse = response as? HTTPURLResponse else {
                return MultimodalResult(
                    text: "Unable to analyze image (invalid server response).",
                    latencyMs: durationMs,
                    status: .error("Invalid server response")
                )
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
                    return MultimodalResult(
                        text: "Multimodal AI service is temporarily rate limited. Using on-device vision.",
                        latencyMs: durationMs,
                        status: .rateLimited(retryAfter)
                    )
                } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    return MultimodalResult(
                        text: "Authentication failed. Please verify your API key.",
                        latencyMs: durationMs,
                        status: .authenticationError(httpResponse.statusCode)
                    )
                } else if httpResponse.statusCode >= 500 {
                    return MultimodalResult(
                        text: "Remote server error (\(httpResponse.statusCode)).",
                        latencyMs: durationMs,
                        status: .serverError(httpResponse.statusCode)
                    )
                } else {
                    return MultimodalResult(
                        text: "Service returned status \(httpResponse.statusCode).",
                        latencyMs: durationMs,
                        status: .error("HTTP \(httpResponse.statusCode)")
                    )
                }
            }
            
            // Parse Gemini response structure
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let firstCandidate = candidates.first,
                  let content = firstCandidate["content"] as? [String: Any],
                  let parts = content["parts"] as? [[String: Any]],
                  let firstPart = parts.first,
                  let responseText = firstPart["text"] as? String else {
                return MultimodalResult(
                    text: "Unable to parse model response.",
                    latencyMs: durationMs,
                    status: .parsingError("Malformed response JSON")
                )
            }
            
            return MultimodalResult(
                text: responseText.trimmingCharacters(in: .whitespacesAndNewlines),
                latencyMs: durationMs,
                status: .success
            )
            
        } catch {
            let durationMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            return MultimodalResult(
                text: "Unable to analyze image due to a network connection error.",
                latencyMs: durationMs,
                status: .networkError(error.localizedDescription)
            )
        }
    }
}
