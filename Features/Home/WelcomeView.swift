import AVFoundation
import SwiftUI

// MARK: - Onboarding Step

private enum OnboardingStep: Int, CaseIterable {
    case introduction = 0
    case voiceTutorial = 1
    case ready = 2
}

// MARK: - Voice Tutorial State

private enum TutorialState: Equatable {
    case idle
    case listening
    case processing
    case success(String)
    case empty
    case unavailable
}

// MARK: - WelcomeView (Interactive 3-Screen Onboarding)

/// Accessible, polished first-launch onboarding following Design Principles B + C:
/// - B: Contextual Primary Action (Permissions -> Voice Area -> Get Started)
/// - C: Consistent Bottom Interaction Zone (Spatial anchor matching CameraView)
struct WelcomeView: View {
    
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentStep: OnboardingStep = .introduction
    @State private var tutorialState: TutorialState = .idle
    @State private var speechService = SpeechService()
    @State private var isHolding = false
    @State private var hasPermissions = false
    @State private var permissionsChecked = false
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Top Navigation Bar (Progress Dots & Contextual Secondary Action)
                topNavigationBar
                    .padding(.top, 16)
                    .padding(.horizontal, 24)
                
                Spacer()
                
                // Screen Content Area
                Group {
                    switch currentStep {
                    case .introduction:
                        introductionContent
                    case .voiceTutorial:
                        voiceTutorialContent
                    case .ready:
                        readyContent
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.easeInOut(duration: 0.35), value: currentStep)
                
                Spacer()
                
                // Bottom Interaction Zone (Consistent Spatial Anchor across all screens)
                bottomInteractionZone
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                AccessibilityVoiceService.shared.speak(
                    "Welcome to TestApp, your visual assistant. TestApp uses your camera and microphone to describe what is around you. Tap the Set Up Permissions button at the bottom of the screen to get started."
                )
            }
        }
        .onDisappear {
            speechService.cancelRecording()
            AccessibilityVoiceService.shared.stopSpeaking()
        }
    }
    
    // MARK: - Top Navigation Bar
    
    private var topNavigationBar: some View {
        HStack {
            // Balance spacer on the left
            Color.clear
                .frame(width: 60, height: 32)
                .accessibilityHidden(true)
            
            Spacer()
            
            // Progress Indicator (Step X of 3)
            progressDots
            
            Spacer()
            
            // Contextual Secondary Action (Skip Practice on Screen 2)
            if currentStep == .voiceTutorial {
                Button {
                    skipPractice()
                } label: {
                    Text("Skip")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color(.secondarySystemBackground))
                        )
                }
                .frame(width: 60, height: 32, alignment: .trailing)
                .accessibilityLabel("Skip voice practice")
                .accessibilityHint("Advances directly to the final step.")
            } else {
                Color.clear
                    .frame(width: 60, height: 32)
                    .accessibilityHidden(true)
            }
        }
    }
    
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == currentStep ? Color.blue : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }
    
    // MARK: - Screen 1: Introduction Content
    
    private var introductionContent: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.blue)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 10) {
                Text("Meet your visual assistant")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Point your camera at anything around you and ask questions to get clear spoken answers.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            // Feature Highlights
            VStack(alignment: .leading, spacing: 14) {
                featureRow(icon: "camera.fill", title: "Visual Understanding", description: "Describes objects, text, and details in your surroundings.")
                featureRow(icon: "waveform", title: "Natural Voice", description: "Hold the bottom of the screen to ask questions in your own words.")
            }
            .padding(.top, 6)
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to TestApp, your visual assistant. TestApp uses your camera and microphone to describe what is around you. Point your camera at anything around you and ask questions to get clear spoken answers. Tap the Set Up Permissions button at the bottom of the screen to get started.")
    }
    
    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Screen 2: Interactive Voice Tutorial Content
    
    private var voiceTutorialContent: some View {
        VStack(spacing: 18) {
            // Heading & instructions
            VStack(spacing: 10) {
                Text("Try asking a question")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Touch and hold the microphone at the bottom of the screen while speaking, then release when finished.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            // Feedback Card or Suggested Prompt
            if case .success(let transcript) = tutorialState {
                successFeedbackCard(transcript: transcript)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else if tutorialState == .empty {
                emptyFeedbackCard
                    .transition(.opacity)
            } else if tutorialState == .unavailable {
                unavailableFeedbackCard
                    .transition(.opacity)
            } else {
                suggestedPromptCard
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var suggestedPromptCard: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
                
                Text("Try saying:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Text("\"What is this?\"")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
            
            Text("or ask about anything nearby")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Suggested question: What is this? Touch and hold the microphone at the bottom of the screen to ask.")
    }
    
    private func successFeedbackCard(transcript: String) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 48, height: 48)
                
                Image(systemName: "checkmark")
                    .font(.title3.bold())
                    .foregroundStyle(.green)
            }
            
            VStack(spacing: 4) {
                Text("You asked:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\"\(transcript)\"")
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            Text("That is how you ask TestApp questions. In the live camera, you'll receive a spoken answer instantly.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Practice successful. You asked: \(transcript). Tap Continue at the bottom of the screen to finish setup.")
    }
    
    private var emptyFeedbackCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text("I didn't hear a question.")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Hold the microphone at the bottom and speak clearly, or tap Skip at the top.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("I didn't hear a question. Hold the microphone at the bottom of the screen to try again, or tap Skip in the top right.")
    }
    
    private var unavailableFeedbackCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Microphone access is needed")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("You can enable microphone permission in iOS Settings to ask questions.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Microphone access is needed. You can enable microphone permission in iOS Settings.")
    }
    
    // MARK: - Screen 3: Ready Content
    
    private var readyContent: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 96, height: 96)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56, weight: .regular))
                    .foregroundStyle(.green)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 10) {
                Text("You're ready")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Point your camera at anything and hold the bottom area to ask questions such as:")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            // Example question cards
            VStack(spacing: 10) {
                exampleCard(icon: "questionmark.circle.fill", text: "\"What is this?\"")
                exampleCard(icon: "info.circle.fill", text: "\"What is it used for?\"")
                exampleCard(icon: "doc.text.viewfinder", text: "\"What does this label say?\"")
            }
            .padding(.horizontal, 8)
        }
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You are ready. Point your camera at anything and hold the bottom of the screen to ask what you would like to know. For example: What is this? What is it used for? Or: What does this label say? Tap the Get Started button at the bottom of the screen to open the live camera.")
    }
    
    private func exampleCard(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
            
            Text(text)
                .font(.body)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
            
            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    // MARK: - Bottom Interaction Zone (Spatial Consistency with CameraView)
    
    @ViewBuilder
    private var bottomInteractionZone: some View {
        switch currentStep {
        case .introduction:
            // Screen 1: Set Up Permissions Button
            Button {
                advanceStep()
            } label: {
                Text("Set Up Permissions")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Set Up Permissions")
            .accessibilityHint("Requests camera and microphone permissions, then proceeds to practice asking a question.")
            
        case .voiceTutorial:
            // Screen 2: Contextual Bottom Interaction
            if case .success = tutorialState {
                // When practice has been completed: Prominent Continue button in bottom zone
                Button {
                    advanceStep()
                } label: {
                    Text("Continue")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel("Continue")
                .accessibilityHint("Advances to the final step.")
            } else {
                // Primary interaction: Voice Area (Exact match with CameraView's bottom voice area)
                onboardingVoiceArea
            }
            
        case .ready:
            // Screen 3: Get Started Button
            Button {
                advanceStep()
            } label: {
                Text("Get Started")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel("Get Started")
            .accessibilityHint("Completes onboarding and opens the live camera viewfinder.")
        }
    }
    
    // MARK: - Onboarding Voice Area (120pt Bottom Card matching CameraView)
    
    private var onboardingVoiceArea: some View {
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
                    switch tutorialState {
                    case .listening:
                        Image(systemName: "waveform")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    case .processing:
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
                
                // Partial transcript while listening or hint text when idle
                if tutorialState == .listening, !speechService.partialTranscript.isEmpty {
                    Text("\"\(speechService.partialTranscript)\"")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                } else if tutorialState == .idle || tutorialState == .empty {
                    Text("\"What is this?\"")
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
                    guard !isHolding else { return }
                    guard tutorialState != .processing else { return }
                    isHolding = true
                    beginTutorialSpeech()
                }
                .onEnded { _ in
                    guard isHolding else { return }
                    isHolding = false
                    endTutorialSpeech()
                }
        )
        .disabled(tutorialState == .processing)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(voiceAreaAccessibilityLabel)
        .accessibilityHint(voiceAreaAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {
            // VoiceOver double-tap toggle
            if isHolding || tutorialState == .listening {
                isHolding = false
                endTutorialSpeech()
            } else if tutorialState != .processing {
                isHolding = true
                beginTutorialSpeech()
            }
        }
    }
    
    // MARK: - Voice Area Styling (100% Consistent with CameraView)
    
    private var voiceAreaBackgroundColor: Color {
        switch tutorialState {
        case .listening:
            return Color.red.opacity(0.75)
        case .processing:
            return Color.blue.opacity(0.6)
        default:
            return Color.black.opacity(0.65)
        }
    }
    
    private var voiceAreaBorderColor: Color {
        switch tutorialState {
        case .listening:
            return Color.red.opacity(0.9)
        case .processing:
            return Color.blue.opacity(0.7)
        default:
            return Color.white.opacity(0.2)
        }
    }
    
    private var voiceAreaLabel: String {
        switch tutorialState {
        case .idle, .empty:
            return "Hold and ask a question"
        case .listening:
            return "Listening…"
        case .processing:
            return "Thinking…"
        case .success:
            return "Done"
        case .unavailable:
            return "Microphone unavailable"
        }
    }
    
    private var voiceAreaAccessibilityLabel: String {
        switch tutorialState {
        case .listening:
            return "Recording question"
        case .processing:
            return "Processing question"
        case .success(let t):
            return "Practice complete. You said: \(t)."
        case .empty:
            return "Try asking again"
        case .unavailable:
            return "Voice practice unavailable"
        case .idle:
            return "Practice asking a question"
        }
    }
    
    private var voiceAreaAccessibilityHint: String {
        switch tutorialState {
        case .listening:
            return "Double-tap to stop recording, or release hold."
        case .processing:
            return "Please wait while your question is analyzed."
        case .success:
            return "Double-tap to practice asking again, or tap Continue below."
        case .idle, .empty:
            return "Double-tap to start speaking, or press and hold the bottom of the screen while speaking."
        case .unavailable:
            return "Tap Skip in the top right to continue."
        }
    }
    
    // MARK: - Proactive Permissions Setup
    
    private func requestAllPermissions() async -> Bool {
        // 1. Camera permission
        let cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        let cameraGranted: Bool
        if cameraStatus == .authorized {
            cameraGranted = true
        } else if cameraStatus == .notDetermined {
            cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        } else {
            cameraGranted = false
        }
        
        // 2. Microphone & Speech Recognition
        let speechGranted = await speechService.requestPermissions()
        
        await MainActor.run {
            self.permissionsChecked = true
            self.hasPermissions = speechGranted
        }
        
        return cameraGranted && speechGranted
    }
    
    // MARK: - Tutorial Speech Actions
    
    private func beginTutorialSpeech() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.15)) {
            tutorialState = .listening
        }
        
        AccessibilityVoiceService.shared.speak("Listening.")
        
        Task {
            if !permissionsChecked {
                _ = await requestAllPermissions()
            }
            
            guard hasPermissions else {
                await MainActor.run {
                    isHolding = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tutorialState = .unavailable
                    }
                    AccessibilityVoiceService.shared.speak(
                        "Microphone permission was not granted. Tap Skip at the top right to continue."
                    )
                }
                return
            }
            
            speechService.startRecording()
        }
    }
    
    private func endTutorialSpeech() {
        guard tutorialState == .listening else { return }
        
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.15)) {
            tutorialState = .processing
        }
        
        Task {
            guard let transcript = await speechService.stopRecordingAndGetTranscript(),
                  !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tutorialState = .empty
                    }
                    AccessibilityVoiceService.shared.speak(
                        "I didn't hear a question. Hold the microphone at the bottom to try again, or tap Skip at the top right."
                    )
                }
                return
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    tutorialState = .success(transcript)
                }
                AccessibilityVoiceService.shared.speak(
                    "Great job! You asked: \(transcript). Tap Continue at the bottom of the screen to finish setup."
                )
            }
        }
    }
    
    // MARK: - Navigation Actions
    
    private func skipPractice() {
        speechService.cancelRecording()
        withAnimation(.easeInOut(duration: 0.35)) {
            currentStep = .ready
        }
        AccessibilityVoiceService.shared.speak(
            "Step 3 of 3: You are ready! Point your camera at anything, touch and hold the bottom of the screen to ask what you would like to know, and release to hear an answer. Tap Get Started at the bottom of the screen to open the camera."
        )
    }
    
    private func advanceStep() {
        if currentStep == .introduction {
            Task {
                AccessibilityVoiceService.shared.speak("Setting up camera and microphone access. Please allow permissions when prompted.")
                _ = await requestAllPermissions()
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .voiceTutorial
                    }
                    AccessibilityVoiceService.shared.speak(
                        "Step 2 of 3: Try asking a question. Touch and hold the microphone at the bottom of the screen while speaking, then release when finished. For example, ask: What is this? Or tap Skip in the top right to continue."
                    )
                }
            }
            return
        }
        
        // Clean up speech if leaving tutorial
        if currentStep == .voiceTutorial {
            speechService.cancelRecording()
        }
        
        withAnimation(.easeInOut(duration: 0.35)) {
            switch currentStep {
            case .introduction:
                break
            case .voiceTutorial:
                currentStep = .ready
                AccessibilityVoiceService.shared.speak(
                    "Step 3 of 3: You are ready! Point your camera at anything, touch and hold the bottom of the screen to ask what you would like to know, and release to hear an answer. Tap Get Started at the bottom of the screen to open the camera."
                )
            case .ready:
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
