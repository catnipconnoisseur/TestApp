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
    
    // MARK: - Language Directive Helper
    
    private static func buildLanguageDirective(for locale: Locale) -> (directive: String, headlineContract: String, descriptionContract: String) {
        let identifier = locale.identifier.lowercased()
        if identifier.hasPrefix("id") {
            let directive = """
            LANGUAGE DIRECTIVE (STRICT MANDATORY REQUIREMENT):
            - The user's active application language is BAHASA INDONESIA.
            - You MUST generate your ENTIRE response (both HEADLINE and DESCRIPTION) strictly in natural, fluent Bahasa Indonesia.
            - NEVER respond in English, even if the user's question was phrased in English, and even if printed text or labels on the object are in English.
            - Translate any necessary visual descriptions naturally into Indonesian (e.g. "Uang Rp50.000", "Botol Minum", "Kancing di kanan atas").
            """
            let headline = "[Jawaban singkat 1 sampai 4 kata dalam Bahasa Indonesia, contoh: \"Uang Rp50.000\", \"Botol Minum\", \"Tombol Kanan Atas\"]"
            let desc = "[1 sampai 3 kalimat jelas dan natural dalam Bahasa Indonesia yang menjawab langsung pertanyaan pengguna]"
            return (directive, headline, desc)
        } else {
            let languageName = locale.localizedString(forIdentifier: locale.identifier) ?? "English"
            let directive = """
            LANGUAGE DIRECTIVE:
            - The user's active application language is \(languageName.uppercased()).
            - You MUST generate your entire response (both HEADLINE and DESCRIPTION) in natural \(languageName).
            - Do not switch languages unless explicitly requested by the user.
            """
            let headline = "[Direct answer or main idea in 1 to 4 words, e.g. \"Rp50,000 Banknote\", \"Hydration Bottle\", \"Top-Right Button\"]"
            let desc = "[1 to 3 clear, natural sentences directly answering the user's question, providing relevant reasoning, practical guidance, or appropriate uncertainty]"
            return (directive, headline, desc)
        }
    }
    
    // MARK: - Structured Plain-Text Accessibility Prompts
    
    static var defaultPrompt: String {
        buildDefaultAnalysisPrompt()
    }
    
    /// Constructs the default visual identification prompt, with optional on-device sensor hints, deformation resilience, and language localization.
    static func buildDefaultAnalysisPrompt(onDeviceHints: [String] = [], locale: Locale = Locale(identifier: "en-US")) -> String {
        let (languageDirective, headlineContract, descriptionContract) = buildLanguageDirective(for: locale)
        
        var hintsSection = ""
        if !onDeviceHints.isEmpty {
            hintsSection = """
            
            ON-DEVICE SENSOR OBSERVATIONS (for cross-modal grounding):
            \(onDeviceHints.map { "- \($0)" }.joined(separator: "\n"))
            """
        }
        
        return """
        You are an intelligent visual accessibility assistant for a user who is blind or visually impaired. Identify and describe the main object in front of the camera.
        \(hintsSection)
        Return plain text only without any Markdown syntax (do not use asterisks, bold markers, bullet points, or empty placeholders like ****).
        
        \(languageDirective)
        
        PHYSICAL DEFORMATION & CURRENCY RECOGNITION RULES:
        1. PHYSICAL DEFORMATION RESILIENCE: Objects may be wrinkled, folded, creased, bent, held at an angle, partially occluded, or under uneven lighting/shadows. Physical deformation does NOT change an object's identity. Analyze the entire visual form and salient details rather than requiring a perfectly flat or centered view.
        2. CURRENCY & BANKNOTE RECOGNITION (especially Indonesian Rupiah): Actively synthesize all visible visual cues to identify the currency and exact denomination:
           - Printed numerals and text (e.g. 100000, 50000, 20000, 10000, 5000, 2000, 1000, "Bank Indonesia", "Rupiah").
           - Dominant color scheme: Red/Pink (Rp100,000), Blue (Rp50,000), Green (Rp20,000), Purple (Rp10,000), Brown/Tan (Rp5,000), Grey (Rp2,000), Yellow-Green (Rp1,000).
           - Prominent portraits, emblems (Garuda Pancasila), and decorative layouts.
           - Even if the banknote is crumpled, folded, or angled, determine the exact denomination from the combination of color, portrait, and visible numbers.
           - If the denomination cannot be determined with reasonable confidence (e.g. note is too heavily obscured or severely torn), state that it is an Indonesian banknote but the denomination is unclear.

        OUTPUT CONTRACT:
        Provide your answer strictly in two labeled sections:

        HEADLINE: \(headlineContract)
        DESCRIPTION: \(descriptionContract)
        """
    }
    
    /// Constructs a structured, grounded multimodal prompt for an explicit spoken user question, tailored for an accessibility assistant with language localization.
    static func buildVoiceQuestionPrompt(
        userQuestion: String,
        previousContext: String? = nil,
        onDeviceHints: [String] = [],
        locale: Locale = Locale(identifier: "en-US")
    ) -> String {
        let (languageDirective, headlineContract, descriptionContract) = buildLanguageDirective(for: locale)
        
        var contextSection = ""
        if let context = previousContext, !context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            contextSection = """
            
            ACTIVE SCENE CONTEXT:
            Previously identified in this scene: "\(context)"
            (Use this context to resolve pronouns like "it", "this", or "that", but answer the new question directly without re-identifying the object from scratch.)
            """
        }
        
        var hintsSection = ""
        if !onDeviceHints.isEmpty {
            hintsSection = """
            
            ON-DEVICE SENSOR OBSERVATIONS (for cross-modal grounding):
            \(onDeviceHints.map { "- \($0)" }.joined(separator: "\n"))
            """
        }
        
        return """
        You are an intelligent visual accessibility assistant explaining physical visual surroundings to a person who is blind or visually impaired.
        Analyze the provided image to answer the user's specific question directly, naturally, and concisely using progressive disclosure.
        \(contextSection)\(hintsSection)
        USER'S QUESTION:
        "\(userQuestion)"

        \(languageDirective)

        PROGRESSIVE DISCLOSURE & REASONING RULES:
        1. PHYSICAL DEFORMATION RESILIENCE: Objects may be wrinkled, folded, creased, bent, held at an angle, partially occluded, or under uneven lighting/shadows. Physical deformation does NOT change an object's identity. Analyze the entire visual form and salient details rather than requiring a perfectly flat or centered view.
        2. BANKNOTE & MONEY ROBUSTNESS (especially Indonesian Rupiah):
           - Actively synthesize all visible cues: numerals (100000, 50000, 20000, 10000, 5000, 2000, 1000), color schemes (Red = 100k, Blue = 50k, Green = 20k, Purple = 10k, Brown = 5k, Grey = 2k, Yellow-Green = 1k), portraits, and text.
           - If the banknote is folded, wrinkled, or angled, determine the exact denomination from the combination of color and visible partial features.
           - If the denomination genuinely cannot be determined, clearly state that it is an Indonesian banknote with denomination unclear.
        3. ANSWER ONLY WHAT IS ASKED: Do not answer questions the user did not ask. Do not volunteer unsolicited visual details (color, material, shape, dimensions, OCR, background) unless specifically requested or essential for safety/understanding. The user is in control and will ask follow-up questions if they need more detail.
        4. INTENT-CONTROLLED INFORMATION SCOPE:
           - Identification ("What is this?"): Provide the concise name and at most one short functional note.
           - Purpose / Function ("What is this used for?"): State its practical use directly.
           - Appearance ("What does it look like?"): Describe physical form, material, and key visible features concretely.
           - Color ("What color is it?"): State the colors directly.
           - Material ("What is it made of?"): State the visible material with honest certainty.
           - Label / Text / OCR ("What's written on it?"): Read the relevant visible text directly without unrelated object commentary.
           - Location / Spatial ("Where is the button?"): Use clear relative positions (top-right, near the bottom, left, center, beside).
           - Specific Feature ("Does it have a handle?"): Answer directly with yes/no and supporting visible evidence.
           - Safety / Practical ("Can I put hot water in it?"): Combine visible material with general knowledge and honest caution.
           - Unanswerable ("What is the exact price?"): Clearly state that the information cannot be determined from the image alone. Never invent prices, dates, model numbers, or hidden properties.
           - Comprehensive Description Exception ("Describe everything you see"): ONLY when the user explicitly requests full visual details, provide a broader, well-organized overview of the main subject and its immediate surroundings.
        5. NATURAL HUMAN PHRASING: Speak like a helpful person explaining something to a friend. NEVER use robotic filler phrases.
        6. CUMULATIVE CONVERSATION: If the object was already identified in the active context, do NOT repeat the identification. Answer the new question directly.
        7. GROUNDED REASONING & UNCERTAINTY: Distinguish what is clearly visible from reasonable inference. Never claim certainty that the image does not support.
        8. PLAIN TEXT ONLY: No Markdown formatting (no asterisks **, no hashes #, no bullets, no empty placeholders ****).

        OUTPUT CONTRACT:
        Provide your response strictly in two clearly labeled plain-text sections:

        HEADLINE: \(headlineContract)
        DESCRIPTION: \(descriptionContract)
        """
    }
    
    /// Constructs a structured prompt for follow-up conversational turns about the active physical scene.
    static func buildFollowUpVoicePrompt(
        userQuestion: String,
        onDeviceHints: [String] = [],
        locale: Locale = Locale(identifier: "en-US")
    ) -> String {
        let (languageDirective, headlineContract, descriptionContract) = buildLanguageDirective(for: locale)
        
        var hintsSection = ""
        if !onDeviceHints.isEmpty {
            hintsSection = """
            
            ON-DEVICE SENSOR OBSERVATIONS:
            \(onDeviceHints.map { "- \($0)" }.joined(separator: "\n"))
            """
        }
        
        return """
        You are an intelligent visual accessibility assistant continuing an active conversation about the same physical scene.
        Answer the user's follow-up question directly, naturally, and concisely using progressive disclosure.
        \(hintsSection)
        FOLLOW-UP QUESTION:
        "\(userQuestion)"

        \(languageDirective)

        FOLLOW-UP RULES:
        1. Resolve references (like "it", "this", "that", "its color", "what is it used for", "read the text") using the active conversation history.
        2. Answer ONLY what is asked in this turn. Do not repeat the initial identification from scratch.
        3. Maintain physical deformation & currency recognition robustness.
        4. Return plain text only without any Markdown syntax (no asterisks **, no hashes #, no bullets, no empty placeholders ****).

        OUTPUT CONTRACT:
        HEADLINE: \(headlineContract)
        DESCRIPTION: \(descriptionContract)
        """
    }
    
    // MARK: - Execution
    
    /// Sends a single JPEG frame to the Gemini multimodal endpoint and returns the natural language analysis.
    func analyzeImage(
        jpegData: Data,
        prompt: String = defaultPrompt,
        apiKey: String
    ) async -> MultimodalResult {
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
        return await executeGeminiRequest(payload: payload, apiKey: apiKey)
    }
    
    /// Performs scene-anchored multi-turn conversational visual reasoning.
    func analyzeMultiTurn(
        turns: [ConversationTurn],
        currentQuestion: String,
        currentImage: Data?,
        onDeviceHints: [String] = [],
        locale: Locale = Locale(identifier: "en-US"),
        apiKey: String
    ) async -> MultimodalResult {
        var contentsArray: [[String: Any]] = []
        
        if turns.isEmpty {
            // Turn 1: Single turn request
            let prompt = Self.buildVoiceQuestionPrompt(
                userQuestion: currentQuestion,
                onDeviceHints: onDeviceHints,
                locale: locale
            )
            var parts: [[String: Any]] = [["text": prompt]]
            if let jpegData = currentImage {
                parts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": jpegData.base64EncodedString()
                    ]
                ])
            }
            contentsArray.append([
                "role": "user",
                "parts": parts
            ])
        } else {
            // Multi-Turn: Reconstruct conversation history with alternating user/model turns
            for (index, turn) in turns.enumerated() {
                // User turn
                let userPrompt: String
                if index == 0 {
                    userPrompt = Self.buildVoiceQuestionPrompt(
                        userQuestion: turn.question,
                        onDeviceHints: onDeviceHints,
                        locale: locale
                    )
                } else {
                    userPrompt = turn.question
                }
                
                contentsArray.append([
                    "role": "user",
                    "parts": [["text": userPrompt]]
                ])
                
                // Model turn
                contentsArray.append([
                    "role": "model",
                    "parts": [["text": turn.rawAIResponse]]
                ])
            }
            
            // Current user turn
            let currentPrompt = Self.buildFollowUpVoicePrompt(
                userQuestion: currentQuestion,
                onDeviceHints: onDeviceHints,
                locale: locale
            )
            var currentParts: [[String: Any]] = [["text": currentPrompt]]
            if let jpegData = currentImage {
                currentParts.append([
                    "inline_data": [
                        "mime_type": "image/jpeg",
                        "data": jpegData.base64EncodedString()
                    ]
                ])
            }
            contentsArray.append([
                "role": "user",
                "parts": currentParts
            ])
        }
        
        let payload: [String: Any] = [
            "contents": contentsArray
        ]
        
        return await executeGeminiRequest(payload: payload, apiKey: apiKey)
    }
    
    // MARK: - Private Unified Request Execution
    
    private func executeGeminiRequest(
        payload: [String: Any],
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
