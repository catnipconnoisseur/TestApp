import AVFoundation
import SwiftUI
import Vision

// MARK: - UIKit Preview View Bridge

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

// MARK: - Explicit Operational State

enum VisualUnderstandingState: String, Equatable {
    case observing              // Live camera scanning; awaiting initial stable framing
    case stabilizing            // Target object detected; holding steady for 0.7s
    case analyzing              // Frame captured; Gemini request in-flight
    case resultLocked           // Analysis result displayed; protected from frame overwrites
    case possibleSceneChange    // Divergence detected; confirmation window running (0.35s)
    case sceneChangeConfirmed   // Change verified; clearing old result and restarting cycle
}

// MARK: - SwiftUI Camera View (Multi-Signal Automatic Visual Understanding Engine)

struct CameraView: View {
    @State private var cameraManager = CameraManager()
    @State private var multimodalService = MultimodalService()
    private let interpretationService = InterpretationService()
    
    // Concrete Timing & Divergence Parameters
    private let dwellRequirementSeconds: TimeInterval = 0.70
    private let sceneChangeConfirmationSeconds: TimeInterval = 0.35
    private let autoRequestCooldown: TimeInterval = 2.0
    private let divergenceThreshold: Float = 0.50
    
    // Explicit Operational State Machine
    @State private var operationalState: VisualUnderstandingState = .observing
    
    // Reference Scene Snapshot & Divergence Tracking
    @State private var lastAnalyzedScene: AnalyzedSceneReference?
    @State private var sceneDivergenceStartTime: Date?
    @State private var observationStartTime: Date?
    @State private var lastVisualObservationTime: Date = Date()
    @State private var isRequestInFlight = false
    @State private var lastRequestTimestamp: Date = .distantPast
    
    // Displayed Interpretation State (Single Source of Truth)
    @State private var displayedInterpretation: InterpretationResult = .initial
    
    // UI Sheets & Configuration
    @State private var showAPIKeySheet = false
    @State private var apiKeyInput = MultimodalConfig.apiKey
    @State private var showRawTelemetry = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch cameraManager.status {
            case .ready:
                CameraPreviewRepresentable(session: cameraManager.captureSession)
                    .ignoresSafeArea()
                    .accessibilityLabel("Live camera viewfinder")
                    .accessibilityHint("Point camera at objects or banknotes to capture visual input.")
                
                // Bottom Interpretation and Status Overlay (Zero Manual Buttons)
                VStack(spacing: 8) {
                    Spacer()
                    
                    // Subtle Status Indicator (Only during stabilizing / analyzing / scene change)
                    if operationalState == .stabilizing || operationalState == .analyzing || operationalState == .possibleSceneChange || operationalState == .sceneChangeConfirmed {
                        stateStatusIndicator
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    // Primary Semantic Interpretation Decision Card (Prominently Displays Full Multimodal Analysis)
                    interpretationCard(interpretation: displayedInterpretation)
                }
                .ignoresSafeArea(edges: .bottom)
                
            case .unauthorized:
                unauthorizedView
                
            case .unavailable:
                unavailableView
                
            case .failed(let message):
                errorView(message: message)
                
            case .unconfigured:
                ProgressView("Connecting Camera...")
                    .foregroundStyle(.white)
            }
            
            // Top Controls Overlay
            VStack {
                HStack {
                    Button {
                        cameraManager.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(16)
                    }
                    .accessibilityLabel("Close camera")
                    .accessibilityHint("Returns to the home screen")
                    
                    Spacer()
                    
                    // Toggle Raw Telemetry Details
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showRawTelemetry.toggle()
                        }
                    } label: {
                        Image(systemName: showRawTelemetry ? "info.circle.fill" : "info.circle")
                            .font(.system(size: 22))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(16)
                    }
                    .accessibilityLabel("Toggle raw technical telemetry")
                    
                    // Local API Key Configuration Trigger
                    Button {
                        apiKeyInput = MultimodalConfig.apiKey
                        showAPIKeySheet = true
                    } label: {
                        Image(systemName: MultimodalConfig.hasConfiguredKey ? "key.fill" : "key.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(16)
                    }
                    .accessibilityLabel(MultimodalConfig.hasConfiguredKey ? "Configure API Key" : "Set API Key (Required for Multimodal)")
                    .accessibilityHint("Opens sheet to configure local API key")
                }
                Spacer()
            }
        }
        .onAppear {
            cameraManager.requestAccessAndSetup()
        }
        .onDisappear {
            cameraManager.stopSession()
            resetAutomaticCycle()
        }
        .sheet(isPresented: $showAPIKeySheet) {
            apiKeyConfigurationView
        }
        .onChange(of: cameraManager.latestResult) { _, newResult in
            handleIncomingVisionFrame(newResult)
        }
    }
    
    // MARK: - Multi-Signal Scene Change & Automatic Engine
    
    private func handleIncomingVisionFrame(_ recognition: RecognitionResult) {
        let now = Date()
        let hasVisuals = recognition.hasObservations
        
        // 1. Empty Scene Invalidation: Camera moved into empty space for > 0.6s
        if !hasVisuals {
            if now.timeIntervalSince(lastVisualObservationTime) > 0.6 {
                if operationalState != .observing {
                    print("[SCENE] Scene cleared / camera moved into empty space. Resetting to OBSERVING.")
                    resetAutomaticCycle()
                }
            }
            return
        }
        
        lastVisualObservationTime = now
        
        // 2. State: RESULT_LOCKED — Evaluate Multi-Signal Scene Divergence
        if operationalState == .resultLocked, let reference = lastAnalyzedScene {
            let (divergence, reason) = interpretationService.computeSceneDivergence(current: recognition, reference: reference)
            
            if divergence >= divergenceThreshold {
                if sceneDivergenceStartTime == nil {
                    sceneDivergenceStartTime = now
                    print("[SCENE] Possible scene change detected. Reason: \(reason ?? "visual divergence"). Starting \(sceneChangeConfirmationSeconds)s confirmation.")
                }
                
                let divergenceDuration = now.timeIntervalSince(sceneDivergenceStartTime ?? now)
                
                if divergenceDuration >= sceneChangeConfirmationSeconds {
                    print("[SCENE] Scene change CONFIRMED after \(String(format: "%.2f", divergenceDuration))s. Clearing previous result and stabilizing new scene.")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        operationalState = .sceneChangeConfirmed
                        lastAnalyzedScene = nil
                        sceneDivergenceStartTime = nil
                        observationStartTime = now
                        displayedInterpretation = interpretationService.interpret(recognition: recognition)
                    }
                    return
                } else {
                    if operationalState != .possibleSceneChange {
                        operationalState = .possibleSceneChange
                    }
                    return
                }
            } else {
                // Divergence dropped back below threshold (user returned to same object / minor camera tremor)
                if sceneDivergenceStartTime != nil {
                    sceneDivergenceStartTime = nil
                    if operationalState != .resultLocked {
                        operationalState = .resultLocked
                    }
                }
                return // Result remains locked on screen; continuous Vision frames do NOT overwrite card
            }
        }
        
        // 3. State: OBSERVING / STABILIZING / SCENE_CHANGE_CONFIRMED — Accumulate Dwell Stability
        if observationStartTime == nil {
            observationStartTime = now
        }
        
        let dwellDuration = now.timeIntervalSince(observationStartTime ?? now)
        
        // 4. State: Stabilizing (accumulating towards 0.70s dwell)
        if dwellDuration < dwellRequirementSeconds {
            if operationalState == .observing || operationalState == .sceneChangeConfirmed {
                withAnimation(.easeInOut(duration: 0.15)) {
                    operationalState = .stabilizing
                }
            }
            // Display fast continuous on-device interpretation while stabilizing
            if operationalState == .stabilizing {
                displayedInterpretation = interpretationService.interpret(recognition: recognition)
            }
            return
        }
        
        // 5. State: Stabilizing -> Analyzing (Dwell Threshold Reached)
        guard !isRequestInFlight else { return }
        guard now.timeIntervalSince(lastRequestTimestamp) >= autoRequestCooldown else { return }
        
        guard MultimodalConfig.hasConfiguredKey else {
            print("[SCENE] API key not configured. Multimodal request suppressed.")
            displayedInterpretation = interpretationService.interpret(recognition: recognition)
            return
        }
        
        print("[SCENE] Stability threshold reached (dwell: \(String(format: "%.2f", dwellDuration))s). Capturing frame.")
        
        guard let jpegData = cameraManager.captureCurrentFrameJPEG() else {
            print("[SCENE] Frame capture failed.")
            return
        }
        
        print("[SCENE] Frame captured (\(jpegData.count) bytes). Sending Gemini request...")
        
        isRequestInFlight = true
        lastRequestTimestamp = now
        
        withAnimation(.easeInOut(duration: 0.2)) {
            operationalState = .analyzing
        }
        
        // Snapshot the reference scene at the moment of capture
        let snapshotReference = AnalyzedSceneReference(
            dominantClassification: recognition.topClassification?.identifier,
            ocrTextFingerprint: recognition.combinedText,
            featurePrint: recognition.featurePrint,
            analyzedAt: now
        )
        
        Task {
            let result = await multimodalService.analyzeImage(
                jpegData: jpegData,
                apiKey: MultimodalConfig.apiKey
            )
            
            await MainActor.run {
                self.isRequestInFlight = false
                
                if result.status == .success && !result.text.isEmpty {
                    print("[SCENE] Gemini SUCCESS - Response length: \(result.text.count)")
                    
                    let synthesized = self.interpretationService.interpret(
                        recognition: self.cameraManager.latestResult,
                        multimodal: result
                    )
                    
                    print("[SCENE] Result LOCKED: '\(synthesized.primaryHeadline)' with full plain-text description (\(synthesized.detailedDescription?.count ?? 0) chars)")
                    
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.displayedInterpretation = synthesized
                        self.lastAnalyzedScene = snapshotReference
                        self.operationalState = .resultLocked
                    }
                } else {
                    print("[SCENE] Multimodal request failed (\(result.status)). Falling back to local evidence.")
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.operationalState = .observing
                    }
                }
            }
        }
    }
    
    // MARK: - State Reset Helper
    
    private func resetAutomaticCycle() {
        observationStartTime = nil
        sceneDivergenceStartTime = nil
        lastAnalyzedScene = nil
        isRequestInFlight = false
        operationalState = .observing
        displayedInterpretation = .initial
        interpretationService.resetStability()
    }
    
    // MARK: - Non-Interactive Subtle State Status Bar
    
    private var stateStatusIndicator: some View {
        HStack(spacing: 6) {
            switch operationalState {
            case .stabilizing:
                Circle()
                    .fill(Color.yellow)
                    .frame(width: 7, height: 7)
                Text("Holding steady...")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.yellow)
                
            case .analyzing:
                ProgressView()
                    .scaleEffect(0.65)
                    .tint(.white)
                Text("Analyzing...")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                
            case .possibleSceneChange, .sceneChangeConfirmed:
                Circle()
                    .fill(Color.blue)
                    .frame(width: 7, height: 7)
                Text("New object detected...")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                
            case .observing, .resultLocked:
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.65))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusAccessibilityText)
    }
    
    private var statusAccessibilityText: String {
        switch operationalState {
        case .observing: return "Observing scene"
        case .stabilizing: return "Holding steady"
        case .analyzing: return "Analyzing"
        case .resultLocked: return "Analysis result locked"
        case .possibleSceneChange: return "Evaluating potential scene change"
        case .sceneChangeConfirmed: return "New object detected"
        }
    }
    
    // MARK: - Interpretation Decision Card (T005)
    
    private func interpretationCard(interpretation: InterpretationResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            
            // Header: Status Badge & Contributing Evidence Sources
            HStack {
                confidenceBadge(interpretation.confidence)
                
                Spacer()
                
                HStack(spacing: 4) {
                    ForEach(interpretation.contributingSources) { source in
                        Text(source.rawValue)
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(sourceBadgeColor(source))
                            .foregroundStyle(.white.opacity(0.95))
                            .clipShape(Capsule())
                    }
                }
            }
            
            // 1. Primary Semantic Headline (Concise, Prominent Title)
            Text(interpretation.primaryHeadline)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .lineLimit(2)
                .accessibilityAddTraits(.isHeader)
            
            // 2. Detailed Multimodal Analysis (Clean Plain-Text Explanation)
            if let description = interpretation.detailedDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Cautionary Note (if uncertainty or conflict exists)
            if let caution = interpretation.cautionaryNote {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text(caution)
                        .font(.caption)
                        .foregroundStyle(.yellow.opacity(0.95))
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.yellow.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Expandable Raw Telemetry (T003 Developer View)
            if showRawTelemetry {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.top, 4)
                rawTelemetrySection(result: cameraManager.latestResult)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.88))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(confidenceBorderColor(interpretation.confidence), lineWidth: 1.5)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Interpretation: \(interpretation.primaryHeadline). \(interpretation.detailedDescription ?? ""). Confidence: \(interpretation.confidence.rawValue). \(interpretation.cautionaryNote ?? "")")
    }
    
    // MARK: - Source Badge Color Helper
    
    private func sourceBadgeColor(_ source: EvidenceSource) -> Color {
        switch source {
        case .multimodal:
            return Color.blue.opacity(0.4)
        case .onDeviceVision:
            return Color.white.opacity(0.15)
        case .onDeviceOCR:
            return Color.yellow.opacity(0.25)
        }
    }
    
    // MARK: - Confidence Badge Helper
    
    private func confidenceBadge(_ confidence: EvidenceConfidence) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(confidenceColor(confidence))
                .frame(width: 8, height: 8)
            Text(confidenceTitle(confidence))
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(confidenceColor(confidence))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(confidenceColor(confidence).opacity(0.15))
        .clipShape(Capsule())
    }
    
    private func confidenceTitle(_ confidence: EvidenceConfidence) -> String {
        switch confidence {
        case .strong: return "Strong Evidence"
        case .moderate: return "Moderate Evidence"
        case .weak: return "Weak Evidence"
        case .conflicting: return "Conflicting Evidence"
        case .insufficient: return "Insufficient Input"
        }
    }
    
    private func confidenceColor(_ confidence: EvidenceConfidence) -> Color {
        switch confidence {
        case .strong: return .green
        case .moderate: return .blue
        case .weak: return .orange
        case .conflicting: return .red
        case .insufficient: return .secondary
        }
    }
    
    private func confidenceBorderColor(_ confidence: EvidenceConfidence) -> Color {
        switch confidence {
        case .strong: return .green.opacity(0.5)
        case .moderate: return .blue.opacity(0.4)
        case .weak: return .orange.opacity(0.4)
        case .conflicting: return .red.opacity(0.6)
        case .insufficient: return .white.opacity(0.15)
        }
    }
    
    // MARK: - Raw Telemetry Sub-section (T003)
    
    private func rawTelemetrySection(result: RecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Raw Telemetry:")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
                if result.processingTimeMs > 0 {
                    Text("\(Int(result.processingTimeMs))ms")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Text("Vision:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.topClassification?.identifier ?? "None")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("OCR:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.recognizedTexts.isEmpty ? "None" : result.combinedText)
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
            }
        }
    }
    
    // MARK: - Local API Key Configuration Sheet
    
    private var apiKeyConfigurationView: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Key Configuration"), footer: Text("Your API key is stored locally on this device in private storage and is never committed or tracked in Git.")) {
                    SecureField("Paste API Key", text: $apiKeyInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                if MultimodalConfig.hasConfiguredKey {
                    Section {
                        Button(role: .destructive) {
                            MultimodalConfig.apiKey = ""
                            apiKeyInput = ""
                        } label: {
                            Text("Clear Stored Key")
                        }
                    }
                }
            }
            .navigationTitle("Multimodal Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showAPIKeySheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        MultimodalConfig.apiKey = apiKeyInput
                        showAPIKeySheet = false
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Fallback State Views
    
    private var unauthorizedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("TestApp needs camera permission to capture visual input for identification. Please enable Camera access in iOS Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
            
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsURL)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
    
    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("Camera Not Available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("No camera device was detected. If running on iOS Simulator, test on a physical iOS device with a camera.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            
            Text("Camera Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CameraView()
}
