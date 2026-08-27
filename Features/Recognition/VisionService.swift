import CoreImage
import Foundation
import Vision

/// Executes built-in Apple Vision framework requests on incoming pixel buffers.
final class VisionService: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let visionQueue = DispatchQueue(label: "com.testapp.vision.processingQueue", qos: .userInitiated)
    private var isProcessing = false
    
    // MARK: - Public Interface
    
    /// Processes a pixel buffer and returns the raw classification & OCR observation results.
    func processFrame(_ pixelBuffer: CVPixelBuffer, completion: @escaping (RecognitionResult) -> Void) {
        visionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Frame throttling: skip if currently evaluating a previous Vision request
            guard !self.isProcessing else { return }
            self.isProcessing = true
            
            let startTime = CFAbsoluteTimeGetCurrent()
            var result = RecognitionResult()
            
            defer {
                self.isProcessing = false
            }
            
            // Camera sensor output is in landscape right by default on iOS, matching portrait device orientation
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
            
            // 1. Built-in Image Classification Request
            let classifyRequest = VNClassifyImageRequest()
            
            // 2. Built-in Text Recognition Request (OCR)
            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = false
            
            do {
                try requestHandler.perform([classifyRequest, textRequest])
                
                // Parse Image Classification observations
                if let observations = classifyRequest.results {
                    result.totalClassificationCount = observations.count
                    
                    // Take top 3 predictions directly sorted by confidence without invalid precision filtering
                    let topItems = observations
                        .prefix(3)
                        .map { RecognitionResult.ClassificationItem(identifier: $0.identifier, confidence: $0.confidence) }
                    
                    result.classifications = Array(topItems)
                }
                
                // Parse OCR Text observations
                if let textObservations = textRequest.results {
                    let topTexts = textObservations
                        .compactMap { observation -> RecognitionResult.RecognizedTextItem? in
                            guard let candidate = observation.topCandidates(1).first else { return nil }
                            return RecognitionResult.RecognizedTextItem(text: candidate.string, confidence: candidate.confidence)
                        }
                        .prefix(5)
                    
                    result.recognizedTexts = Array(topTexts)
                }
                
                let endTime = CFAbsoluteTimeGetCurrent()
                result.processingTimeMs = (endTime - startTime) * 1000.0
                
                DispatchQueue.main.async {
                    completion(result)
                }
            } catch {
                let endTime = CFAbsoluteTimeGetCurrent()
                result.processingTimeMs = (endTime - startTime) * 1000.0
                result.errorMessage = error.localizedDescription
                
                print("[VisionService] Request error: \(error.localizedDescription)")
                
                DispatchQueue.main.async {
                    completion(result)
                }
            }
        }
    }
}
