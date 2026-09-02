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

// MARK: - Interaction State

/// Describes the user-facing state of the voice interaction area.
private enum InteractionState: Equatable {
    case idle
    case listening
    case thinking
    case answered
    case error(String)
}

// MARK: - SwiftUI Camera View (Camera-First Accessible Interaction)

struct CameraView: View {
    @State private var cameraManager = CameraManager()
    @State private var multimodalService = MultimodalService()
    @State private var speechService = SpeechService()
    private let interpretationService = InterpretationService()
    
    // Scene Anchoring & Conversational Memory (T009)
    @State private var activeConversationThread: SceneConversationThread? = nil
    
    // State Tracking
    @State private var lastAnalyzedScene: AnalyzedSceneReference?
    @State private var sceneDivergenceStartTime: Date?
    @State private var lastVisualObservationTime: Date = Date()
    
    // Conversation State & Persistent AI Answer
    @State private var currentAIAnswer: InterpretationResult? = nil
    @State private var liveVisionInterpretation: InterpretationResult = .initial
    
    // Request State & In-Flight Guards
    @State private var isRequestInFlight = false
    @State private var isProcessingVoiceQuery = false
    @State private var lastRequestTimestamp: Date = .distantPast
    @State private var lastTriggerType: String = "None"
    
    // Speech Input & Voice Snapshot State
    @State private var isHoldingSpeechButton = false
    @State private var showSpeechCard = false
    @State private var lastSpokenQuestion: String? = nil
    @State private var pendingVoiceSnapshot: Data? = nil
    @State private var pendingVoiceReference: AnalyzedSceneReference? = nil
    
    // Diagnostic Telemetry (Developer View)
    @State private var lastGeminiLatencyMs: Double = 0.0
    @State private var lastPerceivedTurnaroundMs: Double = 0.0
    @State private var lastAnalyzedPayloadBytes: Int = 0
    @State private var lastMultimodalStatus: MultimodalService.ResponseStatus = .idle
    @State private var lastDivergenceScore: Float = 0.0
    
    // Computed Current Interpretation
    private var displayedInterpretation: InterpretationResult {
        if let aiAnswer = currentAIAnswer {
            return aiAnswer
        }
        return liveVisionInterpretation
    }
    
    // Interaction State
    @State private var interactionState: InteractionState = .idle
    
    // Tactile Thinking Haptics (T012)
    @State private var thinkingHapticTask: Task<Void, Never>? = nil
    
    // UI Sheets & Configuration
    @State private var showSettingsSheet = false
    @State private var showRawTelemetry = false
    
    // Microphone permission tracking for fallback
    @State private var microphoneAvailable: Bool = true
    
    // TEMPORARY T007.2 TEST INPUT — REMOVE AFTER TESTING
    @State private var testQuestionInput: String = ""
    // END TEMPORARY T007.2 TEST INPUT
    
    // Camera arrival announcement tracker
    @State private var hasAnnouncedCameraArrival = false
    
    // Scene phase for background/foreground lifecycle handling
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch cameraManager.status {
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
            cameraManager.requestAccessAndSetup()
            checkAndAnnounceLaunchState()
        }
        .onDisappear {
            cameraManager.stopSession()
            speechService.cancelRecording()
            stopThinkingHaptics()
            AccessibilityVoiceService.shared.stopSpeaking()
            resetSessionState()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                cameraManager.requestAccessAndSetup()
                checkAndAnnounceLaunchState()
            }
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(
                selectedLocale: $speechService.selectedLocale,
                showDeveloperDiagnostics: $showRawTelemetry
            )
            .presentationDetents([.medium, .large])
        }
        .onChange(of: cameraManager.latestResult) { _, newResult in
            handleIncomingVisionFrame(newResult)
        }
        .onChange(of: interactionState) { _, newState in
            handleInteractionStateHaptics(newState)
        }
    }
    
    // MARK: - Launch & Quick Access Announcement
    
    private func checkAndAnnounceLaunchState() {
        let isQuickAccess = UserDefaults.standard.bool(forKey: "launchedFromQuickAccess")
        if isQuickAccess {
            UserDefaults.standard.set(false, forKey: "launchedFromQuickAccess")
            hasAnnouncedCameraArrival = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let msg = speechService.isIndonesian
                    ? "TestApp siap. Tahan bagian bawah layar untuk bertanya."
                    : "TestApp ready. Touch and hold the bottom of the screen to ask a question."
                AccessibilityVoiceService.shared.speak(msg, languageCode: speechService.selectedLocale.identifier)
            }
        } else if !hasAnnouncedCameraArrival {
            hasAnnouncedCameraArrival = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let arrivalMsg = speechService.isIndonesian
                    ? "Kamera siap. Tahan bagian bawah layar untuk bertanya."
                    : "Camera ready. Touch and hold the bottom of the screen to ask a question."
                AccessibilityVoiceService.shared.speak(arrivalMsg, languageCode: speechService.selectedLocale.identifier)
            }
        }
    }
    
    // MARK: - Camera Ready View (Primary Experience)
    
    private var cameraReadyView: some View {
        ZStack {
            // Full-screen camera preview (hidden from VoiceOver to prevent background layer occlusion)
            CameraPreviewRepresentable(session: cameraManager.captureSession)
                .ignoresSafeArea()
                .accessibilityHidden(true)
            
            // Content overlay
            VStack(spacing: 0) {
                
                // Top Bar: Settings only
                topBar
                
                // TEMPORARY T007.2 TEST INPUT — REMOVE AFTER TESTING (Hidden from VoiceOver)
                temporaryTestingInputBar
                    .accessibilityHidden(true)
                // END TEMPORARY T007.2 TEST INPUT
                
                Spacer()
                
                // Speech feedback (shown during/after voice interaction)
                if showSpeechCard {
                    speechFeedbackCard
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
                
                // Interpretation/Result Card
                interpretationCard(interpretation: displayedInterpretation)
                    .padding(.bottom, 10)
                
                // Primary interaction: Large voice area or Analyze fallback
                bottomInteractionArea
                    .padding(.bottom, 8)
            }
        }
        .accessibilityAction(.magicTap) {
            handleMagicTapAccessibilityAction()
        }
    }
    
    // MARK: - TEMPORARY T007.2 TEST INPUT — REMOVE AFTER TESTING
    
    private var temporaryTestingInputBar: some View {
        HStack(spacing: 8) {
            TextField("Type a question for testing...", text: $testQuestionInput)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.18)))
                .foregroundStyle(.white)
                .tint(.blue)
                .accessibilityLabel("Test question input")
                .accessibilityHint("Enter a question to test Gemini multimodal reasoning.")
            
            Button {
                let textToSubmit = testQuestionInput
                // Dismiss keyboard
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                // Capture current camera snapshot
                let snapshot = cameraManager.captureCurrentFrameJPEG()
                let sceneRef = AnalyzedSceneReference(
                    dominantClassification: cameraManager.latestResult.topClassification?.identifier,
                    ocrTextFingerprint: cameraManager.latestResult.combinedText,
                    featurePrint: cameraManager.latestResult.featurePrint,
                    analyzedAt: Date()
                )
                
                withAnimation(.easeInOut(duration: 0.15)) {
                    showSpeechCard = true
                }
                
                submitQuestion(
                    textToSubmit,
                    capturedSnapshot: snapshot,
                    sceneReference: sceneRef,
                    triggerType: "Test-Text"
                )
            } label: {
                Text("Ask AI (Test)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(isRequestInFlight ? Color.gray : Color.purple))
            }
            .disabled(isRequestInFlight)
            .accessibilityLabel("Ask AI for typed test question")
            .accessibilityHint("Submits the typed question and current camera image to Gemini.")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.75)))
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
    
    // END TEMPORARY T007.2 TEST INPUT
    
    // MARK: - Top Bar (Settings Only)
    
    private var topBar: some View {
        HStack {
            Button {
                showSettingsSheet = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(14)
                    .background(Circle().fill(Color.black.opacity(0.3)))
            }
            .accessibilityLabel("Settings")
            .accessibilityHint("Opens settings for language, API key, and diagnostics.")
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }
    
    // MARK: - Continuous On-Device Vision Engine & Scene Invalidation
    
    private func handleIncomingVisionFrame(_ recognition: RecognitionResult) {
        let now = Date()
        let hasVisuals = recognition.hasObservations
        
        // 1. Empty Scene Invalidation: If camera pointed away into empty space for > 0.6s
        if !hasVisuals {
            if now.timeIntervalSince(lastVisualObservationTime) > 0.6 {
                liveVisionInterpretation = .initial
            }
            return
        }
        
        lastVisualObservationTime = now
        
        // 2. Track scene divergence against the active conversation thread (or last analyzed scene)
        // NOTE: Scene divergence resets active multi-turn conversational context, but does NOT erase persistent AI answer display (T007.3).
        if let activeThread = activeConversationThread {
            if activeThread.isExpired() {
                print("[MEMORY] Active conversation thread expired due to inactivity (> \(Int(SceneStabilityConfiguration.threadInactivityTimeout))s). Resetting thread.")
                self.activeConversationThread = nil
                self.sceneDivergenceStartTime = nil
            } else {
                let (divergence, reason) = interpretationService.computeSceneDivergence(current: recognition, reference: activeThread.anchorScene)
                lastDivergenceScore = divergence
                
                if divergence >= SceneStabilityConfiguration.divergenceThreshold {
                    if let start = sceneDivergenceStartTime {
                        let elapsed = now.timeIntervalSince(start)
                        if elapsed >= SceneStabilityConfiguration.confirmationDuration {
                            print("[SCENE] Confirmed scene change (\(reason ?? "diverged")). Resetting active conversation thread. (Persistent AI answer remains visible)")
                            self.activeConversationThread = nil
                            self.sceneDivergenceStartTime = nil
                        }
                    } else {
                        self.sceneDivergenceStartTime = now
                        print("[SCENE] Candidate scene divergence observed (\(reason ?? "diverged")). Awaiting confirmation (\(SceneStabilityConfiguration.confirmationDuration)s)...")
                    }
                } else {
                    if sceneDivergenceStartTime != nil {
                        self.sceneDivergenceStartTime = nil
                    }
                }
            }
        } else if let reference = lastAnalyzedScene {
            let (divergence, _) = interpretationService.computeSceneDivergence(current: recognition, reference: reference)
            lastDivergenceScore = divergence
            if divergence < SceneStabilityConfiguration.divergenceThreshold {
                sceneDivergenceStartTime = nil
            }
        }
        
        // 3. Continuous Local Vision + OCR Interpretation (for live viewfinder when no AI answer is active)
        liveVisionInterpretation = interpretationService.interpret(recognition: recognition, locale: speechService.selectedLocale)
    }
    
    // MARK: - User-Initiated Manual Analysis Fallback (Microphone Denied)
    
    private func triggerManualAnalysis() {
        guard !isRequestInFlight else { return }
        
        guard MultimodalConfig.hasConfiguredKey else {
            showSettingsSheet = true
            return
        }
        
        print("[USER] Analyze button tapped. Capturing frame for generic Gemini reasoning...")
        
        guard let jpegData = cameraManager.captureCurrentFrameJPEG() else {
            print("[USER] Frame capture failed.")
            return
        }
        
        isRequestInFlight = true
        interactionState = .thinking
        lastTriggerType = "Manual"
        lastRequestTimestamp = Date()
        let requestStartTime = Date()
        startThinkingHaptics()
        
        // Snapshot the reference scene at the moment of capture
        let snapshotReference = AnalyzedSceneReference(
            dominantClassification: cameraManager.latestResult.topClassification?.identifier,
            ocrTextFingerprint: cameraManager.latestResult.combinedText,
            featurePrint: cameraManager.latestResult.featurePrint,
            analyzedAt: requestStartTime
        )
        
        let analyzeMsg = speechService.isIndonesian ? "Menganalisis gambar." : "Analyzing image."
        AccessibilityVoiceService.shared.speak(analyzeMsg, languageCode: speechService.selectedLocale.identifier)
        
        var onDeviceHints: [String] = []
        if !cameraManager.latestResult.recognizedTexts.isEmpty {
            let topTexts = cameraManager.latestResult.recognizedTexts.prefix(6).map { "\"\($0.text)\"" }
            onDeviceHints.append("Visible text detected on-device: \(topTexts.joined(separator: ", "))")
        }
        if let topClass = cameraManager.latestResult.topClassification {
            onDeviceHints.append("Visual category: \(topClass.identifier)")
        }
        
        let activeTurns = self.activeConversationThread?.turns ?? []
        let manualQuestion = speechService.isIndonesian ? "Apa ini?" : "What is this?"
        
        Task {
            let result = await multimodalService.analyzeMultiTurn(
                turns: activeTurns,
                currentQuestion: manualQuestion,
                currentImage: jpegData,
                onDeviceHints: onDeviceHints,
                locale: speechService.selectedLocale,
                apiKey: MultimodalConfig.apiKey
            )
            
            await MainActor.run {
                self.isRequestInFlight = false
                self.stopThinkingHaptics()
                self.lastMultimodalStatus = result.status
                self.lastGeminiLatencyMs = result.latencyMs
                self.lastPerceivedTurnaroundMs = Date().timeIntervalSince(requestStartTime) * 1000.0
                self.lastAnalyzedPayloadBytes = jpegData.count
                
                if result.status == .success && !result.text.isEmpty {
                    print("[USER] Gemini SUCCESS (\(Int(result.latencyMs))ms) - Response length: \(result.text.count)")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    let synthesized = self.interpretationService.interpret(
                        recognition: self.cameraManager.latestResult,
                        multimodal: result,
                        locale: self.speechService.selectedLocale
                    )
                    
                    let newTurn = ConversationTurn(
                        question: manualQuestion,
                        answer: synthesized,
                        rawAIResponse: result.text
                    )
                    
                    if var thread = self.activeConversationThread, !thread.isExpired() {
                        thread.appendTurn(newTurn)
                        self.activeConversationThread = thread
                    } else {
                        var newThread = SceneConversationThread(anchorScene: snapshotReference)
                        newThread.appendTurn(newTurn)
                        self.activeConversationThread = newThread
                    }
                    
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.currentAIAnswer = synthesized
                        self.lastAnalyzedScene = snapshotReference
                        self.interactionState = .answered
                    }
                    
                    AccessibilityVoiceService.shared.speak(
                        "\(synthesized.primaryHeadline). \(synthesized.detailedDescription ?? "")",
                        languageCode: self.speechService.selectedLocale.identifier
                    )
                } else {
                    handleGeminiFailure(result: result, sceneRef: snapshotReference)
                }
            }
        }
    }
    
    // MARK: - End-to-End Voice Query Action
    
    private func startSpeechInput() {
        guard !isRequestInFlight else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Synchronously snapshot current camera frame
        if let jpegData = cameraManager.captureCurrentFrameJPEG() {
            self.pendingVoiceSnapshot = jpegData
            self.pendingVoiceReference = AnalyzedSceneReference(
                dominantClassification: cameraManager.latestResult.topClassification?.identifier,
                ocrTextFingerprint: cameraManager.latestResult.combinedText,
                featurePrint: cameraManager.latestResult.featurePrint,
                analyzedAt: Date()
            )
            print("[VOICE] Captured frame snapshot (\(jpegData.count) bytes).")
        } else {
            print("[VOICE] Warning: Frame snapshot capture failed.")
        }
        
        withAnimation(.easeInOut(duration: 0.15)) {
            showSpeechCard = true
            interactionState = .listening
        }
        
        let listeningMsg = speechService.isIndonesian ? "Mendengarkan." : "Listening."
        AccessibilityVoiceService.shared.speak(listeningMsg, languageCode: speechService.selectedLocale.identifier)
        
        Task {
            let granted = await speechService.requestPermissions()
            if granted {
                speechService.startRecording()
            } else {
                await MainActor.run {
                    self.microphoneAvailable = false
                    self.interactionState = .idle
                }
            }
        }
    }
    
    private func stopSpeechInput() {
        guard isHoldingSpeechButton == false else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
            // Await on-device speech transcription finalization (< 250ms)
            let rawQuestion = await speechService.stopRecordingAndGetTranscript()
            await MainActor.run {
                self.submitQuestion(
                    rawQuestion,
                    capturedSnapshot: self.pendingVoiceSnapshot,
                    sceneReference: self.pendingVoiceReference,
                    triggerType: "Voice"
                )
            }
        }
    }
    
    /// Unified submission pipeline for questions originating from SpeechService or temporary typed test input.
    private func submitQuestion(
        _ rawQuestion: String?,
        capturedSnapshot: Data? = nil,
        sceneReference: AnalyzedSceneReference? = nil,
        triggerType: String = "Voice"
    ) {
        guard !isRequestInFlight else { return }
        
        guard let rawQuestion = rawQuestion,
              !rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("[\(triggerType.uppercased())] Question empty or cancelled. Zero Gemini calls made.")
            self.pendingVoiceSnapshot = nil
            self.pendingVoiceReference = nil
            self.interactionState = .idle
            let emptyMsg = speechService.isIndonesian
                ? "Tidak mendengar pertanyaan. Tahan dan tanya lagi."
                : "I didn't hear a question. Hold and ask again."
            self.lastSpokenQuestion = emptyMsg
            AccessibilityVoiceService.shared.speak(emptyMsg, languageCode: speechService.selectedLocale.identifier)
            return
        }
        
        let question = rawQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check API Key
        guard MultimodalConfig.hasConfiguredKey else {
            showSettingsSheet = true
            self.pendingVoiceSnapshot = nil
            self.pendingVoiceReference = nil
            self.interactionState = .idle
            return
        }
        
        // Obtain captured snapshot (or fallback to live frame)
        guard let jpegData = capturedSnapshot ?? self.pendingVoiceSnapshot ?? self.cameraManager.captureCurrentFrameJPEG() else {
            print("[\(triggerType.uppercased())] Frame data missing for query.")
            self.interactionState = .idle
            return
        }
        
        let sceneRef = sceneReference ?? self.pendingVoiceReference ?? AnalyzedSceneReference(
            dominantClassification: self.cameraManager.latestResult.topClassification?.identifier,
            ocrTextFingerprint: self.cameraManager.latestResult.combinedText,
            featurePrint: self.cameraManager.latestResult.featurePrint,
            analyzedAt: Date()
        )
        
        self.lastSpokenQuestion = question
        self.isRequestInFlight = true
        self.isProcessingVoiceQuery = (triggerType == "Voice")
        self.lastTriggerType = triggerType
        self.lastRequestTimestamp = Date()
        self.interactionState = .thinking
        startThinkingHaptics()
        
        let analyzingQuestionMsg = speechService.isIndonesian
            ? "Menganalisis pertanyaan Anda."
            : "Analyzing your question."
        AccessibilityVoiceService.shared.speak(analyzingQuestionMsg, languageCode: speechService.selectedLocale.identifier)
        
        let requestStartTime = Date()
        
        let activeTurns: [ConversationTurn]
        if let currentThread = self.activeConversationThread, !currentThread.isExpired() {
            activeTurns = currentThread.turns
            print("[\(triggerType.uppercased())] Continuing active scene conversation thread (\(activeTurns.count) prior turns)...")
        } else {
            activeTurns = []
            print("[\(triggerType.uppercased())] Starting new scene conversation thread...")
        }
        
        var onDeviceHints: [String] = []
        if !cameraManager.latestResult.recognizedTexts.isEmpty {
            let topTexts = cameraManager.latestResult.recognizedTexts.prefix(6).map { "\"\($0.text)\"" }
            onDeviceHints.append("Visible text detected on-device: \(topTexts.joined(separator: ", "))")
        }
        if let topClass = cameraManager.latestResult.topClassification {
            onDeviceHints.append("Visual category: \(topClass.identifier)")
        }
        
        print("[\(triggerType.uppercased())] Sending Gemini multi-turn query for: \"\(question)\" (\(jpegData.count) bytes, \(activeTurns.count) prior turns) in locale \(speechService.selectedLocale.identifier)...")
        
        Task {
            let result = await multimodalService.analyzeMultiTurn(
                turns: activeTurns,
                currentQuestion: question,
                currentImage: jpegData,
                onDeviceHints: onDeviceHints,
                locale: speechService.selectedLocale,
                apiKey: MultimodalConfig.apiKey
            )
            
            await MainActor.run {
                self.isRequestInFlight = false
                self.isProcessingVoiceQuery = false
                self.pendingVoiceSnapshot = nil
                self.pendingVoiceReference = nil
                self.stopThinkingHaptics()
                
                self.lastMultimodalStatus = result.status
                self.lastGeminiLatencyMs = result.latencyMs
                self.lastPerceivedTurnaroundMs = Date().timeIntervalSince(requestStartTime) * 1000.0
                self.lastAnalyzedPayloadBytes = jpegData.count
                
                if result.status == .success && !result.text.isEmpty {
                    print("[\(triggerType.uppercased())] Gemini SUCCESS (\(Int(result.latencyMs))ms) - Response length: \(result.text.count)")
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    
                    let synthesized = self.interpretationService.interpret(
                        recognition: self.cameraManager.latestResult,
                        multimodal: result,
                        locale: self.speechService.selectedLocale
                    )
                    
                    let newTurn = ConversationTurn(
                        question: question,
                        answer: synthesized,
                        rawAIResponse: result.text
                    )
                    
                    if var thread = self.activeConversationThread, !thread.isExpired() {
                        thread.appendTurn(newTurn)
                        self.activeConversationThread = thread
                    } else {
                        var newThread = SceneConversationThread(anchorScene: sceneRef)
                        newThread.appendTurn(newTurn)
                        self.activeConversationThread = newThread
                    }
                    
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.currentAIAnswer = synthesized
                        self.lastAnalyzedScene = sceneRef
                        self.interactionState = .answered
                    }
                    
                    AccessibilityVoiceService.shared.speak(
                        "\(synthesized.primaryHeadline). \(synthesized.detailedDescription ?? "")",
                        languageCode: self.speechService.selectedLocale.identifier
                    )
                } else {
                    handleGeminiFailure(result: result, sceneRef: sceneRef)
                }
            }
        }
    }
    
    // MARK: - Gemini Failure Handler (Shared)
    
    private func handleGeminiFailure(result: MultimodalService.MultimodalResult, sceneRef: AnalyzedSceneReference) {
        stopThinkingHaptics()
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        
        let failureReason = result.status.displayTelemetryTitle
        print("[AI] Request failed (\(failureReason)). Showing failure notification.")
        
        let userMessage: String
        if speechService.isIndonesian {
            if result.status.isRateLimited {
                userMessage = "Layanan sedang sibuk. Silakan coba sebentar lagi."
            } else if case .networkError = result.status {
                userMessage = "Gagal terhubung. Periksa koneksi internet Anda dan coba lagi."
            } else if case .authenticationError = result.status {
                userMessage = "Masalah kunci API. Periksa kunci Anda di Pengaturan."
            } else {
                userMessage = "Tidak dapat menentukan jawaban dari gambar ini. Coba tanya lagi atau ubah posisi kamera."
            }
        } else {
            if result.status.isRateLimited {
                userMessage = "The service is temporarily busy. Please try again in a moment."
            } else if case .networkError = result.status {
                userMessage = "I couldn't connect. Check your internet connection and try again."
            } else if case .authenticationError = result.status {
                userMessage = "API key issue. Check your key in Settings."
            } else {
                userMessage = "I couldn't determine an answer from this image. Try asking again or repositioning the camera."
            }
        }
        
        // If there is no previous AI answer, update liveVisionInterpretation to display the helpful error note
        if currentAIAnswer == nil {
            let localFallback = self.interpretationService.interpret(
                recognition: self.cameraManager.latestResult,
                locale: self.speechService.selectedLocale
            )
            self.liveVisionInterpretation = InterpretationResult(
                primaryHeadline: localFallback.primaryHeadline,
                detailedDescription: localFallback.detailedDescription,
                confidence: localFallback.confidence,
                cautionaryNote: userMessage,
                contributingSources: localFallback.contributingSources,
                isSpecificIdentification: localFallback.isSpecificIdentification,
                timestamp: Date()
            )
        }
        
        withAnimation(.easeInOut(duration: 0.25)) {
            self.interactionState = .error(userMessage)
        }
        
        AccessibilityVoiceService.shared.speak(userMessage, languageCode: speechService.selectedLocale.identifier)
        
        // Reset to idle after brief error display (persistent AI answer remains intact)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if case .error = self.interactionState {
                self.interactionState = .idle
            }
        }
    }
    
    // MARK: - Bottom Interaction Area
    
    private var bottomInteractionArea: some View {
        Group {
            if microphoneAvailable {
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
                    switch interactionState {
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
                if case .idle = interactionState {
                    Text(currentAIAnswer != nil ? "\"What is it used for?\"" : "\"What is this?\"")
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
                    if !isHoldingSpeechButton && !isRequestInFlight {
                        isHoldingSpeechButton = true
                        startSpeechInput()
                    }
                }
                .onEnded { _ in
                    if isHoldingSpeechButton {
                        isHoldingSpeechButton = false
                        stopSpeechInput()
                    }
                }
        )
        .disabled(isRequestInFlight && !isHoldingSpeechButton)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceAreaAccessibilityLabel)
        .accessibilityValue(voiceAreaAccessibilityValue)
        .accessibilityHint(voiceAreaAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {
            handleVoiceAreaAccessibilityAction()
        }
        .accessibilityActionIf(named: "Repeat Answer", condition: currentAIAnswer != nil) {
            repeatLastAnswer()
        }
    }
    
    private var voiceAreaBackgroundColor: Color {
        switch interactionState {
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
        switch interactionState {
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
        switch interactionState {
        case .idle, .answered:
            return currentAIAnswer != nil ? "Hold and ask another question" : "Hold and ask a question"
        case .listening:
            return "Listening…"
        case .thinking:
            return "Thinking…"
        case .error:
            return "Try again"
        }
    }
    
    private var voiceAreaAccessibilityLabel: String {
        switch interactionState {
        case .listening:
            return "Recording question"
        case .thinking:
            return "Processing question"
        case .answered:
            return "Ask another question"
        case .error:
            return "Try asking again"
        case .idle:
            return currentAIAnswer != nil ? "Ask another question" : "Ask a question"
        }
    }
    
    private var voiceAreaAccessibilityValue: String {
        switch interactionState {
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
        switch interactionState {
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
    
    private func handleVoiceAreaAccessibilityAction() {
        if isHoldingSpeechButton || interactionState == .listening {
            isHoldingSpeechButton = false
            stopSpeechInput()
        } else if !isRequestInFlight {
            isHoldingSpeechButton = true
            startSpeechInput()
        }
    }
    
    private func repeatLastAnswer() {
        guard let answer = currentAIAnswer else { return }
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        AccessibilityVoiceService.shared.repeatAnswer(
            headline: answer.primaryHeadline,
            description: answer.detailedDescription,
            languageCode: speechService.selectedLocale.identifier
        )
    }
    
    // MARK: - Magic Tap & State Haptic Coordination (T012)
    
    private func handleMagicTapAccessibilityAction() {
        if currentAIAnswer != nil {
            repeatLastAnswer()
        } else {
            handleVoiceAreaAccessibilityAction()
        }
    }
    
    private func handleInteractionStateHaptics(_ state: InteractionState) {
        switch state {
        case .thinking:
            thinkingHapticTask?.cancel()
            thinkingHapticTask = Task { @MainActor in
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.prepare()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 800_000_000)
                    if Task.isCancelled { break }
                    generator.impactOccurred(intensity: 0.65)
                }
            }
        case .answered:
            thinkingHapticTask?.cancel()
            thinkingHapticTask = nil
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        case .error:
            thinkingHapticTask?.cancel()
            thinkingHapticTask = nil
            let errorFeedback = UINotificationFeedbackGenerator()
            errorFeedback.notificationOccurred(.error)
        case .idle, .listening:
            thinkingHapticTask?.cancel()
            thinkingHapticTask = nil
        }
    }
    
    // MARK: - Analyze Fallback Button (Microphone Denied)
    
    private var analyzeFallbackButton: some View {
        Button {
            triggerManualAnalysis()
        } label: {
            HStack(spacing: 8) {
                if isRequestInFlight {
                    ProgressView()
                        .scaleEffect(0.9)
                        .tint(.white)
                    Text("Analyzing…")
                        .font(.title3)
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .semibold))
                    Text("Analyze")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isRequestInFlight ? Color.gray.opacity(0.5) : Color.blue)
            )
        }
        .disabled(isRequestInFlight)
        .accessibilityLabel(isRequestInFlight ? "Analyzing image" : "Analyze what the camera sees")
        .accessibilityHint("Takes a photo and uses AI to identify and describe what is visible.")
    }
    
    // MARK: - Speech Feedback Card
    
    private var speechFeedbackCard: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(speechStatusDotColor)
                .frame(width: 8, height: 8)
            
            Text(speechCardText)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .lineLimit(2)
            
            Spacer()
            
            // Dismiss button (only when not actively listening/processing)
            if !speechService.status.isListening && !isProcessingVoiceQuery {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showSpeechCard = false
                        lastSpokenQuestion = nil
                        speechService.finalTranscript = ""
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(6)
                }
                .accessibilityLabel("Dismiss question")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your question: \(speechCardText)")
    }
    
    private var speechStatusDotColor: Color {
        if speechService.status.isListening {
            return .red
        } else if isProcessingVoiceQuery {
            return .blue
        } else {
            return .green
        }
    }
    
    private var speechCardText: String {
        if speechService.status.isListening {
            return speechService.partialTranscript.isEmpty ? "Listening…" : "\"\(speechService.partialTranscript)\""
        } else if isProcessingVoiceQuery, let q = lastSpokenQuestion {
            return "\"\(q)\""
        } else if let q = lastSpokenQuestion {
            return "You asked: \"\(q)\""
        } else if !speechService.finalTranscript.isEmpty {
            return "\"\(speechService.finalTranscript)\""
        } else if case .unauthorized(let msg) = speechService.status {
            return msg
        } else if case .unavailable(let msg) = speechService.status {
            return msg
        } else if case .failed(let msg) = speechService.status {
            return msg
        } else {
            return "Hold to ask a question."
        }
    }
    
    // MARK: - State Reset Helper
    
    private func resetSessionState() {
        stopThinkingHaptics()
        sceneDivergenceStartTime = nil
        lastAnalyzedScene = nil
        currentAIAnswer = nil
        liveVisionInterpretation = .initial
        isRequestInFlight = false
        isProcessingVoiceQuery = false
        pendingVoiceSnapshot = nil
        pendingVoiceReference = nil
        interactionState = .idle
        interpretationService.resetStability()
    }
    
    // MARK: - Thinking State Haptic Heartbeat
    
    private func startThinkingHaptics() {
        stopThinkingHaptics()
        thinkingHapticTask = Task { @MainActor in
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.prepare()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000) // 1.2s interval
                if Task.isCancelled { break }
                generator.impactOccurred(intensity: 0.6)
                generator.prepare()
            }
        }
    }
    
    private func stopThinkingHaptics() {
        thinkingHapticTask?.cancel()
        thinkingHapticTask = nil
    }
    
    // MARK: - Simplified Interpretation Card
    
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
                if currentAIAnswer != nil {
                    Button {
                        repeatLastAnswer()
                    } label: {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(8)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .accessibilityLabel(speechService.isIndonesian ? "Ulangi jawaban" : "Repeat answer")
                    .accessibilityHint(speechService.isIndonesian ? "Ketuk dua kali untuk mendengarkan kembali jawaban ini." : "Double-tap to hear this answer again.")
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
                .fill(Color.black.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(interpretationAccessibilityLabel(interpretation))
        .accessibilityActionIf(named: "Repeat Answer", condition: currentAIAnswer != nil) {
            repeatLastAnswer()
        }
    }
    
    // MARK: - Confidence Helpers (Simplified)
    
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
        case .conflicting: return "Conflicting information"
        case .insufficient: return ""
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
                Text("Trigger: \(lastTriggerType)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(lastTriggerType == "Voice" ? .purple : .blue)
            }
            
            if let q = lastSpokenQuestion {
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
                    .foregroundStyle(speechService.status.isListening ? .red : .white)
                
                Spacer()
                
                Text("Speech Duration:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(speechService.lastRecordingDuration > 0 ? "\(String(format: "%.1f", speechService.lastRecordingDuration))s" : "N/A")
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
                Text(lastGeminiLatencyMs > 0 ? "\(Int(lastGeminiLatencyMs))ms" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("Total Turnaround:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(lastPerceivedTurnaroundMs > 0 ? "\(Int(lastPerceivedTurnaroundMs))ms" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Snapshot Size:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(lastAnalyzedPayloadBytes > 0 ? "\(lastAnalyzedPayloadBytes / 1024) KB" : "N/A")
                    .font(.caption2)
                    .foregroundStyle(.white)
            }
            
            HStack {
                Text("Multimodal Status:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(lastMultimodalStatus.displayTelemetryTitle)
                    .font(.caption2)
                    .foregroundStyle(lastMultimodalStatus.isRateLimited ? .orange : .white)
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
                Text(activeConversationThread != nil ? "Active (\(activeConversationThread!.turnCount) turns)" : "None (New Scene)")
                    .font(.caption2)
                    .foregroundStyle(activeConversationThread != nil ? .green : .white)
                
                Spacer()
                
                Text("Divergence:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.2f", lastDivergenceScore))
                    .font(.caption2)
                    .foregroundStyle(lastDivergenceScore >= SceneStabilityConfiguration.divergenceThreshold ? .orange : .white)
            }
            
            HStack {
                Text("Sources:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(displayedInterpretation.contributingSources) { source in
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
                Text(displayedInterpretation.confidence.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.white)
                
                Spacer()
                
                Text("Mic Available:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(microphoneAvailable ? "Yes" : "No (Fallback)")
                    .font(.caption2)
                    .foregroundStyle(microphoneAvailable ? .green : .orange)
            }
        }
    }
    
    private var speechStatusTelemetryTitle: String {
        switch speechService.status {
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
