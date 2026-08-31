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
    You are an intelligent visual accessibility assistant for a user who may be blind or visually impaired. Identify and describe the main object visible in this image.
    Return plain text only without any Markdown syntax (do not use asterisks, bold markers, bullet points, or empty placeholders like ****).
    Provide your answer strictly in two labeled sections:

    HEADLINE: <A concise 1 to 4 word name of the object or main finding, e.g. "Shaker Bottle", "Rp50,000 Indonesian Banknote", "Galangal">
    DESCRIPTION: <A concise 2 to 3 sentence explanation describing key visual characteristics, shape, texture, color, and functional purpose or plausible alternatives if ambiguous.>
    """
    
    /// Constructs a structured, grounded multimodal prompt for an explicit spoken user question, following an accessibility-first 4-level reasoning hierarchy.
    static func buildVoiceQuestionPrompt(userQuestion: String, previousContext: String? = nil) -> String {
        var contextSection = ""
        if let context = previousContext, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextSection = """
            
            ACTIVE SCENE CONTEXT:
            Previous observation in this scene: "\(context)"
            (Use this context if the user's question refers to "it", "this", "that", or asks a follow-up, but answer the new question directly without repeating previous text.)
            """
        }
        
        return """
        You are an intelligent visual accessibility assistant for a user who may be blind or visually impaired.
        Analyze the provided image to answer the user's specific question directly, concisely, and practically.
        \(contextSection)
        USER'S QUESTION:
        "\(userQuestion)"

        EVIDENCE & REASONING HIERARCHY:
        1. Direct Visual Observation: Use clearly supported visible evidence (materials, shapes, labels, printed text, colors, markings, physical features).
        2. Strong Functional Inference: Draw reasonable conclusions about the object's purpose, design, or practical function directly answering what was asked.
        3. Relevant General Knowledge: Apply practical world knowledge when relevant to answer the question (e.g. typical uses, safety considerations for materials like plastics or electronics). Distinguish general knowledge from what is visibly verified, and communicate appropriate caution (e.g. "Generally...", "Unless specifically labeled as heat-resistant, it is safer to...").
        4. Genuine Unknowns: Only state that information cannot be determined when visible evidence and general knowledge genuinely cannot answer it (e.g. exact hidden price, invisible expiration date, internal mechanism). Do NOT use "cannot be determined from the image" as a generic refusal for ordinary functional or safety questions.

        ANSWERING RULES:
        - ANSWER THE ACTUAL QUESTION FIRST: The HEADLINE and the first sentence of the DESCRIPTION must directly address what the user asked (e.g. function, safety, text, denomination), NOT merely repeat the generic object category.
        - SAFETY QUESTIONS: Prioritize user safety. If an object appears to be ordinary plastic or unmarked material, provide a cautious, practical recommendation (e.g., recommend cold/room-temperature liquids unless heat-safe markings are visible) rather than refusing to answer or claiming unfounded certainty.
        - AVOID REPETITION: Do not waste response space repeating the object name if it was already identified. Answer the new information requested.
        - PRESERVE APPROPRIATE UNCERTAINTY: Use nuanced phrasing ("This appears to be...", "Generally...", "I wouldn't assume... unless labeled") instead of unwarranted absolute certainty or unhelpful total refusal.
        - PLAIN TEXT ONLY: Never output Markdown formatting (no asterisks **, no hashes #, no bullets, no empty placeholders ****).

        OUTPUT CONTRACT:
        Provide your response strictly in two clearly labeled plain-text sections:

        HEADLINE: [Direct answer or concise main idea in 1 to 4 words, e.g. "Carrying Drinks", "Rp50,000", "Cold Liquids Recommended", "Price Not Visible"]
        DESCRIPTION: [1 to 3 clear, plain-text sentences answering the question directly, providing relevant reasoning, practical guidance, and appropriate uncertainty]
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
