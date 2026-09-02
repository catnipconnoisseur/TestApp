import AVFoundation
import Foundation
import Speech

// MARK: - Speech Service Status

enum SpeechServiceStatus: Equatable, Sendable {
    case idle
    case listening
    case finalizing
    case unauthorized(String)
    case unavailable(String)
    case failed(String)
    
    var isListening: Bool {
        self == .listening
    }
}

// MARK: - Dedicated On-Device Speech Recognition Service

@Observable
@MainActor
final class SpeechService {
    
    // Public Observable State
    var status: SpeechServiceStatus = .idle
    var partialTranscript: String = ""
    var finalTranscript: String = ""
    var selectedLocale: Locale = {
        let savedIdentifier = UserDefaults.standard.string(forKey: "selectedLanguageCode") ?? "en-US"
        return Locale(identifier: savedIdentifier)
    }() {
        didSet {
            UserDefaults.standard.set(selectedLocale.identifier, forKey: "selectedLanguageCode")
            setupRecognizer()
        }
    }
    
    var isIndonesian: Bool {
        selectedLocale.identifier.hasPrefix("id")
    }
    
    // Internal Audio & Speech Components
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // Telemetry & Timing
    private(set) var lastRecordingDuration: TimeInterval = 0
    private var recordingStartTime: Date?
    
    init() {
        setupRecognizer()
    }
    
    // MARK: - Recognizer Setup
    
    private func setupRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: selectedLocale)
        if speechRecognizer == nil {
            // Fallback to English if chosen locale is unsupported
            speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        }
    }
    
    // MARK: - Authorization Request
    
    func requestPermissions() async -> Bool {
        // 1. Microphone Permission
        let micGranted: Bool
        if #available(iOS 17.0, *) {
            micGranted = await AVAudioApplication.requestRecordPermission()
        } else {
            micGranted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        
        guard micGranted else {
            status = .unauthorized("Microphone permission was denied. Enable microphone access in iOS Settings.")
            return false
        }
        
        // 2. Speech Recognition Permission
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { authStatus in
                continuation.resume(returning: authStatus)
            }
        }
        
        switch speechStatus {
        case .authorized:
            status = .idle
            return true
        case .denied:
            status = .unauthorized("Speech recognition permission was denied. Enable speech recognition in iOS Settings.")
            return false
        case .restricted:
            status = .unauthorized("Speech recognition is restricted on this device.")
            return false
        case .notDetermined:
            status = .unauthorized("Speech recognition permission is not determined.")
            return false
        @unknown default:
            status = .unauthorized("Unknown speech recognition authorization state.")
            return false
        }
    }
    
    // MARK: - Start Speech Recognition (Hold-to-Talk)
    
    func startRecording() {
        // Cancel any existing active task
        cancelRecording()
        
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            status = .unavailable("Speech recognizer is currently unavailable for \(selectedLocale.identifier).")
            return
        }
        
        // Configure Audio Session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            status = .failed("Failed to configure audio session: \(error.localizedDescription)")
            return
        }
        
        // Reset transcripts
        partialTranscript = ""
        finalTranscript = ""
        recordingStartTime = Date()
        
        // Create Request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        
        // Prefer On-Device Processing where available
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        
        self.recognitionRequest = request
        
        // Install Audio Tap
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Remove existing tap if present
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            status = .listening
            print("[SPEECH] Audio engine started. Listening for speech in \(selectedLocale.identifier)...")
        } catch {
            cleanupAudioEngine()
            status = .failed("Audio engine could not start: \(error.localizedDescription)")
            return
        }
        
        // Start Recognition Task
        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let result = result {
                    let transcribedString = result.bestTranscription.formattedString
                    self.partialTranscript = transcribedString
                    
                    if result.isFinal {
                        self.finalTranscript = transcribedString
                        print("[SPEECH] Final transcript: '\(transcribedString)'")
                    }
                }
                
                if let error = error {
                    let nsError = error as NSError
                    if nsError.domain == "kLSRErrorDomain" && (nsError.code == 201 || nsError.code == 301) {
                        return
                    }
                    if nsError.domain == "kAFAssistantErrorDomain" && nsError.code == 216 {
                        return // Request cancelled
                    }
                    
                    print("[SPEECH] Recognition task error: \(error.localizedDescription)")
                    if self.finalTranscript.isEmpty && self.partialTranscript.isEmpty {
                        self.status = .failed(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    // MARK: - Stop Speech Recognition & Await Final Transcript (T007.2)
    
    func stopRecordingAndGetTranscript() async -> String? {
        guard status == .listening else { return nil }
        
        if let start = recordingStartTime {
            lastRecordingDuration = Date().timeIntervalSince(start)
        }
        
        status = .finalizing
        print("[SPEECH] Stopping recording (duration: \(String(format: "%.2f", lastRecordingDuration))s)...")
        
        // End audio capture
        recognitionRequest?.endAudio()
        cleanupAudioEngine()
        
        // Await final recognition hypothesis (< 250ms)
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let candidate = finalTranscript.isEmpty ? partialTranscript : finalTranscript
        let cleaned = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleaned.isEmpty {
            self.finalTranscript = cleaned
            self.status = .idle
            print("[SPEECH] Captured valid question: '\(cleaned)'")
            return cleaned
        } else {
            print("[SPEECH] No speech recognized.")
            self.finalTranscript = "I didn't hear a question."
            self.status = .idle
            return nil
        }
    }
    
    func stopRecording() {
        Task {
            _ = await stopRecordingAndGetTranscript()
        }
    }
    
    // MARK: - Cancel Recording
    
    func cancelRecording() {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        cleanupAudioEngine()
        status = .idle
    }
    
    private func cleanupAudioEngine() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
