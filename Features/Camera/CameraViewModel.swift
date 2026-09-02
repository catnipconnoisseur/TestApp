import AVFoundation
import Combine
import Foundation
import Speech
import SwiftUI
import UIKit
import Vision

// MARK: - Interaction State

/// Describes the user-facing state of the voice interaction area.
enum InteractionState: Equatable, Sendable {
    case idle
    case listening
    case thinking
    case answered
    case error(String)
}

// MARK: - Camera View Model

/// Central ViewModel coordinating camera feed, on-device vision, speech recognition,
/// multimodal reasoning, scene-anchored conversational memory, and accessibility audio/haptics.
@MainActor
final class CameraViewModel: ObservableObject {
    
    // Dependencies & Sub-Services
    let cameraManager = CameraManager()
    let multimodalService = MultimodalService()
    @Published var speechService = SpeechService()
    let interpretationService = InterpretationService()
    
    // Scene Anchoring & Conversational Memory (T009)
    @Published var activeConversationThread: SceneConversationThread? = nil
    
    // State Tracking
    @Published var lastAnalyzedScene: AnalyzedSceneReference? = nil
    @Published var sceneDivergenceStartTime: Date? = nil
    @Published var lastVisualObservationTime: Date = Date()
    
    // Conversation State & Persistent AI Answer
    @Published var currentAIAnswer: InterpretationResult? = nil
    @Published var liveVisionInterpretation: InterpretationResult = .initial
    
    // Request State & In-Flight Guards
    @Published var isRequestInFlight: Bool = false
    @Published var isProcessingVoiceQuery: Bool = false
    @Published var lastRequestTimestamp: Date = .distantPast
    @Published var lastTriggerType: String = "None"
    
    // Speech Input & Voice Snapshot State
    @Published var isHoldingSpeechButton: Bool = false
    @Published var showSpeechCard: Bool = false
    @Published var lastSpokenQuestion: String? = nil
    @Published var pendingVoiceSnapshot: Data? = nil
    @Published var pendingVoiceReference: AnalyzedSceneReference? = nil
    
    // Interaction State
    @Published var interactionState: InteractionState = .idle
    
    // UI Sheets & Configuration
    @Published var showSettingsSheet: Bool = false
    @Published var showRawTelemetry: Bool = false
    @Published var microphoneAvailable: Bool = true
    @Published var hasAnnouncedCameraArrival: Bool = false
    
    // Diagnostic Telemetry (Developer View)
    @Published var lastGeminiLatencyMs: Double = 0.0
    @Published var lastPerceivedTurnaroundMs: Double = 0.0
    @Published var lastAnalyzedPayloadBytes: Int = 0
    @Published var lastMultimodalStatus: MultimodalService.ResponseStatus = .idle
    @Published var lastDivergenceScore: Float = 0.0
    
    // Background Haptic Task (T012)
    private var thinkingHapticTask: Task<Void, Never>? = nil
    
    // Computed Current Interpretation
    var displayedInterpretation: InterpretationResult {
        if let aiAnswer = currentAIAnswer {
            return aiAnswer
        }
        return liveVisionInterpretation
    }
    
    // MARK: - Lifecycle Handlers
    
    func onAppear() {
        cameraManager.requestAccessAndSetup()
        checkAndAnnounceLaunchState()
    }
    
    func onDisappear() {
        cameraManager.stopSession()
        speechService.cancelRecording()
        stopThinkingHaptics()
        AccessibilityVoiceService.shared.stopSpeaking()
        resetSessionState()
    }
    
    func handleScenePhaseChange(_ newPhase: ScenePhase) {
        if newPhase == .active {
            cameraManager.requestAccessAndSetup()
            checkAndAnnounceLaunchState()
        }
    }
    
    func checkAndAnnounceLaunchState() {
        let isQuickAccess = UserDefaults.standard.bool(forKey: "launchedFromQuickAccess")
        if isQuickAccess {
            UserDefaults.standard.set(false, forKey: "launchedFromQuickAccess")
            hasAnnouncedCameraArrival = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let msg = self.speechService.isIndonesian
                    ? "TestApp siap. Tahan bagian bawah layar untuk bertanya."
                    : "TestApp ready. Touch and hold the bottom of the screen to ask a question."
                AccessibilityVoiceService.shared.speak(msg, languageCode: self.speechService.selectedLocale.identifier)
            }
        } else if !hasAnnouncedCameraArrival {
            hasAnnouncedCameraArrival = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                let arrivalMsg = self.speechService.isIndonesian
                    ? "Kamera siap. Tahan bagian bawah layar untuk bertanya."
                    : "Camera ready. Touch and hold the bottom of the screen to ask a question."
                AccessibilityVoiceService.shared.speak(arrivalMsg, languageCode: self.speechService.selectedLocale.identifier)
            }
        }
    }
    
    // MARK: - Continuous Vision & Scene Divergence Tracking (T005 + T009)
    
    func handleIncomingVisionFrame(_ result: RecognitionResult) {
        let now = Date()
        guard now.timeIntervalSince(lastVisualObservationTime) >= 0.15 else { return }
        lastVisualObservationTime = now
        
        let localInterpretation = interpretationService.interpret(
            recognition: result,
            locale: speechService.selectedLocale
        )
        
        if currentAIAnswer == nil {
            liveVisionInterpretation = localInterpretation
        }
        
        // Evaluate scene divergence against active conversation anchor
        if let thread = activeConversationThread {
            let divergence = interpretationService.computeSceneDivergence(
                current: result,
                reference: thread.anchorScene
            )
            lastDivergenceScore = divergence.score
            
            if divergence.score >= SceneStabilityConfiguration.divergenceThreshold {
                if let startTime = sceneDivergenceStartTime {
                    if now.timeIntervalSince(startTime) >= SceneStabilityConfiguration.confirmationDuration {
                        print("[MEMORY] Scene divergence sustained (\(String(format: "%.2f", divergence.score)) for \(String(format: "%.2f", now.timeIntervalSince(startTime)))s) -> Resetting active conversation thread.")
                        activeConversationThread = nil
                        sceneDivergenceStartTime = nil
                    }
                } else {
                    sceneDivergenceStartTime = now
                }
            } else {
                sceneDivergenceStartTime = nil
            }
        } else if let reference = lastAnalyzedScene {
            let divergence = interpretationService.computeSceneDivergence(
                current: result,
                reference: reference
            )
            lastDivergenceScore = divergence.score
            
            if divergence.score >= SceneStabilityConfiguration.divergenceThreshold {
                if let startTime = sceneDivergenceStartTime {
                    if now.timeIntervalSince(startTime) >= SceneStabilityConfiguration.confirmationDuration {
                        lastAnalyzedScene = nil
                        sceneDivergenceStartTime = nil
                    }
                } else {
                    sceneDivergenceStartTime = now
                }
            } else {
                sceneDivergenceStartTime = nil
            }
        } else {
            sceneDivergenceStartTime = nil
            lastDivergenceScore = 0.0
        }
    }
    
    // MARK: - Voice Input Actions
    
    func startSpeechInput() {
        guard !isRequestInFlight else { return }
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // 1. Capture camera frame snapshot at button press (t=0)
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
    
    func stopSpeechInput() {
        guard isHoldingSpeechButton == false else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        Task {
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
    
    // MARK: - Multimodal Submission & Multi-Turn Threading (T009)
    
    func submitQuestion(
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
    
    // MARK: - Manual Analysis Fallback (Microphone Denied)
    
    func triggerManualAnalysis() {
        guard let jpegData = cameraManager.captureCurrentFrameJPEG() else { return }
        let sceneRef = AnalyzedSceneReference(
            dominantClassification: cameraManager.latestResult.topClassification?.identifier,
            ocrTextFingerprint: cameraManager.latestResult.combinedText,
            featurePrint: cameraManager.latestResult.featurePrint,
            analyzedAt: Date()
        )
        
        let genericPrompt = speechService.isIndonesian ? "Jelaskan apa yang ada di depan kamera." : "What is this?"
        submitQuestion(genericPrompt, capturedSnapshot: jpegData, sceneReference: sceneRef, triggerType: "Manual")
    }
    
    // MARK: - Gemini Failure Handling
    
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
        
        if currentAIAnswer == nil {
            let localFallback = interpretationService.interpret(
                recognition: cameraManager.latestResult,
                locale: speechService.selectedLocale
            )
            liveVisionInterpretation = InterpretationResult(
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
            interactionState = .error(userMessage)
        }
        
        AccessibilityVoiceService.shared.speak(userMessage, languageCode: speechService.selectedLocale.identifier)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if case .error = self.interactionState {
                self.interactionState = .idle
            }
        }
    }
    
    // MARK: - Answer Replay & Accessibility Actions (T012)
    
    func repeatLastAnswer() {
        guard let answer = currentAIAnswer else { return }
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()
        AccessibilityVoiceService.shared.repeatAnswer(
            headline: answer.primaryHeadline,
            description: answer.detailedDescription,
            languageCode: speechService.selectedLocale.identifier
        )
    }
    
    func handleMagicTapAccessibilityAction() {
        if currentAIAnswer != nil {
            repeatLastAnswer()
        } else {
            handleVoiceAreaAccessibilityAction()
        }
    }
    
    func handleVoiceAreaAccessibilityAction() {
        if isHoldingSpeechButton || interactionState == .listening {
            isHoldingSpeechButton = false
            stopSpeechInput()
        } else if !isRequestInFlight {
            isHoldingSpeechButton = true
            startSpeechInput()
        }
    }
    
    func handleInteractionStateHaptics(_ state: InteractionState) {
        switch state {
        case .thinking:
            startThinkingHaptics()
        case .answered:
            stopThinkingHaptics()
        case .error:
            stopThinkingHaptics()
        case .idle, .listening:
            stopThinkingHaptics()
        }
    }
    
    private func startThinkingHaptics() {
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
    }
    
    func stopThinkingHaptics() {
        thinkingHapticTask?.cancel()
        thinkingHapticTask = nil
    }
    
    func resetSessionState() {
        activeConversationThread = nil
        lastAnalyzedScene = nil
        sceneDivergenceStartTime = nil
        isRequestInFlight = false
        interactionState = .idle
    }
}
