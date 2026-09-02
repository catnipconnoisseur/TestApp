import AVFoundation
import Foundation
import UIKit

// MARK: - Accessibility Voice & Spoken Audio Service

/// Coordinates spoken audio feedback for the visual assistant.
/// - When VoiceOver is enabled: Posts native `UIAccessibility.announcement` notifications.
/// - When VoiceOver is not enabled: Speaks answers aloud via `AVSpeechSynthesizer` so blind/low-vision users
///   and testers always hear spoken audio feedback.
@MainActor
final class AccessibilityVoiceService: NSObject, AVSpeechSynthesizerDelegate {
    
    static let shared = AccessibilityVoiceService()
    
    private let synthesizer = AVSpeechSynthesizer()
    
    override private init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Core Speech & Announcement Delivery
    
    /// Returns the currently active language code from UserDefaults, falling back to en-US.
    var activeLanguageCode: String {
        UserDefaults.standard.string(forKey: "selectedLanguageCode") ?? "en-US"
    }
    
    /// Speaks or announces the given text based on current accessibility state and selected language.
    /// Ensures audio is always delivered clearly and without duplicate audio streams.
    func speak(_ text: String, languageCode: String? = nil, queueAnnouncement: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let targetLanguage = languageCode ?? activeLanguageCode
        
        // 1. Post to native VoiceOver screen reader if VoiceOver is currently running
        if UIAccessibility.isVoiceOverRunning {
            var attributes: [NSAttributedString.Key: Any] = [
                .accessibilitySpeechLanguage: targetLanguage
            ]
            if queueAnnouncement {
                attributes[.accessibilitySpeechQueueAnnouncement] = true
            }
            let attributed = NSAttributedString(string: trimmed, attributes: attributes)
            UIAccessibility.post(notification: .announcement, argument: attributed)
            return
        }
        
        // 2. If VoiceOver is not active, speak out loud through the device speaker
        speakAloud(trimmed, languageCode: targetLanguage)
    }
    
    /// Replays an interpretation headline and description aloud.
    func repeatAnswer(headline: String, description: String?, languageCode: String? = nil) {
        let fullText: String
        if let description = description, !description.isEmpty {
            fullText = "\(headline). \(description)"
        } else {
            fullText = headline
        }
        speak(fullText, languageCode: languageCode)
    }
    
    /// Speaks out loud using AVSpeechSynthesizer through the device speaker in the specified language.
    private func speakAloud(_ text: String, languageCode: String) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("[VOICE] Audio session setup error: \(error.localizedDescription)")
        }
        
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode) ?? AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        print("[VOICE] Spoke aloud (\(languageCode)): '\(text)'")
    }
    
    /// Stops any active speech synthesis immediately.
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
