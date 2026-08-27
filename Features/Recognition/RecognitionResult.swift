import Foundation

/// Represents the raw visual observations produced by Apple's Vision framework.
/// Kept intentionally generic so it can represent banknotes, spices, and everyday objects.
struct RecognitionResult: Equatable {
    
    // MARK: - Classification
    
    /// Top image classification identifiers and their associated confidence scores (0.0 to 1.0)
    struct ClassificationItem: Equatable, Identifiable {
        var id: String { identifier }
        let identifier: String
        let confidence: Float
    }
    
    // MARK: - OCR Text
    
    /// Text recognized in the frame along with confidence
    struct RecognizedTextItem: Equatable, Identifiable {
        var id: String { text }
        let text: String
        let confidence: Float
    }
    
    // MARK: - Properties
    
    var classifications: [ClassificationItem] = []
    var totalClassificationCount: Int = 0
    var recognizedTexts: [RecognizedTextItem] = []
    var errorMessage: String? = nil
    var processingTimeMs: Double = 0.0
    var timestamp: Date = Date()
    
    // MARK: - Computed Summaries
    
    /// Top classification item if available
    var topClassification: ClassificationItem? {
        classifications.first
    }
    
    /// Combined recognized text string
    var combinedText: String {
        recognizedTexts.map { $0.text }.joined(separator: ", ")
    }
    
    /// Indicates whether any observations or text were made
    var hasObservations: Bool {
        !classifications.isEmpty || !recognizedTexts.isEmpty
    }
}
