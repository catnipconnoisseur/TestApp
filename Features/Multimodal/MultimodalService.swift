import Foundation
import UIKit

/// Executes on-demand multimodal visual reasoning requests via native URLSession.
final class MultimodalService: Sendable {
    
    // MARK: - Types
    
    enum ResponseStatus: Equatable {
        case idle
        case success
        case error(String)
    }
    
    struct MultimodalResult: Equatable {
        var text: String = ""
        var latencyMs: Double = 0.0
        var status: ResponseStatus = .idle
    }
    
    // MARK: - Structured Plain-Text Accessibility Prompt
    
    static let defaultPrompt = """
    Identify and describe the main object visible in this image for an accessibility assistant.
    Return plain text only without any Markdown syntax (do not use asterisks, bold markers, bullet points, or empty placeholders like ****).
    Provide your answer strictly in two labeled sections:

    HEADLINE: <A concise 1 to 4 word name of the object, e.g. "Shaker Bottle", "Rp50,000 Indonesian Banknote", "Galangal">
    DESCRIPTION: <A concise 2 to 3 sentence explanation describing key visual characteristics, shape, texture, color, and plausible alternatives if ambiguous.>
    """
    
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
                status: .error("Missing API Key")
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
                let userFriendlyError: String
                switch httpResponse.statusCode {
                case 404:
                    userFriendlyError = "Multimodal service configuration error (404 Not Found)."
                case 400:
                    userFriendlyError = "Invalid request format (400 Bad Request)."
                case 403:
                    userFriendlyError = "Authentication failed (403 Forbidden). Please verify your API key."
                case 429:
                    userFriendlyError = "Rate limit reached (429). Please wait a moment."
                case 500...599:
                    userFriendlyError = "Remote server error (\(httpResponse.statusCode)). Please try again."
                default:
                    userFriendlyError = "Service returned status \(httpResponse.statusCode)."
                }
                
                return MultimodalResult(
                    text: "Unable to analyze image: \(userFriendlyError)",
                    latencyMs: durationMs,
                    status: .error("HTTP \(httpResponse.statusCode)")
                )
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
                    status: .error("Parsing failure")
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
                status: .error("Network error")
            )
        }
    }
}
