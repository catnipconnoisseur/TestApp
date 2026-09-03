import AVFoundation
import Speech
import SwiftUI

// MARK: - Onboarding Step

private enum OnboardingStep: Int, CaseIterable {
    case welcome = 0          // Screen 1: Welcome & Value Proposition
    case permissionsSetup = 1 // Screen 2: Central Setup Hub (Required Permissions + Optional Quick Access)
    case tryAsking = 2        // Screen 3: Interactive Voice Tutorial
    case ready = 3            // Screen 4: Ready / Get Started
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

// MARK: - WelcomeView (Interactive 4-Step Onboarding)

/// Accessible first-launch onboarding following the corrected flow:
/// **Welcome → Permissions / Setup → Try Asking → Get Started**
///
/// Principles:
/// - Contextual Primary Action: Welcome -> Setup Hub -> Voice Practice -> Ready
/// - Consistent Bottom Interaction Zone: 120pt spatial anchor matching CameraView
/// - Non-blocking Quick Access: Optional setup configured on the Permissions/Setup page
struct WelcomeView: View {
    
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentStep: OnboardingStep = .welcome
    @State private var tutorialState: TutorialState = .idle
    @State private var speechService = SpeechService()
    @State private var isHolding = false
    @State private var showQuickAccessSheet = false
    @AppStorage("hasCompletedQuickAccessSetup") private var hasCompletedQuickAccessSetup = false
    
    @State private var cameraAuthorized = false
    @State private var micAndSpeechAuthorized = false
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
                    case .welcome:
                        welcomeContent
                    case .permissionsSetup:
                        permissionsSetupContent
                    case .tryAsking:
                        tryAskingContent
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
        .sheet(isPresented: $showQuickAccessSheet) {
            QuickAccessSetupSheet(isIndonesian: speechService.isIndonesian)
        }
        .onAppear {
            updatePermissionStatuses()
            announceWelcome()
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
            
            // Progress Indicator (Step X of 4)
            progressDots
            
            Spacer()
            
            // Contextual Secondary Action (Skip Practice on Screen 3)
            if currentStep == .tryAsking {
                Button {
                    skipPractice()
                } label: {
                    Text(speechService.isIndonesian ? "Lewati" : "Skip")
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
                .accessibilityLabel(speechService.isIndonesian ? "Lewati latihan suara" : "Skip voice practice")
                .accessibilityHint(speechService.isIndonesian ? "Langsung lanjut ke langkah terakhir." : "Advances directly to the final step.")
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
        .accessibilityLabel(speechService.isIndonesian
            ? "Langkah \(currentStep.rawValue + 1) dari \(OnboardingStep.allCases.count)"
            : "Step \(currentStep.rawValue + 1) of \(OnboardingStep.allCases.count)")
        .animation(.easeInOut(duration: 0.25), value: currentStep)
    }
    
    // MARK: - Screen 1: Welcome Content (with Integrated Language Selection)
    
    private var welcomeContent: some View {
        VStack(spacing: 16) {
            // App Branding Icon
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "eye.circle.fill")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.blue)
            }
            .accessibilityHidden(true)
            
            // 1. App Title
            Text("TestApp")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            
            // 2. Welcome / Value Statement
            Text(speechService.isIndonesian
                 ? "Asisten visual cerdas yang mendeskripsikan lingkungan sekitar Anda menggunakan kamera dan suara."
                 : "An intelligent visual assistant that describes what is around you using your camera and voice.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
            
            // 3. Language Spatial Guidance Instruction
            Text(speechService.isIndonesian
                 ? "Pilih bahasa Anda di atas, lalu pilih Lanjut di bagian bawah layar."
                 : "Choose your language above, then select Continue at the bottom of the screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .fixedSize(horizontal: false, vertical: true)
            
            // 4. Coherent Accessible Language Selector
            languageSelectorControl
                .padding(.top, 4)
                .padding(.horizontal, 4)
        }
        .padding(.horizontal, 24)
    }
    
    // MARK: - Language Selector (Accessible Adjustable Control)
    
    private var languageSelectorControl: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(speechService.isIndonesian ? "Pilih bahasa" : "Choose your language")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)
                .accessibilityHidden(true)
            
            VStack(spacing: 8) {
                languageVisualOption(
                    title: "English",
                    localeIdentifier: "en-US",
                    isSelected: !speechService.isIndonesian
                )
                
                languageVisualOption(
                    title: "Bahasa Indonesia",
                    localeIdentifier: "id-ID",
                    isSelected: speechService.isIndonesian
                )
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(speechService.isIndonesian ? "Bahasa" : "Language")
        .accessibilityValue(speechService.isIndonesian ? "Bahasa Indonesia dipilih" : "English selected")
        .accessibilityHint(speechService.isIndonesian
            ? "Gesek ke atas atau ke bawah untuk mengubah bahasa."
            : "Swipe up or down to change language.")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment, .decrement:
                cycleLanguage()
            @unknown default:
                break
            }
        }
        .accessibilityAction(.default) {
            cycleLanguage()
        }
    }
    
    private func languageVisualOption(title: String, localeIdentifier: String, isSelected: Bool) -> some View {
        Button {
            selectLanguage(identifier: localeIdentifier)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.blue : Color(.tertiaryLabel))
                
                Text(title)
                    .font(.body)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                if isSelected {
                    Text(speechService.isIndonesian ? "Dipilih" : "Selected")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.12))
                        )
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.blue.opacity(0.08) : Color(.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? Color.blue : Color(.separator).opacity(0.3), lineWidth: isSelected ? 1.5 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    private func cycleLanguage() {
        if speechService.isIndonesian {
            selectLanguage(identifier: "en-US")
        } else {
            selectLanguage(identifier: "id-ID")
        }
    }
    
    private func selectLanguage(identifier: String) {
        let isSame = (speechService.selectedLocale.identifier == identifier)
        if !isSame {
            let haptic = UIImpactFeedbackGenerator(style: .light)
            haptic.impactOccurred()
            
            withAnimation(.easeInOut(duration: 0.2)) {
                speechService.selectedLocale = Locale(identifier: identifier)
            }
        }
        
        let confirmMsg = speechService.isIndonesian
            ? "Bahasa Indonesia dipilih."
            : "English selected."
        AccessibilityVoiceService.shared.speak(confirmMsg, languageCode: speechService.selectedLocale.identifier)
    }
    
    private func announceWelcome() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            guard currentStep == .welcome else { return }
            let welcomeMsg = speechService.isIndonesian
                ? "Selamat datang di TestApp, asisten visual Anda. Pilih bahasa Anda di atas, lalu pilih Lanjut di bagian bawah layar."
                : "Welcome to TestApp, your visual assistant. Choose your language above, then select Continue at the bottom of the screen."
            AccessibilityVoiceService.shared.speak(welcomeMsg, languageCode: speechService.selectedLocale.identifier)
        }
    }
    
    // MARK: - Screen 2: Central Permissions & Setup Content (Static / Unscrollable)
    
    private var permissionsSetupContent: some View {
        VStack(spacing: 12) {
            
            // Screen Header
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: "checklist")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(.blue)
                }
                .accessibilityHidden(true)
                
                Text(speechService.isIndonesian ? "Atur TestApp" : "Set Up TestApp")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(speechService.isIndonesian
                     ? "Aktifkan izin wajib dan atur akses cepat opsional."
                     : "Enable required permissions and configure optional quick access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
            
            // Section 1: Required Permissions
            VStack(alignment: .leading, spacing: 8) {
                Text(speechService.isIndonesian ? "Izin Wajib" : "Required Permissions")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                
                permissionCard(
                    icon: "camera.fill",
                    title: speechService.isIndonesian ? "Akses Kamera" : "Camera Access",
                    description: speechService.isIndonesian
                        ? "Untuk melihat dan mendeskripsikan objek di sekitar Anda."
                        : "To see and describe objects in your surroundings.",
                    isGranted: cameraAuthorized
                )
                
                permissionCard(
                    icon: "mic.fill",
                    title: speechService.isIndonesian ? "Mikrofon & Suara" : "Microphone & Speech",
                    description: speechService.isIndonesian
                        ? "Untuk mendengar dan mengenali pertanyaan Anda."
                        : "To hear and transcribe your spoken questions.",
                    isGranted: micAndSpeechAuthorized
                )
            }
            
            // Section 2: Optional Quick Access Setup
            VStack(alignment: .leading, spacing: 8) {
                Text(speechService.isIndonesian ? "Akses Cepat (Opsional)" : "Quick Access (Optional)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .padding(.horizontal, 4)
                
                QuickAccessOnboardingCardView(
                    isIndonesian: speechService.isIndonesian,
                    hasCompletedSetup: hasCompletedQuickAccessSetup,
                    onSetupTapped: {
                        showQuickAccessSheet = true
                    },
                    onResetTapped: {
                        hasCompletedQuickAccessSetup = false
                    }
                )
            }
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
    }
    
    private func permissionCard(icon: String, title: String, description: String, isGranted: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .fill(isGranted ? Color.green.opacity(0.15) : Color.blue.opacity(0.12))
                    .frame(width: 38, height: 38)
                
                Image(systemName: isGranted ? "checkmark" : icon)
                    .font(.subheadline.bold())
                    .foregroundStyle(isGranted ? Color.green : Color.blue)
            }
            .accessibilityHidden(true)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Text(isGranted
                         ? (speechService.isIndonesian ? "Diizinkan" : "Granted")
                         : (speechService.isIndonesian ? "Wajib" : "Required"))
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(isGranted ? Color.green : Color.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(isGranted ? Color.green.opacity(0.12) : Color(.systemGray5))
                        )
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(isGranted ? (speechService.isIndonesian ? "Sudah diizinkan" : "Granted") : (speechService.isIndonesian ? "Izin diperlukan" : "Required permission")). \(description)")
    }
    
    // MARK: - Screen 3: Interactive Voice Tutorial Content (Try Asking)
    
    private var tryAskingContent: some View {
        VStack(spacing: 18) {
            // Heading & instructions
            VStack(spacing: 8) {
                Text(speechService.isIndonesian ? "Coba ajukan pertanyaan" : "Try asking a question")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(speechService.isIndonesian
                     ? "Sentuh dan tahan mikrofon di bagian bawah layar sambil berbicara, lalu lepaskan jika selesai."
                     : "Touch and hold the microphone at the bottom of the screen while speaking, then release when finished.")
                    .font(.subheadline)
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
                
                Text(speechService.isIndonesian ? "Coba katakan:" : "Try saying:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
            Text(speechService.isIndonesian ? "\"Apa ini?\"" : "\"What is this?\"")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.blue)
            
            Text(speechService.isIndonesian ? "atau tanyakan tentang apa pun di dekat Anda" : "or ask about anything nearby")
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
        .accessibilityLabel(speechService.isIndonesian
            ? "Contoh pertanyaan yang dapat Anda coba: Apa ini?, atau tanyakan tentang apa pun di dekat Anda. Tahan mikrofon di bagian bawah layar untuk mencoba."
            : "Suggested question: What is this?, or ask about anything nearby. Hold the microphone at the bottom of the screen to try.")
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
                Text(speechService.isIndonesian ? "Anda bertanya:" : "You asked:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text("\"\(transcript)\"")
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            
            Text(speechService.isIndonesian
                 ? "Begitulah cara Anda bertanya di TestApp. Di kamera langsung, Anda akan langsung mendengar jawaban suara."
                 : "That is how you ask TestApp questions. In the live camera, you'll receive a spoken answer instantly.")
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
        .accessibilityLabel(speechService.isIndonesian
            ? "Latihan berhasil. Anda bertanya: \(transcript). Ketuk Lanjutkan di bagian bawah layar untuk menyelesaikan."
            : "Practice successful. You asked: \(transcript). Tap Continue at the bottom of the screen to finish setup.")
    }
    
    private var emptyFeedbackCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash")
                .font(.title2)
                .foregroundStyle(.orange)
            
            Text(speechService.isIndonesian ? "Pertanyaan tidak terdengar." : "I didn't hear a question.")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(speechService.isIndonesian
                 ? "Tahan mikrofon di bagian bawah dan bicaralah dengan jelas, atau ketuk Lewati di atas."
                 : "Hold the microphone at the bottom and speak clearly, or tap Skip at the top.")
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
        .accessibilityLabel(speechService.isIndonesian
            ? "Pertanyaan tidak terdengar. Tahan mikrofon di bagian bawah layar untuk mencoba lagi, atau ketuk Lewati di kanan atas."
            : "I didn't hear a question. Hold the microphone at the bottom of the screen to try again, or tap Skip in the top right.")
    }
    
    private var unavailableFeedbackCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.slash.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text(speechService.isIndonesian ? "Izin mikrofon diperlukan" : "Microphone access is needed")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(speechService.isIndonesian
                 ? "Anda dapat mengaktifkan izin mikrofon di Pengaturan iOS untuk bertanya."
                 : "You can enable microphone permission in iOS Settings to ask questions.")
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
        .accessibilityLabel(speechService.isIndonesian
            ? "Izin mikrofon diperlukan. Anda dapat mengaktifkannya di Pengaturan iOS."
            : "Microphone access is needed. You can enable microphone permission in iOS Settings.")
    }
    
    // MARK: - Screen 4: Ready Content (Get Started - Static / Unscrollable)
    
    private var readyContent: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 64, height: 64)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 38, weight: .regular))
                    .foregroundStyle(.green)
            }
            .accessibilityHidden(true)
            
            VStack(spacing: 6) {
                Text(speechService.isIndonesian ? "Anda sudah siap" : "You're ready")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .accessibilityAddTraits(.isHeader)
                
                Text(speechService.isIndonesian
                     ? "Arahkan kamera ke objek di sekitar Anda dan tahan area bawah untuk bertanya."
                     : "Point your camera at anything and hold the bottom area to ask questions.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            
            // Example question cards
            VStack(spacing: 8) {
                exampleCard(icon: "questionmark.circle.fill", text: speechService.isIndonesian ? "\"Apa ini?\"" : "\"What is this?\"")
                exampleCard(icon: "info.circle.fill", text: speechService.isIndonesian ? "\"Untuk apa benda ini?\"" : "\"What is it used for?\"")
                exampleCard(icon: "doc.text.viewfinder", text: speechService.isIndonesian ? "\"Apa tulisan di label ini?\"" : "\"What does this label say?\"")
            }
            .padding(.horizontal, 4)
        }
        .padding(.horizontal, 20)
        .accessibilityElement(children: .contain)
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
        case .welcome:
            // Screen 1: Continue Button to Setup Page
            Button {
                advanceStep()
            } label: {
                Text(speechService.isIndonesian ? "Lanjut" : "Continue")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(speechService.isIndonesian ? "Lanjut" : "Continue")
            .accessibilityHint(speechService.isIndonesian
                ? "Di bagian bawah layar. Membuka halaman pengaturan izin dan akses cepat."
                : "At the bottom of the screen. Opens the permissions and quick access setup page.")
            
        case .permissionsSetup:
            // Screen 2: Continue to Try Asking
            Button {
                advanceStep()
            } label: {
                Text(speechService.isIndonesian ? "Lanjutkan" : "Continue")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(speechService.isIndonesian ? "Lanjutkan" : "Continue")
            .accessibilityHint(speechService.isIndonesian
                ? "Menyimpan pengaturan dan lanjut ke latihan bertanya."
                : "Proceeds to voice question practice.")
            
        case .tryAsking:
            // Screen 3: Contextual Bottom Interaction (Voice Area or Continue button)
            if case .success = tutorialState {
                // When practice completed: Continue button
                Button {
                    advanceStep()
                } label: {
                    Text(speechService.isIndonesian ? "Lanjutkan" : "Continue")
                        .font(.title3)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityLabel(speechService.isIndonesian ? "Lanjutkan" : "Continue")
                .accessibilityHint(speechService.isIndonesian ? "Lanjut ke langkah terakhir." : "Advances to the final step.")
            } else {
                // Primary interaction: Voice Area (Exact match with CameraView's bottom voice area)
                onboardingVoiceArea
            }
            
        case .ready:
            // Screen 4: Get Started Button
            Button {
                advanceStep()
            } label: {
                Text(speechService.isIndonesian ? "Mulai" : "Get Started")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityLabel(speechService.isIndonesian ? "Mulai" : "Get Started")
            .accessibilityHint(speechService.isIndonesian
                ? "Menyelesaikan orientasi dan membuka kamera langsung."
                : "Completes onboarding and opens the live camera viewfinder.")
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
                    Text(speechService.isIndonesian ? "\"Apa ini?\"" : "\"What is this?\"")
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
            return speechService.isIndonesian ? "Tahan dan ajukan pertanyaan" : "Hold and ask a question"
        case .listening:
            return speechService.isIndonesian ? "Mendengarkan…" : "Listening…"
        case .processing:
            return speechService.isIndonesian ? "Memproses…" : "Thinking…"
        case .success:
            return speechService.isIndonesian ? "Selesai" : "Done"
        case .unavailable:
            return speechService.isIndonesian ? "Mikrofon tidak tersedia" : "Microphone unavailable"
        }
    }
    
    private var voiceAreaAccessibilityLabel: String {
        switch tutorialState {
        case .listening:
            return speechService.isIndonesian ? "Merekam pertanyaan" : "Recording question"
        case .processing:
            return speechService.isIndonesian ? "Menganalisis pertanyaan" : "Processing question"
        case .success(let t):
            return speechService.isIndonesian ? "Latihan selesai. Anda berkata: \(t)." : "Practice complete. You said: \(t)."
        case .empty:
            return speechService.isIndonesian ? "Coba bertanya lagi" : "Try asking again"
        case .unavailable:
            return speechService.isIndonesian ? "Latihan suara tidak tersedia" : "Voice practice unavailable"
        case .idle:
            return speechService.isIndonesian ? "Latihan mengajukan pertanyaan" : "Practice asking a question"
        }
    }
    
    private var voiceAreaAccessibilityHint: String {
        switch tutorialState {
        case .listening:
            return speechService.isIndonesian ? "Ketuk dua kali untuk berhenti merekam, atau lepaskan sentuhan." : "Double-tap to stop recording, or release hold."
        case .processing:
            return speechService.isIndonesian ? "Harap tunggu sementara pertanyaan Anda dianalisis." : "Please wait while your question is analyzed."
        case .success:
            return speechService.isIndonesian ? "Ketuk dua kali untuk berlatih lagi, atau ketuk Lanjutkan di bawah." : "Double-tap to practice asking again, or tap Continue below."
        case .idle, .empty:
            return speechService.isIndonesian ? "Ketuk dua kali untuk mulai berbicara, atau tekan dan tahan bagian bawah layar." : "Double-tap to start speaking, or press and hold the bottom of the screen while speaking."
        case .unavailable:
            return speechService.isIndonesian ? "Ketuk Lewati di kanan atas untuk melanjutkan." : "Tap Skip in the top right to continue."
        }
    }
    
    // MARK: - Permissions Helper
    
    private func updatePermissionStatuses() {
        let camStatus = AVCaptureDevice.authorizationStatus(for: .video)
        cameraAuthorized = (camStatus == .authorized)
        
        let micStatus: Bool
        if #available(iOS 17.0, *) {
            micStatus = (AVAudioApplication.shared.recordPermission == .granted)
        } else {
            micStatus = (AVAudioSession.sharedInstance().recordPermission == .granted)
        }
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        micAndSpeechAuthorized = micStatus && (speechStatus == .authorized)
    }
    
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
            self.cameraAuthorized = cameraGranted
            self.micAndSpeechAuthorized = speechGranted
        }
        
        return cameraGranted && speechGranted
    }
    
    // MARK: - Tutorial Speech Actions
    
    private func beginTutorialSpeech() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.15)) {
            tutorialState = .listening
        }
        
        AccessibilityVoiceService.shared.speak(
            speechService.isIndonesian ? "Mendengarkan." : "Listening.",
            languageCode: speechService.selectedLocale.identifier
        )
        
        Task {
            if !permissionsChecked {
                _ = await requestAllPermissions()
            }
            
            guard micAndSpeechAuthorized else {
                await MainActor.run {
                    isHolding = false
                    withAnimation(.easeInOut(duration: 0.2)) {
                        tutorialState = .unavailable
                    }
                    AccessibilityVoiceService.shared.speak(
                        speechService.isIndonesian
                            ? "Izin mikrofon tidak diberikan. Ketuk Lewati di kanan atas untuk lanjut."
                            : "Microphone permission was not granted. Tap Skip at the top right to continue.",
                        languageCode: speechService.selectedLocale.identifier
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
                        speechService.isIndonesian
                            ? "Pertanyaan tidak terdengar. Tahan mikrofon di bagian bawah untuk mencoba lagi, atau ketuk Lewati di kanan atas."
                            : "I didn't hear a question. Hold the microphone at the bottom to try again, or tap Skip at the top right.",
                        languageCode: speechService.selectedLocale.identifier
                    )
                }
                return
            }
            
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.25)) {
                    tutorialState = .success(transcript)
                }
                AccessibilityVoiceService.shared.speak(
                    speechService.isIndonesian
                        ? "Bagus sekali! Anda bertanya: \(transcript). Ketuk Lanjutkan di bagian bawah layar untuk menyelesaikan."
                        : "Great job! You asked: \(transcript). Tap Continue at the bottom of the screen to finish setup.",
                    languageCode: speechService.selectedLocale.identifier
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
            speechService.isIndonesian
                ? "Langkah 4 dari 4: Anda siap! Arahkan kamera ke objek, tahan bagian bawah layar untuk bertanya, dan lepaskan untuk mendengar jawaban. Ketuk Mulai di bawah untuk membuka kamera."
                : "Step 4 of 4: You are ready! Point your camera at anything, touch and hold the bottom of the screen to ask what you would like to know, and release to hear an answer. Tap Get Started at the bottom of the screen to open the camera.",
            languageCode: speechService.selectedLocale.identifier
        )
    }
    
    private func advanceStep() {
        switch currentStep {
        case .welcome:
            // Advance from Welcome -> Permissions / Setup
            withAnimation(.easeInOut(duration: 0.35)) {
                currentStep = .permissionsSetup
            }
            updatePermissionStatuses()
            AccessibilityVoiceService.shared.speak(
                speechService.isIndonesian
                    ? "Langkah 2 dari 4: Atur TestApp. Aktifkan izin kamera dan mikrofon, serta atur Akses Cepat untuk Tombol Tindakan. Ketuk Lanjut jika sudah siap."
                    : "Step 2 of 4: Set Up TestApp. Enable camera and microphone permissions, and optionally set up Quick Access for your Action Button. Tap Continue when ready.",
                languageCode: speechService.selectedLocale.identifier
            )
            
        case .permissionsSetup:
            // Advance from Permissions / Setup -> Try Asking
            Task {
                if !cameraAuthorized || !micAndSpeechAuthorized {
                    _ = await requestAllPermissions()
                }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        currentStep = .tryAsking
                    }
                    AccessibilityVoiceService.shared.speak(
                        speechService.isIndonesian
                            ? "Langkah 3 dari 4: Coba ajukan pertanyaan. Sentuh dan tahan mikrofon di bagian bawah layar sambil berbicara, lalu lepaskan. Contohnya, tanyakan: Apa ini? Atau ketuk Lewati di kanan atas untuk lanjut."
                            : "Step 3 of 4: Try asking a question. Touch and hold the microphone at the bottom of the screen while speaking, then release when finished. For example, ask: What is this? Or tap Skip in the top right to continue.",
                        languageCode: speechService.selectedLocale.identifier
                    )
                }
            }
            
        case .tryAsking:
            // Advance from Try Asking -> Ready
            speechService.cancelRecording()
            withAnimation(.easeInOut(duration: 0.35)) {
                currentStep = .ready
            }
            AccessibilityVoiceService.shared.speak(
                speechService.isIndonesian
                    ? "Langkah 4 dari 4: Anda siap! Arahkan kamera ke objek, tahan bagian bawah layar untuk bertanya, dan lepaskan untuk mendengar jawaban. Ketuk Mulai di bawah untuk membuka kamera."
                    : "Step 4 of 4: You are ready! Point your camera at anything, touch and hold the bottom of the screen to ask what you would like to know, and release to hear an answer. Tap Get Started at the bottom of the screen to open the camera.",
                languageCode: speechService.selectedLocale.identifier
            )
            
        case .ready:
            // Complete onboarding
            withAnimation(.easeInOut(duration: 0.35)) {
                hasCompletedOnboarding = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    WelcomeView(hasCompletedOnboarding: .constant(false))
}
