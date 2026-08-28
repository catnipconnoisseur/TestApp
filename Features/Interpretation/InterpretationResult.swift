import Foundation

/// Explicit operational state for the automatic visual understanding engine.
enum AnalysisState: String, Equatable, Sendable {
    case observing      // Fast continuous Vision + OCR scanning
    case stabilizing    // Consistent candidate detected; accumulating dwell stability
    case analyzing      // Stable dwell reached; multimodal snapshot being reasoned over
    case displaying     // AI reasoning synthesized and presented; awaiting scene change
}

/// Defines the evidential certainty level determined by the interpretation engine.
enum EvidenceConfidence: String, Equatable, Sendable {
    case strong         // Multiple concordant sources or clear high-quality evidence
    case moderate       // High-level category confirmed or single reliable source without fine details
    case weak           // Fragmented text, low-confidence classification, or ambiguous features
    case conflicting    // Direct contradiction between Vision/OCR and Multimodal reasoning
    case insufficient   // Obscured, dark, or unrecognizable frame
}

/// Identifies the technical sources that contributed to the interpretation.
enum EvidenceSource: String, Equatable, Sendable, Identifiable {
    var id: String { rawValue }
    
    case onDeviceVision = "Vision"
    case onDeviceOCR = "OCR"
    case multimodal = "Multimodal AI"
}

/// Represents the high-level semantic interpretation synthesized from raw AI evidence.
struct InterpretationResult: Equatable, Sendable {
    /// Concise primary headline suitable for quick scanning and screen readers (e.g. "Galangal (Lengkuas)")
    let primaryHeadline: String
    
    /// Full, rich substantive natural-language multimodal analysis or on-device explanation
    let detailedDescription: String?
    
    /// Evidential confidence assessment
    let confidence: EvidenceConfidence
    
    /// Specific cautionary guidance if uncertainty or conflict exists
    let cautionaryNote: String?
    
    /// Sources that contributed to this interpretation
    let contributingSources: [EvidenceSource]
    
    /// Whether the interpretation represents a specific object/denomination or a broad category
    let isSpecificIdentification: Bool
    
    /// Timestamp when this interpretation was synthesized
    let timestamp: Date
    
    /// Indicates whether on-device evidence is ambiguous or non-specific, warranting deeper multimodal reasoning
    var requiresDeeperReasoning: Bool {
        // 1. Strong, specific on-device evidence needs no cloud multimodal request
        if isSpecificIdentification && confidence == .strong {
            return false
        }
        // 2. Insufficient or dark input should not waste API requests
        if confidence == .insufficient {
            return false
        }
        // 3. Active conflicts should be resolved by user repositioning, not infinite retries
        if confidence == .conflicting {
            return false
        }
        // 4. Request deeper reasoning for broad classifications or unconfirmed denominations
        return true
    }
    
    // MARK: - Initial / Idle State
    
    static let initial = InterpretationResult(
        primaryHeadline: "Awaiting visual input...",
        detailedDescription: "Point camera steadily at an object or banknote to begin automatic visual understanding.",
        confidence: .insufficient,
        cautionaryNote: nil,
        contributingSources: [],
        isSpecificIdentification: false,
        timestamp: Date()
    )
}
