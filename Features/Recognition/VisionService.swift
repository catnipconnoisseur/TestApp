import CoreImage
import Foundation
import Vision

/// Executes built-in Apple Vision framework requests on incoming pixel buffers.
final class VisionService: @unchecked Sendable {
    
    // MARK: - Properties
    
    private let visionQueue = DispatchQueue(label: "com.testapp.vision.processingQueue", qos: .userInitiated)
    private var isProcessing = false
    
    // MARK: - Public Interface
    
    /// Processes a pixel buffer and returns the raw classification, OCR, and feature print observations.
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
            textRequest.recognitionLanguages = ["id-ID", "en-US"]
            textRequest.customWords = [
                "Rupiah", "Bank Indonesia", "Indonesia",
                "100000", "50000", "20000", "10000", "5000", "2000", "1000",
                "Emisi", "Negara Kesatuan", "Gubernur", "Direktur"
            ]
            
            // 3. Built-in Feature Print Embedding Request (Visual Fingerprint)
            let featurePrintRequest = VNGenerateImageFeaturePrintRequest()
            
            do {
                try requestHandler.perform([classifyRequest, textRequest, featurePrintRequest])
                
                // Parse Image Classification observations
                if let observations = classifyRequest.results {
                    result.totalClassificationCount = observations.count
                    
                    let topItems = observations
                        .prefix(3)
                        .map { RecognitionResult.ClassificationItem(identifier: $0.identifier, confidence: $0.confidence) }
                    
                    result.classifications = Array(topItems)
                }
                
                // Parse OCR Text observations (capture up to 15 items across entire frame)
                if let textObservations = textRequest.results {
                    let topTexts = textObservations
                        .compactMap { observation -> RecognitionResult.RecognizedTextItem? in
                            guard let candidate = observation.topCandidates(1).first else { return nil }
                            return RecognitionResult.RecognizedTextItem(text: candidate.string, confidence: candidate.confidence)
                        }
                        .prefix(15)
                    
                    result.recognizedTexts = Array(topTexts)
                }
                
                // Parse Feature Print observation
                if let fpObservations = featurePrintRequest.results as? [VNFeaturePrintObservation],
                   let firstFP = fpObservations.first {
                    result.featurePrint = firstFP
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
