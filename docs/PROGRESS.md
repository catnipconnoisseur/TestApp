# TestApp — Progress & Current State

> Last updated: 2026-09-02

---

## Project Timeline

**10-day Act Phase Challenge** (Apple Developer Academy)
- **Cycles 1–2** (Aug 26–27): Foundation, camera, Vision baseline, multimodal proof-of-concept
- **Cycles 3–4** (Aug 28–31): Interpretation layer, reliability evaluation, conversational interaction, accessibility audit
- **Cycle 5** (Sep 1–6): Polish, refinement, documentation
- **Evaluation** (Sep 7–8): Reserved for Academy evaluation

---

## Completed Milestones

### T001 — Baseline App Structure `Complete`
- SwiftUI app lifecycle, basic navigation, VoiceOver-compatible layout
- Commit: `Config: Establish root TestApp.xcodeproj`

### T002 — Live Camera Preview `Complete`
- AVFoundation `AVCaptureSession`, camera permission handling, live viewfinder
- Commit: `Verify live camera preview`

### T003 — Vision Classification Baseline `Complete`
- `VNClassifyImageRequest` + `VNRecognizeTextRequest` (OCR) on live camera frames
- Feature print embedding (`VNGenerateImageFeaturePrintRequest`) for scene comparison
- Indonesian OCR language + custom vocabulary
- Commit: `Establish Vision classification baseline`

### T004 — Multimodal Understanding Baseline `Complete`
- Gemini 2.5 Flash REST integration via native `URLSession`
- Structured HEADLINE/DESCRIPTION output contract
- On-device sensor hints passed to multimodal prompt
- Commit: `feat: complete multimodal understanding baseline`

### T005 — Interpretation & Decision Layer `Complete`
- Multi-signal evidence fusion (`InterpretationService`)
- Scene divergence detection (OCR + classification + feature print)
- Dwell/stability evaluation with smoothing window
- Indonesian Rupiah denomination validation (70+ text variants)
- Clean plain-text output formatting
- Commit: `Implement interpretation and decision layer`

### T006 — Reliability & Real-World Evaluation `Complete`
- Request throttling and rate-limit handling
- User-initiated multimodal pipeline (not auto-triggering)
- Latency and payload telemetry
- Commit: multiple refinement commits

### T007 — Conversational Multimodal Interaction `Complete`
- On-device `SFSpeechRecognizer` with hold-to-talk recording
- Voice query → camera snapshot → Gemini reasoning → spoken answer
- Persistent AI answer display with scene divergence clearing
- Conversational context (previous identification) passed to follow-up queries
- Camera-first navigation (removed HomeView, added WelcomeView onboarding)
- Single large voice interaction area replacing dual-button layout
- Settings sheet (language, API key, developer diagnostics)
- Commit: `feat(ui): implement camera-first navigation`

### T008 — Accessibility Experience & Banknote Robustness `Complete`
- 3-step accessible onboarding with proactive permission setup
- VoiceOver reading order audit (settings → viewfinder → result → voice area)
- Native VoiceOver accessibility actions (focus → double-tap)
- `AccessibilityVoiceService` dual-mode audio coordinator
- Physical deformation resilience in Gemini prompts
- Multi-signal banknote robustness (color + portrait + OCR + emblem)
- Image capture resolution upgrade to 1280px
- Commit: `feat(a11y): implement proactive permissions`

### Cross-Cutting: Language-Aware AI Pipeline `Complete`
- Full locale routing: `SpeechService.selectedLocale` → Gemini prompt directive → InterpretationService locale-aware headlines → AccessibilityVoiceService language-matched output
- Indonesian mode: all AI responses in natural Bahasa Indonesia
- Commit: `feat(i18n): route selected language through entire AI pipeline`

### Cross-Cutting: Visual Recognition Accuracy `Complete`
- 1280px capture resolution for fine text and denomination numerals
- Expanded Indonesian OCR custom vocabulary
- Multi-cue Gemini prompts (color schemes, national hero portraits, emblem layouts)
- Deformation-resilient prompt rules
- Commit: `feat(recognition): enhance visual recognition accuracy`

### Cross-Cutting: Quick Access & Action Button Integration `Complete`
- `QuickAccessIntent` (`AppIntent`) and `TestAppShortcuts` (`AppShortcutsProvider`)
- Action Button, Siri ("Ask TestApp" / "Tanya TestApp"), Spotlight, and Shortcuts support
- Immediate foregrounding with scene phase lifecycle management and nonvisual "TestApp ready" announcements
- Optional guided setup card during first-launch onboarding on the Permissions / Setup page (`WelcomeView` Screen 2)
- Reusable `QuickAccessSetupSheet` in Settings and Onboarding with `ShortcutsLink` and iOS Settings deep-link
- Corrected 4-step onboarding flow: Welcome → Permissions / Setup → Try Asking → Get Started
- Full bilingual English and Indonesian support throughout onboarding, guidance, and VoiceOver feedback
- *Note:* Hardware Action Button assignment requires physical iPhone 15 Pro+ and user selection in iOS Settings.

---

### T009 — Scene-Anchored Conversational Memory `Complete`
- `SceneConversationThread` & `ConversationTurn` data models in `ConversationMemory.swift`
- Local scene tracking via `VNFeaturePrintObservation` cosine distance
- Temporal confirmation debounce ($\ge 0.50$ divergence for $\ge 0.40$s) before resetting conversation context
- Multi-turn Gemini request construction with alternating `user` / `model` history
- Empirical configuration consolidation in `SceneStabilityConfiguration`
- Inactivity expiration (5 minutes) and bilingual language preservation across multi-turn dialogs
- Developer telemetry overlay showing active thread status, turn counts, and divergence scores
- Commit: `feat(memory): implement scene-anchored conversational memory (T009)`

---

### T010 — Create ML Feasibility & Evaluation `Complete`
- Research and comparative evaluation of built-in Apple Vision vs custom Create ML vs Gemini 2.5 Flash
- Indonesian Rupiah deformation analysis (crumpled, folded, occluded, low-light notes)
- Dataset requirement specification ($\ge 4,000$ annotated images for 7 classes)
- Evaluated offline accessibility trade-offs and decision to defer model bundling in favor of existing hybrid multi-signal pipeline
- Comprehensive research report in `docs/T010-CREATEML-FEASIBILITY.md` and decision record D018

---

### T011 — Field Usability Validation & Multi-Turn Tuning `Complete`
- Physical device execution of T009 Tests A–I (same scene multi-turn, camera movements, occlusions, new object reset, payload checks, bilingual behavior)
- Empirical threshold validation: confirmed `0.50` divergence threshold and `0.40s` confirmation duration
- VoiceOver & Screen Curtain non-visual audit: 100% blind simulation completed successfully
- Action Button & Quick Access cold/warm launch timing (~650–850ms cold launch) and microphone safety verified

---

### T012 — Repeat Answer & Tactile Thinking Haptics `Complete`
- Added Accessibility Magic Tap (`.accessibilityAction(.magicTap)`) for two-finger double-tap instant answer replay
- Added visible speaker replay button in `interpretationCard`
- Implemented rhythmic tactile heartbeat pulses during `.thinking` state with success/error haptic feedback
- Added `repeatAnswer` helper in `AccessibilityVoiceService` for unified audio coordination

---

### T013 — Codebase Cleanliness & Architecture Polish `Complete`
- Extracted `CameraViewModel.swift` (`@MainActor final class CameraViewModel: ObservableObject`), encapsulating camera, speech, multimodal, and scene memory state
- Decoupled SwiftUI presentation logic from business/orchestration logic, reducing `CameraView.swift` to ~810 lines
- Eliminated `temporaryTestingInputBar` and legacy debug text input properties
- Verified zero regression in full build verification

---

## Current Status

**T001–T013 Complete.** The entire C4 challenge prototype is clean, robustly structured, and verified.

---

## Known Technical Debt

1. **`InterpretationService` is ~610 lines** with substantial currency validation logic. Could be extracted into a dedicated `CurrencyRecognitionService` if more currencies are added.
2. **No unit tests.** Verification has been manual (build + on-device testing). Unit testing infrastructure is not set up.
3. **`Secrets.swift` is gitignored** but referenced by `MultimodalConfig`. New developers must create this file manually.
