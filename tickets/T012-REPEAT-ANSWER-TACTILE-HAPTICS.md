# T012 — Repeat Answer Accessibility Action & Tactile Thinking Haptics

**Status:** Complete  
**Date:** 2026-09-02  
**Focus:** Accessibility Magic Tap Replay, Visible Speaker Replay Button, Audio Channel Coordination, and Thinking State Tactile Heartbeat  

---

## 1. Executive Summary

While T007–T011 established reliable multimodal visual reasoning and scene-anchored conversation, field feedback revealed two essential accessibility opportunities:
1. **Answer Replay Without Re-Querying:** If a blind user misses part of an answer due to ambient noise or wants to re-hear specific numbers/details, they previously had to ask again (triggering another cloud request). T012 introduces zero-network answer replay.
2. **Tactile Assurance During Cloud Processing:** Gemini takes ~1.0–2.0s to analyze images and return answers. T012 provides a gentle, periodic tactile heartbeat pulse during `.thinking` states so non-visual users have physical confirmation that their request is actively processing.

---

## 2. Core Capabilities Implemented

### 1. Universal Accessibility Magic Tap (Two-Finger Double-Tap)
- Attached `.accessibilityAction(.magicTap)` to the main viewfinder hierarchy.
- When an AI answer is present (`currentAIAnswer != nil`), performing the standard iOS VoiceOver Magic Tap immediately replays the answer aloud without taking a new photo or sending a network request.
- If no answer is present (idle viewfinder), Magic Tap toggles the voice recording action.

### 2. Visible Replay Audio Button
- Added an accessible speaker button (`Image(systemName: "speaker.wave.2.fill")`) inside `interpretationCard`.
- Allows low-vision and sighted users to replay the latest answer with a single tap.
- Annotated with full bilingual VoiceOver accessibility labels (*"Repeat answer"* / *"Ulangi jawaban"*).

### 3. Tactile Heartbeat During Reasoning
- When `interactionState` transitions to `.thinking`, launches a recurring `Task` firing `UIImpactFeedbackGenerator(style: .light)` every 800ms.
- Automatically cancels upon answer arrival (`.answered`), error (`.error`), or cancellation (`.idle`).
- Fires `UINotificationFeedbackGenerator(.success)` on successful response and `UINotificationFeedbackGenerator(.error)` on failure.

---

## 3. Code Modifications

- **`Features/Speech/AccessibilityVoiceService.swift`:**
  - Added `repeatAnswer(headline:description:languageCode:)` to cleanly format and speak cached answers.
- **`Features/Camera/CameraView.swift`:**
  - Added `thinkingHapticTask: Task<Void, Never>?`
  - Added `.onChange(of: interactionState)` driving periodic haptics and completion notifications.
  - Added `.accessibilityAction(.magicTap)` for two-finger double-tap answer replay.
  - Added visible speaker icon button on `interpretationCard`.

---

## 4. Verification

- **Xcode Build:** `** BUILD SUCCEEDED **` (0 errors, 0 warnings).
- **Physical Device & VoiceOver Verification:**
  - Double-tapping the repeat button or performing two-finger double-tap successfully replays the answer without network traffic.
  - Tactile pulse is gentle, rhythmic, and stops immediately when the answer arrives.
