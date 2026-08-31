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

/// First-launch onboarding that teaches the core interaction through experience.
/// Screen 1: What the app is. Screen 2: Practice hold-to-speak. Screen 3: Go.
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
                Spacer()
                
                // Current screen content
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
                
                // Bottom: progress dots + action button
                VStack(spacing: 20) {
                    progressDots
                    bottomAction
                }
                .padding(.bottom, 48)
            }
        }
        .onDisappear {
            speechService.cancelRecording()
        }
    }
    
    // MARK: - Screen 1: Introduction
    
    private var introductionContent: some View {
        VStack(spacing: 20) {
            Image(systemName: "eye.circle.fill")
                .font(.system(size: 64, weight: .thin))
                .foregroundStyle(.blue)
                .accessibilityHidden(true)
            
            Text("Meet your visual assistant")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            Text("Ask questions about what your camera sees.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Meet your visual assistant. Ask questions about what your camera sees.")
    }
    
    // MARK: - Screen 2: Interactive Voice Tutorial
    
    private var voiceTutorialContent: some View {
        VStack(spacing: 0) {
            // Heading
            VStack(spacing: 12) {
                Text("Try asking a question")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                if tutorialState == .idle || tutorialState == .empty {
                    VStack(spacing: 4) {
                        Text("Hold below and ask:")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        Text("\"What is this?\"")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .italic()
                    }
                }
            }
            .padding(.horizontal, 32)
            
            Spacer()
                .frame(minHeight: 24, maxHeight: 40)
            
            // Result area (after success or empty)
            if case .success(let transcript) = tutorialState {
                successFeedback(transcript: transcript)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(minHeight: 16, maxHeight: 24)
            }
            
            if tutorialState == .empty {
                emptyFeedback
                    .transition(.opacity)
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(minHeight: 16, maxHeight: 24)
            }
            
            if tutorialState == .unavailable {
                unavailableFeedback
                    .transition(.opacity)
                    .padding(.horizontal, 32)
                
                Spacer()
                    .frame(minHeight: 16, maxHeight: 24)
            }
            
            // Interactive voice area (when not showing success)
            if tutorialState != .unavailable {
                tutorialVoiceArea
                    .padding(.horizontal, 24)
            }
        }
    }
    
    // MARK: - Tutorial Voice Area (Large, Interactive)
    
    private var tutorialVoiceArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20)
                .fill(tutorialAreaBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(tutorialAreaBorder, lineWidth: 1.5)
                )
            
            VStack(spacing: 10) {
                // State icon
                Group {
                    switch tutorialState {
                    case .listening:
                        Image(systemName: "waveform")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                            .symbolEffect(.variableColor.iterative, isActive: true)
                    case .processing:
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(.white)
                    case .success:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white)
                    default:
                        Image(systemName: "mic.fill")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .frame(height: 36)
                
                // State label
                Text(tutorialAreaLabel)
                    .font(.headline)
                    .foregroundStyle(.white)
                
                // Partial transcript while listening
                if tutorialState == .listening, !speechService.partialTranscript.isEmpty {
                    Text("\"\(speechService.partialTranscript)\"")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                        .transition(.opacity)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 130)
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
        .accessibilityLabel(tutorialAreaAccessibilityLabel)
        .accessibilityHint(tutorialAreaAccessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(.default) {
            // VoiceOver double-tap toggles recording
            if isHolding || tutorialState == .listening {
                isHolding = false
                endTutorialSpeech()
            } else if tutorialState != .processing {
                isHolding = true
                beginTutorialSpeech()
            }
        }
    }
    
    // MARK: - Tutorial Speech Actions
    
    private func beginTutorialSpeech() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.15)) {
            tutorialState = .listening
        }
        
        UIAccessibility.post(notification: .announcement, argument: "Listening")
        
        Task {
            if !permissionsChecked {
                let granted = await speechService.requestPermissions()
                permissionsChecked = true
                hasPermissions = granted
                
                if !granted {
                    await MainActor.run {
                        isHolding = false
                        withAnimation(.easeInOut(duration: 0.2)) {
                            tutorialState = .unavailable
                        }
                        UIAccessibility.post(
                            notification: .announcement,
                            argument: "Voice practice isn't available. Microphone or speech permission was not granted. You can skip this step."
                        )
                    }
                    return
                }
            } else if !hasPermissions {
                await MainActor.run {
                    isHolding = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tutorialState = .unavailable
                    }
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
            guard let transcript = await speechService.stopRecordingAndGetTranscript() else {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tutorialState = .empty
                    }
                    UIAccessibility.post(
                        notification: .announcement,
                        argument: "I didn't hear anything. You can try again or continue."
                    )
                }
                return
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    tutorialState = .success(transcript)
                }
                UIAccessibility.post(
                    notification: .announcement,
                    argument: "You asked: \(transcript). That's how you talk to me."
                )
            }
        }
    }
    
    // MARK: - Success Feedback
    
    private func successFeedback(transcript: String) -> some View {
        VStack(spacing: 8) {
            Text("You asked:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Text("\"\(transcript)\"")
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            
            Text("That's how you talk to me.")
                .font(.body)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You asked: \(transcript). That's how you talk to me.")
    }
    
    // MARK: - Empty Speech Feedback
    
    private var emptyFeedback: some View {
        Text("I didn't hear anything. Try again or continue.")
            .font(.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .accessibilityLabel("I didn't hear anything. You can try again or continue.")
    }
    
    // MARK: - Unavailable Feedback
    
    private var unavailableFeedback: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("Voice practice isn't available right now.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("You can set up microphone access later in Settings.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Voice practice isn't available right now. You can set up microphone access later in Settings.")
    }
    
    // MARK: - Screen 3: Ready
    
    private var readyContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.green)
                .accessibilityHidden(true)
            
            VStack(spacing: 14) {
                Text("You're ready")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("Point your camera at something and ask what you'd like to know.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Example questions
            VStack(spacing: 8) {
                exampleQuestion("\"What is this?\"")
                exampleQuestion("\"What is it used for?\"")
                exampleQuestion("\"What does this label say?\"")
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 32)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You're ready. Point your camera at something and ask what you'd like to know. For example: What is this? What is it used for? What does this label say?")
    }
    
    private func exampleQuestion(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .italic()
            .foregroundStyle(.blue.opacity(0.7))
    }
    
    // MARK: - Progress Dots
    
    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                Circle()
                    .fill(step == currentStep ? Color.blue : Color(.systemGray4))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityHidden(true)
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }
    
    // MARK: - Bottom Action Button
    
    private var bottomAction: some View {
        Button {
            advanceStep()
        } label: {
            Text(bottomActionLabel)
                .font(.title3)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .padding(.horizontal, 32)
        .accessibilityLabel(bottomActionAccessibilityLabel)
        .accessibilityHint(bottomActionAccessibilityHint)
    }
    
    // MARK: - Navigation Logic
    
    private func advanceStep() {
        // Clean up speech if leaving tutorial
        if currentStep == .voiceTutorial {
            speechService.cancelRecording()
        }
        
        withAnimation(.easeInOut(duration: 0.35)) {
            switch currentStep {
            case .introduction:
                currentStep = .voiceTutorial
            case .voiceTutorial:
                currentStep = .ready
            case .ready:
                hasCompletedOnboarding = true
            }
        }
    }
    
    // MARK: - Computed Labels
    
    private var bottomActionLabel: String {
        switch currentStep {
        case .introduction:
            return "Continue"
        case .voiceTutorial:
            switch tutorialState {
            case .success:
                return "Continue"
            case .unavailable:
                return "Continue without practicing"
            default:
                return "Skip"
            }
        case .ready:
            return "Get Started"
        }
    }
    
    private var bottomActionAccessibilityLabel: String {
        switch currentStep {
        case .introduction:
            return "Continue"
        case .voiceTutorial:
            if case .success = tutorialState {
                return "Continue"
            } else if tutorialState == .unavailable {
                return "Continue without practicing"
            }
            return "Skip voice tutorial"
        case .ready:
            return "Get Started"
        }
    }
    
    private var bottomActionAccessibilityHint: String {
        switch currentStep {
        case .ready:
            return "Opens the camera."
        default:
            return ""
        }
    }
    
    // MARK: - Tutorial Voice Area Styling
    
    private var tutorialAreaBackground: Color {
        switch tutorialState {
        case .listening:
            return Color.red.opacity(0.75)
        case .processing:
            return Color.blue.opacity(0.6)
        case .success:
            return Color.green.opacity(0.6)
        default:
            return Color(.systemGray2)
        }
    }
    
    private var tutorialAreaBorder: Color {
        switch tutorialState {
        case .listening:
            return Color.red.opacity(0.9)
        case .success:
            return Color.green.opacity(0.7)
        default:
            return Color.clear
        }
    }
    
    private var tutorialAreaLabel: String {
        switch tutorialState {
        case .idle, .empty:
            return "Hold and speak"
        case .listening:
            return "Listening…"
        case .processing:
            return "Processing…"
        case .success:
            return "Done"
        case .unavailable:
            return ""
        }
    }
    
    private var tutorialAreaAccessibilityLabel: String {
        switch tutorialState {
        case .listening:
            return "Listening to your question. Double-tap to stop."
        case .processing:
            return "Processing your speech."
        case .success(let t):
            return "You said: \(t). You can try again or continue."
        case .empty:
            return "I didn't hear anything. Hold and speak to try again."
        default:
            return "Hold and speak to try asking a question."
        }
    }
    
    private var tutorialAreaAccessibilityHint: String {
        switch tutorialState {
        case .idle, .empty, .success:
            return "Double-tap to start speaking, then double-tap again to stop."
        default:
            return ""
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
