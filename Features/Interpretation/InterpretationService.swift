import Foundation
import Vision

/// Holds snapshot properties of the last successfully analyzed visual scene.
struct AnalyzedSceneReference: Equatable, Sendable {
    let dominantClassification: String?
    let ocrTextFingerprint: String
    let featurePrint: VNFeaturePrintObservation?
    let analyzedAt: Date
    
    init(
        dominantClassification: String?,
        ocrTextFingerprint: String,
        featurePrint: VNFeaturePrintObservation?,
        analyzedAt: Date = Date()
    ) {
        self.dominantClassification = dominantClassification
        self.ocrTextFingerprint = ocrTextFingerprint
        self.featurePrint = featurePrint
        self.analyzedAt = analyzedAt
    }
    
    static func == (lhs: AnalyzedSceneReference, rhs: AnalyzedSceneReference) -> Bool {
        lhs.dominantClassification == rhs.dominantClassification &&
        lhs.ocrTextFingerprint == rhs.ocrTextFingerprint &&
        lhs.analyzedAt == rhs.analyzedAt
    }
}

/// Synthesizes raw visual signals from on-device Vision, OCR, and cloud Multimodal AI into cohesive, accessible interpretations.
final class InterpretationService: @unchecked Sendable {
    
    // MARK: - Configuration Constants
    
    /// Default continuous observation duration before a visual candidate is deemed stable.
    static let defaultDwellThreshold: TimeInterval = 0.7
    
    /// Smoothing window size for on-device Vision classifications.
    private let smoothingWindowSize = 5
    
    // MARK: - Thread-Safe State Buffers
    
    private var recentClassifications: [String] = []
    private var currentCandidateIdentifier: String?
    private var candidateFirstObservedAt: Date?
    private var lastObservedWithDataAt: Date?
    private let lock = NSLock()
    
    // MARK: - Indonesian Currency Validation Helper
    
    private let validRupiahDenominations: [String: String] = [
        // 100,000 Rupiah (Red / Soekarno-Hatta)
        "100000": "Rp100,000",
        "100.000": "Rp100,000",
        "100,000": "Rp100,000",
        "100 000": "Rp100,000",
        "100k": "Rp100,000",
        "100rb": "Rp100,000",
        "100 rb": "Rp100,000",
        "seratus ribu": "Rp100,000",
        "soekarno": "Rp100,000",
        "hatta": "Rp100,000",
        
        // 50,000 Rupiah (Blue / Djuanda)
        "50000": "Rp50,000",
        "50.000": "Rp50,000",
        "50,000": "Rp50,000",
        "50 000": "Rp50,000",
        "50k": "Rp50,000",
        "50rb": "Rp50,000",
        "50 rb": "Rp50,000",
        "lima puluh ribu": "Rp50,000",
        "djuanda": "Rp50,000",
        
        // 20,000 Rupiah (Green / Sam Ratulangi)
        "20000": "Rp20,000",
        "20.000": "Rp20,000",
        "20,000": "Rp20,000",
        "20 000": "Rp20,000",
        "20k": "Rp20,000",
        "20rb": "Rp20,000",
        "20 rb": "Rp20,000",
        "dua puluh ribu": "Rp20,000",
        "ratulangi": "Rp20,000",
        
        // 10,000 Rupiah (Purple / Frans Kaisiepo)
        "10000": "Rp10,000",
        "10.000": "Rp10,000",
        "10,000": "Rp10,000",
        "10 000": "Rp10,000",
        "10k": "Rp10,000",
        "10rb": "Rp10,000",
        "10 rb": "Rp10,000",
        "sepuluh ribu": "Rp10,000",
        "kaisiepo": "Rp10,000",
        
        // 5,000 Rupiah (Brown / Idham Chalid)
        "5000": "Rp5,000",
        "5.000": "Rp5,000",
        "5,000": "Rp5,000",
        "5 000": "Rp5,000",
        "5k": "Rp5,000",
        "5rb": "Rp5,000",
        "5 rb": "Rp5,000",
        "lima ribu": "Rp5,000",
        "idham chalid": "Rp5,000",
        
        // 2,000 Rupiah (Grey / Mohammad Hoesni Thamrin)
        "2000": "Rp2,000",
        "2.000": "Rp2,000",
        "2,000": "Rp2,000",
        "2 000": "Rp2,000",
        "2k": "Rp2,000",
        "2rb": "Rp2,000",
        "2 rb": "Rp2,000",
        "dua ribu": "Rp2,000",
        "hoesni thamrin": "Rp2,000",
        "thamrin": "Rp2,000",
        
        // 1,000 Rupiah (Yellow-Green / Tjut Meutia)
        "1000": "Rp1,000",
        "1.000": "Rp1,000",
        "1,000": "Rp1,000",
        "1 000": "Rp1,000",
        "1k": "Rp1,000",
        "1rb": "Rp1,000",
        "1 rb": "Rp1,000",
        "seribu": "Rp1,000",
        "meutia": "Rp1,000"
    ]
    
    // MARK: - Multi-Signal Scene Divergence Evaluation
    
    /// Computes a multi-signal divergence score (0.0 to 1.0) between the current frame and the reference scene.
    func computeSceneDivergence(current: RecognitionResult, reference: AnalyzedSceneReference) -> (score: Float, reason: String?) {
        var divergence: Float = 0.0
        var reasons: [String] = []
        
        // 1. OCR Text Divergence (Weight: 0.5)
        let curOCR = current.combinedText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let refOCR = reference.ocrTextFingerprint.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if curOCR != refOCR {
            divergence += 0.5
            reasons.append("OCR text changed ('\(refOCR)' → '\(curOCR)')")
        }
        
        // 2. Classification Divergence (Weight: 0.3)
        if let curClass = current.topClassification?.identifier, let refClass = reference.dominantClassification {
            if curClass != refClass {
                divergence += 0.3
                reasons.append("Classification changed (\(refClass) → \(curClass))")
            }
        }
        
        // 3. Visual Feature Print Embedding Distance (Weight: 0.5)
        if let curFP = current.featurePrint, let refFP = reference.featurePrint {
            var distance: Float = 0.0
            do {
                try curFP.computeDistance(&distance, to: refFP)
                if distance > SceneStabilityConfiguration.featurePrintDistanceThreshold {
                    divergence += 0.5
                    reasons.append("Visual feature distance: \(String(format: "%.2f", distance))")
                }
            } catch {
                // Fallback without feature distance
            }
        }
        
        let finalScore = min(divergence, 1.0)
        let reasonString = reasons.isEmpty ? nil : reasons.joined(separator: ", ")
        return (finalScore, reasonString)
    }
    
    // MARK: - Dwell & Stability Evaluation
    
    /// Evaluates whether the candidate visual signal has remained stable for the configured dwell duration.
    func evaluateStability(
        for recognition: RecognitionResult,
        dwellThreshold: TimeInterval = defaultDwellThreshold
    ) -> (candidate: String?, isStable: Bool, dwellDuration: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        
        guard recognition.hasObservations else {
            if let lastObserved = lastObservedWithDataAt, now.timeIntervalSince(lastObserved) > 0.5 {
                currentCandidateIdentifier = nil
                candidateFirstObservedAt = nil
            }
            return (nil, false, 0)
        }
        
        lastObservedWithDataAt = now
        
        let candidate = getSmoothedIdentifier(for: recognition) ?? (recognition.recognizedTexts.isEmpty ? "object" : "text_document")
        
        if let current = currentCandidateIdentifier {
            let duration = now.timeIntervalSince(candidateFirstObservedAt ?? now)
            let isStable = duration >= dwellThreshold
            return (current, isStable, duration)
        } else {
            currentCandidateIdentifier = candidate
            candidateFirstObservedAt = now
            return (candidate, false, 0)
        }
    }
    
    /// Resets stability state.
    func resetStability() {
        lock.lock()
        defer { lock.unlock() }
        currentCandidateIdentifier = nil
        candidateFirstObservedAt = nil
        lastObservedWithDataAt = nil
        recentClassifications.removeAll()
    }
    
    // MARK: - Evidence Synthesis
    
    /// Interprets the combined evidence from on-device Vision/OCR and optional Multimodal reasoning with locale awareness.
    func interpret(
        recognition: RecognitionResult,
        multimodal: MultimodalService.MultimodalResult? = nil,
        locale: Locale = Locale(identifier: "en-US")
    ) -> InterpretationResult {
        let topIdentifier = updateSmoothedClassification(from: recognition)
        let ocrText = recognition.combinedText
        let detectedRupiah = extractRupiahDenomination(from: ocrText)
        
        // 1. Multimodal Evidence Available
        if let multimodal = multimodal, multimodal.status == .success, !multimodal.text.isEmpty {
            return interpretWithMultimodal(
                multimodalText: multimodal.text,
                topVisionIdentifier: topIdentifier,
                detectedRupiah: detectedRupiah,
                ocrText: ocrText,
                locale: locale
            )
        }
        
        // 2. On-Device Vision + OCR Only (Continuous Viewfinder)
        return interpretOnDeviceOnly(
            topVisionIdentifier: topIdentifier,
            detectedRupiah: detectedRupiah,
            ocrText: ocrText,
            recognition: recognition,
            locale: locale
        )
    }
    
    // MARK: - Internal Synthesis Logic
    
    /// Synthesizes Multimodal reasoning with local on-device signals, producing clean plain text without Markdown syntax in the selected language.
    private func interpretWithMultimodal(
        multimodalText: String,
        topVisionIdentifier: String?,
        detectedRupiah: String?,
        ocrText: String,
        locale: Locale = Locale(identifier: "en-US")
    ) -> InterpretationResult {
        var sources: [EvidenceSource] = [.multimodal]
        if topVisionIdentifier != nil { sources.append(.onDeviceVision) }
        if !ocrText.isEmpty { sources.append(.onDeviceOCR) }
        
        let isIndonesian = locale.identifier.hasPrefix("id")
        
        // Parse structured plain-text response (HEADLINE: and DESCRIPTION:)
        let (parsedHeadline, parsedDescription) = parseStructuredMultimodalText(multimodalText)
        let lowerDesc = parsedDescription.lowercased()
        let lowerHeadline = parsedHeadline.lowercased()
        let isCurrencyContext = lowerDesc.contains("banknote") || lowerDesc.contains("rupiah") ||
            lowerDesc.contains("currency") || lowerDesc.contains("indonesian") ||
            lowerDesc.contains("uang") || lowerDesc.contains("duit") ||
            lowerHeadline.contains("banknote") || lowerHeadline.contains("rupiah") ||
            lowerHeadline.contains("uang") || lowerHeadline.contains("rp") || lowerHeadline.contains("money") ||
            topVisionIdentifier?.lowercased().contains("currency") == true ||
            topVisionIdentifier?.lowercased().contains("money") == true
        
        // Scenario A: Indonesian Banknote / Currency
        if isCurrencyContext {
            let confirmedDenomination = extractRupiahDenomination(from: parsedHeadline)
                ?? extractRupiahDenomination(from: parsedDescription)
                ?? detectedRupiah
            let denominationUnclear = lowerDesc.contains("unclear") ||
                lowerDesc.contains("cannot determine") ||
                lowerDesc.contains("unable to determine") ||
                lowerDesc.contains("uncertain") ||
                lowerDesc.contains("tidak jelas") ||
                lowerDesc.contains("belum jelas") ||
                lowerDesc.contains("tidak dapat menentukan") ||
                lowerHeadline.contains("unclear") ||
                lowerHeadline.contains("belum jelas")
            
            if let denomination = confirmedDenomination, !denominationUnclear {
                let headline: String
                if isIndonesian {
                    if parsedHeadline.lowercased().contains("uang") || parsedHeadline.lowercased().contains("rp") {
                        headline = parsedHeadline
                    } else {
                        headline = "Uang Kertas \(denomination)"
                    }
                } else {
                    headline = "\(denomination) Indonesian Banknote"
                }
                
                return InterpretationResult(
                    primaryHeadline: headline,
                    detailedDescription: parsedDescription,
                    confidence: .strong,
                    cautionaryNote: nil,
                    contributingSources: sources,
                    isSpecificIdentification: true,
                    timestamp: Date()
                )
            } else {
                let headline = isIndonesian ? "Uang Kertas (Pecahan Belum Jelas)" : "Indonesian Banknote (Denomination Unclear)"
                let caution = isIndonesian
                    ? "Pecahan spesifik belum dapat dipastikan. Coba balik atau ratakan uang di bawah pencahayaan yang baik."
                    : "Specific denomination could not be confirmed. Try turning or flattening the note under good light."
                
                return InterpretationResult(
                    primaryHeadline: headline,
                    detailedDescription: parsedDescription,
                    confidence: .moderate,
                    cautionaryNote: caution,
                    contributingSources: sources,
                    isSpecificIdentification: false,
                    timestamp: Date()
                )
            }
        }
        
        // Scenario B: Conflict Detection
        if let vision = topVisionIdentifier?.lowercased() {
            if (vision == "machine" || vision == "computer") && (lowerDesc.contains("rhizome") || lowerDesc.contains("spice") || lowerDesc.contains("fruit") || lowerDesc.contains("plant") || lowerDesc.contains("rimpang") || lowerDesc.contains("rempah")) {
                let headline = isIndonesian ? "Objek Kurang Jelas (Indikasi Bertentangan)" : "Ambiguous Object (Conflicting Evidence)"
                let caution = isIndonesian ? "Terdeteksi indikasi visual yang bertentangan. Posisikan ulang kamera dan analisis kembali." : "Conflicting visual indicators detected. Reposition camera and re-analyze."
                return InterpretationResult(
                    primaryHeadline: headline,
                    detailedDescription: parsedDescription,
                    confidence: .conflicting,
                    cautionaryNote: caution,
                    contributingSources: sources,
                    isSpecificIdentification: false,
                    timestamp: Date()
                )
            }
        }
        
        // Scenario C: General Object / Spice / Produce Semantic Identification
        let isSpecific = !lowerDesc.contains("uncertain") && !lowerDesc.contains("unable to identify") && !lowerDesc.contains("not completely certain") && !lowerDesc.contains("tidak pasti") && !lowerDesc.contains("tidak dapat mengidentifikasi")
        
        return InterpretationResult(
            primaryHeadline: parsedHeadline,
            detailedDescription: parsedDescription,
            confidence: isSpecific ? .strong : .moderate,
            cautionaryNote: isSpecific ? nil : (isIndonesian ? "Identifikasi memiliki alternatif yang masuk akal." : "Identification has plausible alternatives."),
            contributingSources: sources,
            isSpecificIdentification: isSpecific,
            timestamp: Date()
        )
    }
    
    /// Synthesizes fast continuous on-device Vision and OCR signals.
    private func interpretOnDeviceOnly(
        topVisionIdentifier: String?,
        detectedRupiah: String?,
        ocrText: String,
        recognition: RecognitionResult,
        locale: Locale = Locale(identifier: "en-US")
    ) -> InterpretationResult {
        let isIndonesian = locale.identifier.hasPrefix("id")
        
        // Scenario A: Currency identified with verified printed denomination
        if let vision = topVisionIdentifier?.lowercased(), vision.contains("currency") || vision.contains("money") {
            if let rupiah = detectedRupiah {
                return InterpretationResult(
                    primaryHeadline: isIndonesian ? "Uang Kertas \(rupiah)" : "\(rupiah) Indonesian Banknote",
                    detailedDescription: isIndonesian ? "Terverifikasi dari nominal cetak '\(rupiah)' pada kertas uang." : "Verified by printed denomination '\(rupiah)' on currency paper.",
                    confidence: .strong,
                    cautionaryNote: nil,
                    contributingSources: [.onDeviceVision, .onDeviceOCR],
                    isSpecificIdentification: true,
                    timestamp: Date()
                )
            } else {
                return InterpretationResult(
                    primaryHeadline: isIndonesian ? "Uang Kertas (Pecahan Belum Jelas)" : "Currency / Banknote (Denomination Unclear)",
                    detailedDescription: isIndonesian ? "Terdeteksi kertas uang. Tahan mikrofon untuk tanya detail AI." : "Identified as currency paper. Tap Analyze for AI visual details.",
                    confidence: .moderate,
                    cautionaryNote: isIndonesian ? "Teks nominal belum terlihat jelas." : "Denomination text not yet visible in frame.",
                    contributingSources: [.onDeviceVision],
                    isSpecificIdentification: false,
                    timestamp: Date()
                )
            }
        }
        
        // Scenario B: OCR detected verified currency text
        if let rupiah = detectedRupiah, ocrText.lowercased().contains("bank indonesia") || ocrText.lowercased().contains("indonesia") {
            return InterpretationResult(
                primaryHeadline: isIndonesian ? "Uang Kertas \(rupiah)" : "\(rupiah) Indonesian Banknote",
                detailedDescription: isIndonesian ? "Mengenali teks cetak Bank Indonesia dengan nominal '\(rupiah)'." : "Recognized printed Bank Indonesia text with denomination '\(rupiah)'.",
                confidence: .moderate,
                cautionaryNote: nil,
                contributingSources: [.onDeviceOCR],
                isSpecificIdentification: true,
                timestamp: Date()
            )
        }
        
        // Scenario C: Document or Text-Heavy Item
        if let vision = topVisionIdentifier?.lowercased(), vision.contains("document") || vision.contains("paper") {
            if !ocrText.isEmpty {
                return InterpretationResult(
                    primaryHeadline: isIndonesian ? "Dokumen Berisi Teks" : "Document with Text",
                    detailedDescription: isIndonesian ? "Teks terlihat: \"\(truncate(ocrText, limit: 120))\"" : "Visible text: \"\(truncate(ocrText, limit: 120))\"",
                    confidence: .moderate,
                    cautionaryNote: nil,
                    contributingSources: [.onDeviceVision, .onDeviceOCR],
                    isSpecificIdentification: false,
                    timestamp: Date()
                )
            }
        }
        
        // Scenario D: Broad Object Classification without Text
        if let vision = topVisionIdentifier, !vision.isEmpty {
            let formattedTitle = formatTaxonomyTitle(vision)
            return InterpretationResult(
                primaryHeadline: formattedTitle,
                detailedDescription: isIndonesian ? "Kategori umum terdeteksi di perangkat. Tahan mikrofon untuk detail AI." : "Broad category detected on-device. Tap Analyze for AI visual details.",
                confidence: .moderate,
                cautionaryNote: nil,
                contributingSources: [.onDeviceVision],
                isSpecificIdentification: false,
                timestamp: Date()
            )
        }
        
        // Scenario E: Insufficient / Empty Input
        return InterpretationResult.initial
    }
    
    // MARK: - Structured Response & Markdown Sanitization Helpers
    
    /// Parses structured HEADLINE: and DESCRIPTION: tags, ensuring clean plain text without Markdown syntax.
    private func parseStructuredMultimodalText(_ raw: String) -> (headline: String, description: String) {
        let sanitized = sanitizeMarkdownArtifacts(raw)
        
        // Check for HEADLINE: and DESCRIPTION: tags
        if let headlineRange = sanitized.range(of: "HEADLINE:", options: .caseInsensitive),
           let descRange = sanitized.range(of: "DESCRIPTION:", options: .caseInsensitive) {
            
            let headlinePart = sanitized[headlineRange.upperBound..<descRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let descPart = sanitized[descRange.upperBound...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            if !headlinePart.isEmpty && !descPart.isEmpty {
                return (cleanHeadlineString(headlinePart), descPart)
            }
        }
        
        // Fallback for unstructured responses
        let firstSentence = extractFirstSentence(from: sanitized)
        let cleanTitle = cleanHeadlineString(firstSentence)
        return (cleanTitle, sanitized)
    }
    
    /// Defensively removes Markdown artifacts (asterisks, bullet points, headers, empty placeholders) while preserving numbers and legitimate characters.
    private func sanitizeMarkdownArtifacts(_ text: String) -> String {
        var cleaned = text
        
        // 1. Remove empty placeholder asterisks like **** or ***
        cleaned = cleaned.replacingOccurrences(of: "\\*{3,}", with: "", options: .regularExpression)
        
        // 2. Strip bold/italic markdown asterisks like **word** -> word
        cleaned = cleaned.replacingOccurrences(of: "\\*\\*", with: "")
        cleaned = cleaned.replacingOccurrences(of: "(?<!\\w)\\*(?!\\w)", with: "", options: .regularExpression)
        
        // 3. Remove Markdown header syntax (e.g. ### Title -> Title)
        cleaned = cleaned.replacingOccurrences(of: "(?m)^#{1,6}\\s*", with: "", options: .regularExpression)
        
        // 4. Remove Markdown bullet markers (e.g. * item -> item)
        cleaned = cleaned.replacingOccurrences(of: "(?m)^\\s*[-*+]\\s+", with: "", options: .regularExpression)
        
        // 5. Clean excessive spaces
        cleaned = cleaned.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func cleanHeadlineString(_ raw: String) -> String {
        var cleaned = raw
        let prefixesToStrip = [
            "based on the image, this is an ", "based on the image, this is a ", "based on the image, this is ",
            "based on the image, it is an ", "based on the image, it is a ", "based on the image, it is ",
            "based on the image, ", "upon analyzing the image, ", "upon analyzing, ",
            "the main object visible in the image is a ", "the main object visible in the image is an ", "the main object visible in the image is ",
            "the object visible in the image is a ", "the object visible in the image is an ", "the object visible in the image is ",
            "the image shows an ", "the image shows a ", "the image shows ",
            "this appears to be an ", "this appears to be a ", "this appears to be ",
            "this is an ", "this is a ", "this is ",
            "it appears to be an ", "it appears to be a ", "it appears to be ",
            "it is an ", "it is a ", "it is ",
            "it's an ", "it's a ", "it's ",
            "i can see an ", "i can see a ", "i can see ",
            "berdasarkan gambar, ini adalah sebuah ", "berdasarkan gambar, ini adalah seorang ", "berdasarkan gambar, ini adalah ",
            "berdasarkan gambar, ini merupakan ", "berdasarkan gambar, ini ", "berdasarkan gambar, ",
            "menurut gambar, ini adalah ", "menurut gambar, ", "gambar ini menunjukkan sebuah ", "gambar ini menunjukkan seorang ", "gambar ini menunjukkan ",
            "ini adalah sebuah ", "ini adalah seorang ", "ini adalah ", "ini merupakan sebuah ", "ini merupakan ",
            "terlihat sebuah ", "terlihat seorang ", "terlihat ", "objek ini adalah sebuah ", "objek ini adalah ",
            "objek utama adalah sebuah ", "objek utama adalah ", "saya melihat sebuah ", "saya melihat "
        ]
        for prefix in prefixesToStrip {
            if cleaned.lowercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        if let firstChar = cleaned.first {
            cleaned = firstChar.uppercased() + String(cleaned.dropFirst())
        }
        return truncate(cleaned, limit: 45)
    }
    
    // MARK: - Temporal Smoothing Helpers
    
    private func getSmoothedIdentifier(for recognition: RecognitionResult) -> String? {
        if let top = recognition.topClassification?.identifier {
            recentClassifications.append(top)
            if recentClassifications.count > smoothingWindowSize {
                recentClassifications.removeFirst()
            }
        }
        guard !recentClassifications.isEmpty else { return nil }
        let counts = recentClassifications.reduce(into: [:]) { counts, name in
            counts[name, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }
    
    private func updateSmoothedClassification(from recognition: RecognitionResult) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return getSmoothedIdentifier(for: recognition)
    }
    
    // MARK: - String Helpers
    
    private func extractRupiahDenomination(from text: String) -> String? {
        let rawLower = text.lowercased()
        let cleaned = rawLower
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "rp.", with: "rp ")
            .replacingOccurrences(of: "idr", with: "rp")
        
        // 1. Direct dictionary match with longest keys first
        let sortedKeys = validRupiahDenominations.keys.sorted(by: { $0.count > $1.count })
        for key in sortedKeys {
            if cleaned.contains(key) {
                return validRupiahDenominations[key]
            }
        }
        
        // 2. Normalized numerical digits check (e.g. "rp 50000", "50 000 rupiah")
        let digitsOnly = cleaned.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if digitsOnly.contains("100000") { return "Rp100,000" }
        if digitsOnly.contains("50000") { return "Rp50,000" }
        if digitsOnly.contains("20000") { return "Rp20,000" }
        if digitsOnly.contains("10000") { return "Rp10,000" }
        if digitsOnly.contains("5000") { return "Rp5,000" }
        if digitsOnly.contains("2000") { return "Rp2,000" }
        if digitsOnly.contains("1000") { return "Rp1,000" }
        
        // 3. Color-based currency synthesis when currency context is strong
        if cleaned.contains("banknote") || cleaned.contains("rupiah") || cleaned.contains("currency") {
            if cleaned.contains("red") || cleaned.contains("pink") || cleaned.contains("merah") {
                return "Rp100,000"
            }
            if cleaned.contains("blue") || cleaned.contains("biru") {
                return "Rp50,000"
            }
            if cleaned.contains("green") || cleaned.contains("hijau") {
                return "Rp20,000"
            }
            if cleaned.contains("purple") || cleaned.contains("violet") || cleaned.contains("ungu") {
                return "Rp10,000"
            }
            if cleaned.contains("brown") || cleaned.contains("cokelat") || cleaned.contains("tan") {
                return "Rp5,000"
            }
            if cleaned.contains("grey") || cleaned.contains("gray") || cleaned.contains("abu-abu") || cleaned.contains("abu abu") {
                return "Rp2,000"
            }
            if cleaned.contains("olive") || cleaned.contains("yellow-green") {
                return "Rp1,000"
            }
        }
        
        return nil
    }
    
    private func extractFirstSentence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let dotIndex = trimmed.firstIndex(of: ".") {
            return String(trimmed[..<dotIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return truncate(trimmed, limit: 60)
    }
    
    private func formatTaxonomyTitle(_ raw: String) -> String {
        let words = raw.replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { $0.capitalized }
        return words.joined(separator: " ")
    }
    
    private func truncate(_ text: String, limit: Int) -> String {
        if text.count <= limit { return text }
        let index = text.index(text.startIndex, offsetBy: limit)
        return String(text[..<index]) + "..."
    }
}
