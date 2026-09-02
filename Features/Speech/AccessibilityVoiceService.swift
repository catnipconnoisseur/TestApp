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
    
    /// Speaks or announces the given text based on current accessibility state.
    /// Ensures audio is always delivered clearly and without duplicate audio streams.
    func speak(_ text: String, queueAnnouncement: Bool = false) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // 1. Post to native VoiceOver screen reader if VoiceOver is currently running
        if UIAccessibility.isVoiceOverRunning {
            let attributed = NSAttributedString(
                string: trimmed,
                attributes: [.accessibilitySpeechQueueAnnouncement: queueAnnouncement]
            )
            UIAccessibility.post(notification: .announcement, argument: attributed)
            return
        }
        
        // 2. If VoiceOver is not active, speak out loud through the device speaker
        speakAloud(trimmed)
    }
    
    /// Speaks out loud using AVSpeechSynthesizer through the device speaker.
    private func speakAloud(_ text: String) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            print("[VOICE] Audio session setup error: \(error.localizedDescription)")
        }
        
        synthesizer.stopSpeaking(at: .immediate)
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        synthesizer.speak(utterance)
        print("[VOICE] Spoke aloud: '\(text)'")
    }
    
    /// Stops any active speech synthesis immediately.
    func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
