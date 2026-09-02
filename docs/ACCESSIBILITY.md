# TestApp — Accessibility Conventions

> Last updated: 2026-09-02

---

## Core Principle

> **The user is in control.** The app does not narrate constantly. The user points, asks, and receives a concise answer. This is the "POINT → ASK → UNDERSTAND" model.

---

## VoiceOver

### Reading Order (CameraView)
The VoiceOver focus order on the camera screen is strictly:
1. **Settings gear** (top-left) — "Settings. Button."
2. **Camera viewfinder** — hidden from VoiceOver (`.accessibilityHidden(true)`) to prevent background layer occlusion
3. **Interpretation card** — "Interpretation: [Headline]. [Description]. [Confidence]."
4. **Voice interaction area** — "Hold to ask a question about what the camera sees."

This follows the natural top-to-bottom flow and places the action at the end, which is correct for VoiceOver users who swipe sequentially.

### VoiceOver Labels & Hints
Every interactive element must have:
```swift
.accessibilityLabel("What it is")
.accessibilityHint("What happens when you activate it")
```

Example:
```swift
Button("Settings") { ... }
    .accessibilityLabel("Settings")
    .accessibilityHint("Opens app settings for language, API key, and developer options.")
```

### Grouped Elements
Use `.accessibilityElement(children: .combine)` to group related child elements into a single VoiceOver item:
```swift
HStack {
    Text("Status")
    Text("Configured")
}
.accessibilityElement(children: .combine)
.accessibilityLabel("API Key status: Configured")
```

### Accessibility Actions
- **Double-tap**: Standard activation (e.g., start/stop recording in voice area)
- **Actions Rotor**: Used for "Repeat answer" capability

### Language Attributes
When VoiceOver reads content in a specific language, use `accessibilitySpeechLanguage`:
```swift
let attributed = NSAttributedString(
    string: text,
    attributes: [.accessibilitySpeechLanguage: "id-ID"]
)
UIAccessibility.post(notification: .announcement, argument: attributed)
```

---

## Announcements

### When to Announce
- **Camera ready (standard launch)**: "Camera ready. Touch and hold the bottom of the screen to ask a question." / "Kamera siap. Tahan bagian bawah layar untuk bertanya."
- **Quick Access ready (Action Button / Shortcut)**: "TestApp ready. Touch and hold the bottom of the screen to ask a question." / "TestApp siap. Tahan bagian bawah layar untuk bertanya."
- **Listening started**: "Listening..." (with haptic feedback)
- **Thinking**: "Analyzing your question..." (with gentle haptic pulses)
- **Answer received**: Full headline + description announced
- **Error**: Descriptive error message announced

### How to Announce
Always use `AccessibilityVoiceService.shared.speak()`:
```swift
AccessibilityVoiceService.shared.speak(
    "Rp50,000 Banknote",
    languageCode: speechService.selectedLocale.identifier
)
```

This automatically routes to:
- **VoiceOver active** → `UIAccessibility.post(notification: .announcement)` with language attributes
- **VoiceOver inactive** → `AVSpeechSynthesizer` with language-matched voice

### Do NOT
- Call `UIAccessibility.post(notification: .announcement)` directly. Always go through `AccessibilityVoiceService`.
- Announce system-internal states ("Rate limited", "Parsing error"). Translate to user-facing language.

---

## Audio Management

### Audio Sessions
- **Recording** (SpeechService): `.playAndRecord` mode with `.measurement` and `.defaultToSpeaker`
- **Playback** (AccessibilityVoiceService): `.playback` mode with `.spokenAudio` and `.duckOthers`
- Sessions must be deactivated with `.notifyOthersOnDeactivation` to restore other audio.

### Speech Synthesis
- `AVSpeechSynthesisVoice(language:)` is used with the active locale code
- Fallback to `en-US` if the requested locale voice is unavailable
- Always `stopSpeaking(at: .immediate)` before starting new speech to avoid overlapping audio

---

## Haptic Feedback

- **Interaction start** (hold begins): `UIImpactFeedbackGenerator(style: .medium).impactOccurred()`
- **Interaction end** (release): `UIImpactFeedbackGenerator(style: .light).impactOccurred()`
- **Thinking state**: Gentle periodic haptic pulses to indicate ongoing processing
- **Answer received**: No haptic (the spoken announcement is the feedback)

---

## Touch Targets

- **Voice interaction area**: ~120pt tall, full screen width. Far exceeds Apple's 44pt minimum.
- **Settings gear**: Standard 44pt minimum touch target.
- The voice area responds to `DragGesture(minimumDistance: 0)` for hold detection.

---

## Onboarding Accessibility (WelcomeView)

The 4-step onboarding is designed for VoiceOver:
1. **Welcome (Introduction)**: Spoken welcome, value proposition (camera & microphone assistance), and primary "Continue" button.
2. **Permissions / Setup (Central Hub)**:
   - **VoiceOver Hierarchy**:
     1. Page header & context ("Set Up TestApp", "Step 2 of 4").
     2. Required Permissions (Camera access status, Microphone & Speech recognition status).
     3. Quick Access section ("Quick Access", "Optional", Action Button description, privacy note).
     4. "Set Up Quick Access" / "Review Setup" button with accessible hints.
     5. "Continue" primary button.
   - **User Agency & Privacy**: States explicitly that Quick Access only opens the camera and the microphone is never activated automatically.
   - **Non-blocking**: Users can tap "Continue" without configuring Quick Access.
3. **Try Asking (Voice Practice)**: Live interactive practice area with `onboardingVoiceArea`, real-time speech feedback, and contextual "Skip" / "Continue" actions.
4. **Get Started (Ready)**: "You're ready" confirmation, example spoken questions, and primary "Get Started" button opening the live camera.

---

## Localized Accessibility

When the user selects Indonesian:
- All announcements are spoken in Indonesian
- Idle state text: "Arahkan kamera ke objek" / "Tahan bagian bawah layar untuk bertanya"
- Camera arrival: "Kamera siap. Tahan bagian bawah layar untuk bertanya."
- Error messages are localized
- VoiceOver synthesis voice switches to `id-ID`

---

## Confidence Communication

Confidence is communicated through **colored dots**, not technical labels:
| Dot | Meaning | VoiceOver Label |
|-----|---------|-----------------|
| 🟢 Green | High confidence | "High confidence" |
| 🟡 Yellow | Uncertain | "Uncertain" |
| 🔴 Red | Conflicting | "Conflicting" |

The words "Evidence", "Multimodal AI", "Vision", "OCR" are **never** shown to the user. These belong in developer telemetry only.
