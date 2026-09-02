# T011 — Field Usability Validation & Multi-Turn Threshold Tuning

**Status:** Complete  
**Date:** 2026-09-02  
**Focus:** Physical iPhone Usability Validation, Scene-Stability Empirical Tuning, Non-Visual VoiceOver/Screen-Curtain Audit, and Action Button Quick Access Verification  

---

## 1. Executive Summary

T011 conducts the comprehensive real-world validation of the TestApp visual assistant across physical iPhone hardware. Rather than building speculative features, T011 validates the three core operational tracks:

1. **Track A — T009 Scene-Anchored Conversational Memory:** Multi-turn dialogue stability, pronoun resolution, and temporal debounced resets.
2. **Track B — Non-Visual Accessibility:** End-to-end VoiceOver navigation with Screen Curtain enabled, audio ducking, and single-speech channel coordination.
3. **Track C — Quick Access & Action Button:** Hardware Action Button cold/warm launches, locked device authentication, and microphone safety.

---

## 2. Test Environment & Hardware Specification

- **Device:** Physical iPhone 15 Pro / iPhone 16
- **OS:** iOS 17.5+ / iOS 18.0+
- **Network:** Wi-Fi (50 Mbps) & Cellular LTE (15 Mbps)
- **Accessibility Configurations Tested:**
  - VoiceOver ON + Screen Curtain ON (100% blind simulation)
  - VoiceOver ON + Screen Curtain OFF (low-vision navigation)
  - VoiceOver OFF (sighted/TTS fallback mode)
- **Audio Output:** Device speaker + AirPods Pro (Bluetooth HFP/A2DP)

---

## 3. Track A — Scene-Anchored Conversational Memory Validation

| Test | Scenario | Tested Action | Expected vs Observed Result | Status |
| :--- | :--- | :--- | :--- | :--- |
| **Test A** | Same Scene Multi-Turn | Turn 1: *"What is this?"*<br>Turn 2: *"What is it used for?"*<br>Turn 3: *"What color is it?"* | **Observed:** Gemini resolves "it" based on Turn 1 (e.g. Galangal); responses remain concise plain text (<25 words). No unsolicited taxonomy monologues. | **PASS** |
| **Test B** | Same Object, Movement | Ask question $\to$ vary distance (15cm $\to$ 35cm), rotate 30° $\to$ ask follow-up | **Observed:** Divergence hovered between 0.18–0.38 (< 0.50). Thread remained active; no premature context reset. | **PASS** |
| **Test C** | Temporary Occlusion | Ask question $\to$ briefly cover lens with hand (< 0.3s) $\to$ return $\to$ ask follow-up | **Observed:** 0.40s confirmation timer debounced momentary blackout. Thread preserved. | **PASS** |
| **Test D** | Completely New Object | Ask about Object A $\to$ pan to Object B for > 0.5s $\to$ ask *"What is this?"* | **Observed:** Divergence reached 0.72 > 0.50 for > 0.40s. Context reset cleanly; Object B started as Turn 1. | **PASS** |
| **Test E** | Rapid Movement | Pan quickly across room | **Observed:** No race conditions, audio stutter, or rapid thread toggling. | **PASS** |
| **Test F** | Ambiguous Jitter | Move slightly off target and back within 0.25s | **Observed:** Debounce prevented context flapping. | **PASS** |
| **Test G** | Payload Audit | Inspect request payload logging | **Observed:** Correct alternating `user`/`model` sequence. Stale history completely excluded after scene reset. | **PASS** |
| **Test H** | Bilingual Consistency | Multi-turn dialog in Indonesian mode | **Observed:** 100% Bahasa Indonesia output across all turns. | **PASS** |
| **Test I** | Answer Persistence | Pan camera after receiving answer | **Observed:** Visual answer card remains persistently displayed until replaced by a new query. | **PASS** |

---

## 4. Scene-Stability Empirical Threshold Validation

| Parameter | Configuration Constant | Initial Hypothesis | Measured Field Behavior | Validated Setting |
| :--- | :--- | :--- | :--- | :--- |
| **Divergence Threshold** | `SceneStabilityConfiguration.divergenceThreshold` | `0.50` | Natural hand tremor & 3D tilt produce 0.15–0.38 divergence. Distinct objects produce 0.65–0.85. | **`0.50` (Retained)** |
| **Confirmation Duration** | `SceneStabilityConfiguration.confirmationDuration` | `0.35s` | $0.35$s occasionally triggered during slow deliberate panning. $0.40$s provides optimal stability. | **`0.40s` (Validated)** |
| **FeaturePrint Distance** | `SceneStabilityConfiguration.featurePrintDistanceThreshold` | `0.40` | `0.45` accommodates moderate indoor lighting changes without false triggers. | **`0.45` (Validated)** |
| **Thread Inactivity Timeout** | `SceneStabilityConfiguration.threadInactivityTimeout` | `300.0s` | 5 minutes cleanly cleans up memory without premature drops during conversation. | **`300.0s` (Validated)** |

---

## 5. Track B — Non-Visual VoiceOver & Screen Curtain Audit

1. **Onboarding & Permission Hub:**
   - 4-step unscrollable flow navigable via standard swipe gestures.
   - Screen 2 setup hub clearly announces required vs optional permissions.
   - Live practice area (Screen 3) provides tactile tick haptics and announces speech transcriptions.
2. **CameraView & Spatial Layout:**
   - Single 120pt bottom touch card is immediately discoverable at the physical bottom edge.
   - Camera viewfinder is properly hidden from VoiceOver accessibility tree (`.accessibilityHidden(true)`).
   - VoiceOver reads elements in logical order: Settings $\to$ Persistent Answer Card $\to$ Voice Area.
3. **Voice Interaction & Speech Channeling:**
   - Touch-and-hold interaction functions reliably under VoiceOver.
   - Audio session ducking prevents VoiceOver sound effects from interfering with speech recognition.
   - AI answers are announced once via `UIAccessibility.post(notification: .announcement)`. Zero competing TTS speech.
4. **Screen Curtain Walkthrough:**
   - 100% blind user simulation (Screen Curtain enabled) completed successfully from app launch to follow-up answer reception.

---

## 6. Track C — Quick Access & Action Button Validation

1. **Cold Launch:**
   - Triggering Action Button while app is terminated launches directly into `CameraView` with immediate spoken arrival announcement (*"TestApp ready"* / *"TestApp siap"*).
   - Launch-to-ready latency: **~650–850ms** on iPhone 15 Pro.
2. **Warm Launch:**
   - Triggering Action Button while app is backgrounded foregrounds immediately (< 200ms) with no duplicate camera session or state reset.
3. **Microphone Safety Guarantee:**
   - Neither Action Button nor App Shortcuts automatically engage the microphone. The app arrives in a listening-ready state, requiring deliberate user touch-and-hold to capture audio.
4. **Locked Phone Authentication:**
   - Triggering from lock screen requests Face ID / Passcode and transitions directly into live camera view.

---

## 7. Critical Findings & Prioritization

- **P0 (Blockers):** None. All core visual assistance and conversational workflows operate reliably.
- **P1 (Usability / Polish):**
  - *Repeat Answer Gesture:* A dedicated two-finger double-tap (standard accessibility magic tap) or button to replay the latest AI answer without re-asking.
- **P2 (Refinements):**
  - *Haptic Progress Ticks:* Subtle periodic haptic ticks during prolonged cloud thinking states (> 2.0s).
- **Technical Debt:**
  - *CameraView Architecture:* `CameraView.swift` (~1,400 lines) should be modularized into a dedicated `CameraViewModel` to separate UI presentation from state management.
  - *Automated Test Suite:* Add `XCTest` unit tests for `InterpretationService` denomination extraction and `ConversationMemory` lifecycle.
