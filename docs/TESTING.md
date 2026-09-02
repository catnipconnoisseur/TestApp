# TestApp — Testing & Verification

> Last updated: 2026-09-02

---

## Build Command

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project TestApp.xcodeproj \
  -scheme TestApp \
  -destination 'generic/platform=iOS' \
  build
```

Expected: `BUILD SUCCEEDED` with 0 errors.

> **Note:** Warnings from Apple frameworks (e.g., Vision, Speech) may appear and can be ignored if they are not from project source code.

---

## Unit Tests

**Status: Not implemented.**

No XCTest infrastructure exists. All verification has been manual (build + on-device testing). If unit tests are added in the future:
- Test `InterpretationService.extractRupiahDenomination()` with all 70+ text variants
- Test `InterpretationService.computeSceneDivergence()` with known score inputs
- Test `MultimodalService.buildLanguageDirective()` for both locales
- Test `InterpretationService.parseStructuredMultimodalText()` with various HEADLINE/DESCRIPTION formats

---

## Manual Verification Checklist

### App Lifecycle
- [ ] First launch → WelcomeView appears with 3-step onboarding
- [ ] Second launch → Camera opens directly (onboarding skipped)
- [ ] Settings sheet opens and dismisses correctly

### Camera & Vision
- [ ] Camera permission dialog appears on first launch
- [ ] Live camera viewfinder renders at full screen
- [ ] On-device Vision produces classification and OCR results (check developer diagnostics)
- [ ] Camera frame capture returns JPEG data (non-nil)

### Voice Interaction
- [ ] Hold bottom area → "Listening" state with haptic feedback
- [ ] Speak a question → partial transcript appears in speech card
- [ ] Release → "Thinking" state with animated indicator
- [ ] Answer appears in interpretation card

### Multimodal AI
- [ ] Gemini API responds with HEADLINE and DESCRIPTION
- [ ] Response is plain text (no Markdown symbols)
- [ ] Rate limiting (429) shows graceful fallback message
- [ ] Missing API key shows configuration prompt

### Indonesian Language
- [ ] Switch to Indonesian in Settings
- [ ] Voice input transcribes in Indonesian
- [ ] Gemini response is in Indonesian
- [ ] Headline is Indonesian (e.g., "Uang Kertas Rp50.000")
- [ ] VoiceOver speaks in Indonesian voice

### Banknote Recognition
- [ ] Flat banknote → correct denomination identified
- [ ] Wrinkled banknote → still identified (deformation resilience)
- [ ] Denomination unclear → shows "Denomination Unclear" with cautionary note
- [ ] Multiple denomination formats recognized (100000, 100.000, seratus ribu)

### Accessibility
- [ ] VoiceOver reads elements in correct order: settings → result → voice area
- [ ] Camera viewfinder is hidden from VoiceOver
- [ ] Announcements are spoken after answer is received
- [ ] When VoiceOver is off, `AVSpeechSynthesizer` speaks the answer aloud
- [ ] Haptic feedback on interaction start/end

### Scene Divergence
- [ ] Point at Object A → ask "What is this?" → receive answer
- [ ] Keep pointing at Object A → answer persists despite minor camera movement
- [ ] Point at Object B → answer clears when divergence threshold is exceeded

### Error States
- [ ] Camera unauthorized → "Camera access required" screen
- [ ] Camera unavailable → "Camera unavailable" screen
- [ ] Microphone denied → Analyze fallback button appears
- [ ] Network error → descriptive error message in interpretation card

---

## Known Test Scenarios (Edge Cases)

### Currency-Specific
| Scenario | Expected Behavior |
|----------|-------------------|
| Rp100k flat, good light | "Rp100,000 Indonesian Banknote" with strong confidence |
| Rp50k wrinkled | "Rp50,000 Indonesian Banknote" (deformation resilience) |
| Rp20k folded in half | Should still identify from color (green) + partial text |
| Multiple bills stacked | May identify the top bill only |
| Non-Indonesian currency | Should identify as currency but not map to Rupiah |
| Rp denomination OCR partial ("5000" visible, rest occluded) | "Rp5,000" if sufficient visual cues |
| Very dark / heavily occluded | "Indonesian Banknote (Denomination Unclear)" |

### Voice Query-Specific
| Scenario | Expected Behavior |
|----------|-------------------|
| "What is this?" | Concise identification |
| "What color is it?" | Color only, no extra details |
| "How much is this?" (pointing at banknote) | Denomination answer |
| "Describe everything you see" | Full visual overview (progressive disclosure exception) |
| Very short recording (<0.5s) | "I didn't hear a question" |
| Ambient noise, no clear speech | "I didn't hear a question" or partial transcript |
| Follow-up: "Is it fresh?" (after "This is turmeric") | Uses previous context for pronoun resolution |

### Language-Specific
| Scenario | Expected Behavior |
|----------|-------------------|
| Indonesian mode + English question | Response still in Indonesian |
| Indonesian mode + Indonesian question | Response in Indonesian |
| Switch language mid-session | Next query uses new language |

### Quick-Access & Action Button Specific
| Scenario | Expected Behavior |
|----------|-------------------|
| Standard app launch (tap icon) | Opens to CameraView; speaks "Camera ready" arrival announcement |
| Cold launch via Action Button / Shortcut | Opens app directly to CameraView; speaks "TestApp ready" announcement |
| Warm launch via Action Button (app backgrounded) | Foregrounds app directly; speaks "TestApp ready" announcement |
| First launch via Action Button (prior to onboarding) | WelcomeView appears normally; permissions requested; does not break |
| Siri invocation ("Hey Siri, ask TestApp" / "Tanya TestApp") | Launches app into ready camera state |
| Action Button press while device locked | iOS requires Face ID/Passcode, then opens directly into ready camera state |
| Welcome Screen 1 (Welcome) | Shows welcome introduction; tapping Continue advances directly to Permissions / Setup |
| Welcome Screen 2 (Permissions / Setup) | Central setup hub with Required Permissions (Camera, Mic) + Optional Quick Access card |
| Tap "Set Up Quick Access" on Screen 2 | Opens `QuickAccessSetupSheet` with step-by-step guidance & deep links |
| Tap "Open iOS Settings" in setup sheet | Deep links directly to iOS Settings.app; marks setup complete on return |
| Tap "Done" or dismiss setup sheet | Returns to Permissions / Setup; card updates to "Quick Access Configured" |
| Tap "Continue" on Screen 2 | Prompts for required permissions (if ungranted) and advances directly to Screen 3 (Try Asking) |
| Screen 3 (Try Asking) | Interactive voice practice area with hold-to-speak gesture |
| Screen 4 (Get Started) | Confirmation screen with "Get Started" button entering CameraView |
| Settings sheet Quick Access button | Opens identical `QuickAccessSetupSheet` for reconfiguration |
| Indonesian locale throughout onboarding | All titles, cards, buttons, and VoiceOver speak in Bahasa Indonesia |

---

## Performance Benchmarks (Observed)

| Metric | Typical Range |
|--------|---------------|
| Vision frame processing | 15–40ms |
| Camera frame capture (JPEG) | 5–15ms |
| Gemini API round trip | 1,000–4,000ms |
| Speech recording to transcript | 200–500ms finalization |
| Total perceived turnaround (hold → answer) | 2,000–5,000ms |

---

## T009 — Scene-Anchored Conversational Memory Test Matrix

| Test | Scenario | Action | Expected Result | Status |
|------|----------|--------|-----------------|--------|
| **Test A** | Same Scene Multi-Turn | Turn 1: *"What is this?"* → Turn 2: *"What is it used for?"* → Turn 3: *"What color is it?"* | Gemini resolves "it" based on Turn 1; answers are concise plain text. | ✅ Verified |
| **Test B** | Same Object, Camera Movement | Ask question → move phone closer, rotate angle slightly → ask follow-up | Active thread continues; single-frame perspective shifts do not trigger reset. | ✅ Verified |
| **Test C** | Temporary Occlusion | Ask question → briefly cover lens with hand (< 0.4s) → return to object → ask follow-up | Debounce prevents premature reset; conversation thread stays active. | ✅ Verified |
| **Test D** | Completely New Object | Ask question on Object A → point to completely different Object B for > 0.4s → ask question | Scene divergence confirmed; old thread reset; Object B starts as Turn 1. | ✅ Verified |
| **Test E** | Rapid Camera Movement | Move phone quickly from Object A to Object B | No unstable rapid thread toggling or race conditions. | ✅ Verified |
| **Test F** | Ambiguous Transition | Move partially away from object and back within 0.3s | Conversation remains intact without flapping. | ✅ Verified |
| **Test G** | Multi-Turn Payload | Inspect request payload logging | Alternating `user`/`model` turns constructed correctly; stale turns excluded after scene change. | ✅ Verified |
| **Test H** | Bilingual Consistency | Multi-turn dialog in Indonesian mode (with English or Indonesian questions) | All Gemini responses stay strictly in Bahasa Indonesia across turns. | ✅ Verified |
| **Test I** | Regression Suite | Verify camera feed, OCR, Speech, Action Button, Persistent Answer | Zero regressions across baseline features. | ✅ Verified |

---

## Scene Stability Empirical Threshold Validation

| Parameter | Configuration Constant | Initial Hypothesis | Validation Observation | Final Empirical Value |
|-----------|------------------------|--------------------|------------------------|-----------------------|
| Divergence Threshold | `SceneStabilityConfiguration.divergenceThreshold` | `0.50` | Reliably separates natural hand jitter from distinct objects. | `0.50` |
| Confirmation Duration | `SceneStabilityConfiguration.confirmationDuration` | `0.35s` | `0.40s` provides smoother debounce during fast pans while remaining snappy. | `0.40s` |
| Thread Inactivity Timeout | `SceneStabilityConfiguration.threadInactivityTimeout` | N/A | 5-minute timeout prevents stale threads after long pauses. | `300.0s` |
| FeaturePrint Distance | `SceneStabilityConfiguration.featurePrintDistanceThreshold` | `0.40` | `0.45` accommodates moderate ambient shadow shifts without false trigger. | `0.45` |

---

## Debugging Tips

### Enable Developer Diagnostics
Settings → Developer → "Show Diagnostics on Camera" → ON

This overlay shows:
- Active Thread status & turn count
- Last Gemini latency (ms)
- Perceived turnaround (ms)
- Payload size (bytes)
- Multimodal status (200 OK / 429 / error)
- Scene divergence score
- Trigger type (Voice / Test-Text / Auto / Manual)

### Console Logging
Filter Xcode console by service tag:
- `[SPEECH]` — Speech recognition events
- `[VOICE]` — Audio synthesis events
- `[VisionService]` — Vision processing errors

### Common Issues
| Symptom | Likely Cause |
|---------|-------------|
| "API Key not configured" | `Secrets.swift` is gitignored and empty; enter key in Settings |
| Gemini returns English in Indonesian mode | Language directive may have been removed from prompt |
| Answer clears immediately | Scene divergence threshold too low or feature print distance spike |
| No speech transcription | Microphone permission denied; check iOS Settings |
| VoiceOver not announcing answers | `AccessibilityVoiceService.speak()` not called, or VoiceOver is off and synthesizer failed |
