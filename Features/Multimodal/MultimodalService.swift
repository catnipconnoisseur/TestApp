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
    Identify and describe the main object visible in this image for an accessibility assistant.
    Return plain text only without any Markdown syntax (do not use asterisks, bold markers, bullet points, or empty placeholders like ****).
    Provide your answer strictly in two labeled sections:

    HEADLINE: <A concise 1 to 4 word name of the object, e.g. "Shaker Bottle", "Rp50,000 Indonesian Banknote", "Galangal">
    DESCRIPTION: <A concise 2 to 3 sentence explanation describing key visual characteristics, shape, texture, color, and plausible alternatives if ambiguous.>
    """
    
    /// Constructs a structured, grounded multimodal prompt for an explicit spoken user question.
    static func buildVoiceQuestionPrompt(userQuestion: String) -> String {
        return """
        You are an intelligent visual accessibility assistant. Analyze the provided image to answer the user's specific spoken question.

        USER'S QUESTION:
        "\(userQuestion)"

        CRITICAL INSTRUCTIONS:
        1. Answer the user's specific question directly based strictly on what is visible in the image.
        2. Provide your response in two clearly labeled plain-text sections:
        HEADLINE: [Concise 1 to 4 word summary or main answer, e.g. "Cooking Spice", "Rp50,000", "Price Unavailable"]
        DESCRIPTION: [1 to 3 clear, plain-text sentences explaining the answer and visual justification]
        3. If the question asks for information that cannot be determined from the image (such as hidden price, internal composition, or invisible dates), state clearly that it cannot be determined from the image alone without guessing.
        4. Return plain text ONLY. Never output Markdown formatting (no asterisks **, no hashes #, no bullets, no empty **** placeholders).
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
