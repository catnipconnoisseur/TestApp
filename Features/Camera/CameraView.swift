import AVFoundation
import Speech
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

// MARK: - SwiftUI Camera View (Camera-First Accessible View)

struct CameraView: View {
    @StateObject private var viewModel = CameraViewModel()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch viewModel.cameraManager.status {
            case .ready:
                cameraReadyView
                
            case .unauthorized:
                unauthorizedView
                
            case .unavailable:
                unavailableView
                
            case .failed(let message):
                errorView(message: message)
                
            case .unconfigured:
                ProgressView("Starting camera…")
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            viewModel.onAppear()
        }
        .onDisappear {
            viewModel.onDisappear()
        }
        .onChange(of: scenePhase) { _, newPhase in
            viewModel.handleScenePhaseChange(newPhase)
        }
        .sheet(isPresented: $viewModel.showSettingsSheet) {
            SettingsView(
                selectedLocale: $viewModel.speechService.selectedLocale,
                showDeveloperDiagnostics: $viewModel.showRawTelemetry
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: viewModel.cameraManager.latestResult) { _, newResult in
            viewModel.handleIncomingVisionFrame(newResult)
        }
        .onChange(of: viewModel.interactionState) { _, newState in
            viewModel.handleInteractionStateHaptics(newState)
        }
    }
    
    // MARK: - Camera Ready View (Primary Experience)
    
    private var cameraReadyView: some View {
        ZStack {
            // Full-screen camera preview (hidden from VoiceOver to prevent background layer occlusion)
            CameraPreviewRepresentable(session: viewModel.cameraManager.captureSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            // Content overlay
            VStack(spacing: 0) {
                
                // Top Bar: Settings only
                topBar
                
                Spacer()
                
                // Speech feedback (shown during/after voice interaction)
                if viewModel.showSpeechCard {
                    speechFeedbackCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
                
                // Interpretation/Result Card
                interpretationCard(interpretation: viewModel.displayedInterpretation)
                    .padding(.bottom, 10)
                
                // Primary interaction: Large voice area or Analyze fallback
                bottomInteractionArea
                    .padding(.bottom, 8)
            }
        }
        .accessibilityAction(.magicTap) {
            viewModel.handleMagicTapAccessibilityAction()
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            Spacer()
            
            Button {
                viewModel.showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .accessibilityLabel(viewModel.speechService.isIndonesian ? "Pengaturan" : "Settings")
            .accessibilityHint(viewModel.speechService.isIndonesian ? "Buka preferensi bahasa dan konfigurasi." : "Opens language preferences and configuration.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Speech Feedback Card
    
    private var speechFeedbackCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.subheadline)
                .foregroundStyle(viewModel.speechService.status.isListening ? .red : .blue)
            
            Text(speechFeedbackText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Spacer()
            
            if viewModel.speechService.status.isListening {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(speechFeedbackAccessibilityLabel)
    }
    
    private var speechFeedbackText: String {
        if viewModel.speechService.status.isListening {
            let partial = viewModel.speechService.partialTranscript
            return partial.isEmpty ? (viewModel.speechService.isIndonesian ? "Mendengarkan…" : "Listening…") : "\"\(partial)\""
        } else if let q = viewModel.lastSpokenQuestion {
            return "\"\(q)\""
        }
        return viewModel.speechService.isIndonesian ? "Memproses…" : "Processing…"
    }
    
    private var speechFeedbackAccessibilityLabel: String {
        if viewModel.speechService.status.isListening {
            let partial = viewModel.speechService.partialTranscript
            return partial.isEmpty ? "Listening for question" : "Question: \(partial)"
        } else if let q = viewModel.lastSpokenQuestion {
            return "Asked: \(q)"
        }
        return "Voice processing"
    }
    
    // MARK: - Bottom Interaction Area
    
    private var bottomInteractionArea: some View {
        Group {
            if viewModel.microphoneAvailable {
                voiceInteractionArea
            } else {
                analyzeFallbackButton
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Large Voice Interaction Area (~120pt, full width)
    
    private var voiceInteractionArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(voiceAreaBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(voiceAreaBorderColor, lineWidth: 1.5)
                )
            
            VStack(spacing: 8) {
                // State-dependent icon
                Group {
                    switch viewModel.interactionState {
                    case .listening:
                        Image(systemName: "waveform")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    case .thinking:
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(.white)
                    default:
                        Image(systemName: "mic.fill")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(height: 32)
                
                // State-dependent label
                Text(voiceAreaLabel)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.9))
                
                // Hint text (idle only)
                if case .idle = viewModel.interactionState {
                    Text(viewModel.currentAIAnswer != nil ? "\"What is it used for?\"" : "\"What is this?\"")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.5))
                        .italic()
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !viewModel.isHoldingSpeechButton && !viewModel.isRequestInFlight {
                        viewModel.isHoldingSpeechButton = true
                        viewModel.startSpeechInput()
                    }
                }
                .onEnded { _ in
                    if viewModel.isHoldingSpeechButton {
                        viewModel.isHoldingSpeechButton = false
                        viewModel.stopSpeechInput()
                    }
                }
        )
        .disabled(viewModel.isRequestInFlight && !viewModel.isHoldingSpeechButton)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceAreaAccessibilityLabel)
        .accessibilityValue(voiceAreaAccessibilityValue)
        .accessibilityHint(voiceAreaAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {
            viewModel.handleVoiceAreaAccessibilityAction()
        }
        .accessibilityActionIf(named: "Repeat Answer", condition: viewModel.currentAIAnswer != nil) {
            viewModel.repeatLastAnswer()
        }
    }
    
    private var voiceAreaBackgroundColor: Color {
        switch viewModel.interactionState {
        case .listening:
            return Color.red.opacity(0.75)
        case .thinking:
            return Color.blue.opacity(0.6)
        case .error:
            return Color.orange.opacity(0.5)
        default:
            return Color.black.opacity(0.65)
        }
    }
    
    private var voiceAreaBorderColor: Color {
        switch viewModel.interactionState {
        case .listening:
            return Color.red.opacity(0.9)
        case .thinking:
            return Color.blue.opacity(0.7)
        case .error:
            return Color.orange.opacity(0.7)
        default:
            return Color.white.opacity(0.2)
        }
    }
    
    private var voiceAreaLabel: String {
        switch viewModel.interactionState {
        case .idle, .answered:
            return viewModel.currentAIAnswer != nil ? "Hold and ask another question" : "Hold and ask a question"
        case .listening:
            return "Listening…"
        case .thinking:
            return "Thinking…"
        case .error:
            return "Try again"
        }
    }
    
    private var voiceAreaAccessibilityLabel: String {
        switch viewModel.interactionState {
        case .listening:
            return "Recording question"
        case .thinking:
            return "Processing question"
        case .answered:
            return "Ask another question"
        case .error:
            return "Try asking again"
        case .idle:
            return viewModel.currentAIAnswer != nil ? "Ask another question" : "Ask a question"
        }
    }
    
    private var voiceAreaAccessibilityValue: String {
        switch viewModel.interactionState {
        case .listening:
            return "Recording in progress"
        case .thinking:
            return "Analyzing image and speech"
        case .answered:
            return "Answer available"
        case .error(let msg):
            return "Error: \(msg)"
        case .idle:
            return ""
        }
    }
    
    private var voiceAreaAccessibilityHint: String {
        switch viewModel.interactionState {
        case .listening:
            return "Double-tap to stop recording and submit your question."
        case .thinking:
            return "Please wait while your question is analyzed."
        case .answered:
            return "Double-tap to ask another question, or use the Actions rotor to repeat the previous answer. Or press and hold while speaking."
        case .error:
            return "Double-tap to try asking again, or press and hold while speaking."
        case .idle:
            return "Double-tap to start speaking, then double-tap again to get an answer. Or press and hold the bottom of the screen while speaking."
        }
    }
    
    // MARK: - Analyze Fallback Button (Microphone Denied)
    
    private var analyzeFallbackButton: some View {
        Button {
            viewModel.triggerManualAnalysis()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isRequestInFlight {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.white)
                    Text("Analyzing…")
                        .font(.headline)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "sparkles")
                        .font(.headline)
                        .foregroundStyle(.yellow)
                    Text("Analyze")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.blue.opacity(0.85))
            )
        }
        .disabled(viewModel.isRequestInFlight)
        .accessibilityLabel(viewModel.isRequestInFlight ? "Analyzing image" : "Analyze what the camera sees")
        .accessibilityHint("Captures the current camera view and performs detailed AI analysis.")
    }
    
    // MARK: - Interpretation Card
    
    private func interpretationCard(interpretation: InterpretationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            
            // Confidence dot + Headline + Visible Repeat Button (T012)
            HStack(alignment: .top, spacing: 8) {
                // Simple colored dot for confidence (no text label)
                Circle()
                    .fill(confidenceColor(interpretation.confidence))
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                    .accessibilityLabel(confidenceAccessibilityLabel(interpretation.confidence))
                
                // Primary Headline
                Text(interpretation.primaryHeadline)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .accessibilityAddTraits(.isHeader)
                
                Spacer()
                
                // Repeat Answer Button (Visible when an AI answer exists)
                if viewModel.currentAIAnswer != nil {
                    Button {
                        viewModel.repeatLastAnswer()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(8)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(viewModel.speechService.isIndonesian ? "Ulangi jawaban" : "Repeat answer")
                    .accessibilityHint(viewModel.speechService.isIndonesian ? "Ketuk dua kali untuk mendengarkan kembali jawaban ini." : "Double-tap to hear this answer again.")
                }
            }
            
            // Description
            if let description = interpretation.detailedDescription {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.88))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            // Cautionary Note (human-readable error/uncertainty)
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
                .background(Color.yellow.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            // Developer Telemetry (hidden by default, toggled from Settings)
            if viewModel.showRawTelemetry {
                Divider()
                    .background(Color.white.opacity(0.2))
                    .padding(.top, 4)
                rawTelemetrySection(result: viewModel.cameraManager.latestResult)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(interpretationAccessibilityLabel(interpretation))
        .accessibilityActionIf(named: "Repeat Answer", condition: viewModel.currentAIAnswer != nil) {
            viewModel.repeatLastAnswer()
        }
    }
    
    // MARK: - Confidence Helpers
    
    private func confidenceColor(_ confidence: EvidenceConfidence) -> Color {
        switch confidence {
        case .strong: return .green
        case .moderate: return .blue
        case .weak: return .orange
        case .conflicting: return .red
        case .insufficient: return .gray
        }
    }
    
    private func confidenceAccessibilityLabel(_ confidence: EvidenceConfidence) -> String {
        switch confidence {
        case .strong: return "High confidence"
        case .moderate: return "Moderate confidence"
        case .weak: return "Low confidence"
        case .conflicting: return "Conflicting signals"
        case .insufficient: return "Insufficient data"
        }
    }
    
    private func interpretationAccessibilityLabel(_ interpretation: InterpretationResult) -> String {
        var label = interpretation.primaryHeadline
        if let desc = interpretation.detailedDescription {
            label += ". \(desc)"
        }
        let conf = confidenceAccessibilityLabel(interpretation.confidence)
        if !conf.isEmpty {
            label += ". \(conf)."
        }
        if let caution = interpretation.cautionaryNote {
            label += " \(caution)"
        }
        return label
    }
    
    // MARK: - Raw Telemetry Sub-section (Developer View)
    
    private func rawTelemetrySection(result: RecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Technical Diagnostics:")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Trigger: \(viewModel.lastTriggerType)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(viewModel.lastTriggerType == "Voice" ? .purple : .blue)
            }
            
            if let q = viewModel.lastSpokenQuestion {
                HStack {
                    Text("Spoken Question:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("\"\(q)\"")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                        .lineLimit(1)
                }
            }
            
            HStack {
                Text("Speech State:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(speechStatusTelemetryTitle)
                    .font(.caption2)
                    .foregroundStyle(viewModel.speechService.status.isListening ? .red : .white)
                
                Spacer()
                
                Text("Speech Duration:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.speechService.lastRecordingDuration > 0 ? "\(String(format: "%.1f", viewModel.speechService.lastRecordingDuration))s" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("Vision Latency:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.processingTimeMs > 0 ? "\(Int(result.processingTimeMs))ms" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Gemini Latency:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.lastGeminiLatencyMs > 0 ? "\(Int(viewModel.lastGeminiLatencyMs))ms" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("Total Turnaround:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.lastPerceivedTurnaroundMs > 0 ? "\(Int(viewModel.lastPerceivedTurnaroundMs))ms" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Snapshot Size:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.lastAnalyzedPayloadBytes > 0 ? "\(viewModel.lastAnalyzedPayloadBytes / 1024) KB" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("Multimodal Status:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.lastMultimodalStatus.displayTelemetryTitle)
                    .font(.caption2)
                    .foregroundStyle(viewModel.lastMultimodalStatus.isRateLimited ? .orange : .white)
            }
            
            HStack {
                Text("Vision Category:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.topClassification?.identifier ?? "None")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("OCR Text:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.recognizedTexts.isEmpty ? "None" : result.combinedText)
                    .font(.caption2)
                    .foregroundStyle(.yellow)
                    .lineLimit(1)
            }
            
            HStack {
                Text("Active Thread:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.activeConversationThread != nil ? "Active (\(viewModel.activeConversationThread!.turnCount) turns)" : "None (New Scene)")
                    .font(.caption2)
                    .foregroundStyle(viewModel.activeConversationThread != nil ? .green : .white)
                
                Spacer()
                
                Text("Divergence:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", viewModel.lastDivergenceScore))
                    .font(.caption2)
                    .foregroundStyle(viewModel.lastDivergenceScore >= SceneStabilityConfiguration.divergenceThreshold ? .orange : .white)
            }
            
            HStack {
                Text("Sources:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(viewModel.displayedInterpretation.contributingSources) { source in
                        Text(source.rawValue)
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.15))
                            .foregroundStyle(.white.opacity(0.9))
                            .clipShape(Capsule())
                    }
                }
            }
            
            HStack {
                Text("Confidence:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.displayedInterpretation.confidence.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Mic Available:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(viewModel.microphoneAvailable ? "Yes" : "No (Fallback)")
                    .font(.caption2)
                    .foregroundStyle(viewModel.microphoneAvailable ? .green : .orange)
            }
        }
    }
    
    private var speechStatusTelemetryTitle: String {
        switch viewModel.speechService.status {
        case .idle: return "Idle"
        case .listening: return "Listening (PCM Tap Active)"
        case .finalizing: return "Finalizing"
        case .unauthorized: return "Unauthorized"
        case .unavailable: return "Unavailable"
        case .failed: return "Error"
        }
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
            
            Text("This app needs camera permission to help you understand what's around you. Please enable Camera access in Settings.")
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
            
            Text("No camera was detected. Please use a device with a camera.")
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

// MARK: - Accessibility Helper Extension

extension View {
    @ViewBuilder
    func accessibilityActionIf(named name: String, condition: Bool, action: @escaping () -> Void) -> some View {
        if condition {
            self.accessibilityAction(named: name, action)
        } else {
            self
        }
    }
}
