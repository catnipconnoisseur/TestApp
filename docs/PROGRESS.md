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

## Planned / Not Yet Started

### T009 — Conversational Memory & Spatial Context `Planned`
- Scene-anchored conversational memory (multi-turn context beyond single previous answer)
- Repeat answer gesture via Actions Rotor
- Tactile progress feedback during thinking state

### T010 — Create ML Feasibility & Evaluation `Planned`
- Evaluate whether a custom trained model improves recognition beyond Gemini + Vision
- Only implement if justified by real limitation evidence

---

## Current Active Ticket

**None actively in progress.** T008 was the last completed ticket. Documentation system is being established.

---

## Known Technical Debt

1. **CameraView is ~1400 lines.** It handles all UI state, interaction logic, and view composition. If complexity grows, extracting a `CameraViewModel` may be justified.
2. **Temporary test input bar** still exists in `CameraView` (lines ~103–105, 206–260). Labeled `TEMPORARY T007.2 TEST INPUT — REMOVE AFTER TESTING`.
3. **`InterpretationService` is ~610 lines** with substantial currency validation logic. Could be extracted into a dedicated `CurrencyRecognitionService` if more currencies are added.
4. **No unit tests.** Verification has been manual (build + on-device testing). Unit testing infrastructure is not set up.
5. **`Secrets.swift` is gitignored** but referenced by `MultimodalConfig`. New developers must create this file manually.
