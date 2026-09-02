# TestApp — Project Structure

> Last updated: 2026-09-02

---

## Root Layout

```text
TestApp/
├── App/                          # App entry point & assets
│   ├── TestAppApp.swift          # @main, onboarding gate via @AppStorage
│   └── Assets.xcassets/          # App icon, accent color, image assets
│
├── Features/                     # Feature-oriented modules (one folder per concern)
│   ├── Camera/                   # Live camera experience & viewfinder
│   ├── Home/                     # First-launch onboarding (WelcomeView)
│   ├── Interpretation/           # Multi-signal evidence synthesis
│   ├── Multimodal/               # Gemini API client & prompt engineering
│   ├── QuickAccess/              # App Intents & Action Button shortcuts
│   ├── Recognition/              # On-device Apple Vision (OCR + classification)
│   ├── Settings/                 # User preferences sheet
│   └── Speech/                   # On-device speech recognition & audio output
│
├── tickets/                      # Development ticket documentation
│   ├── ROADMAP.md                # High-level ticket roadmap & change log
│   ├── T001-BASELINE.md          # through T008; each ticket has its own file
│   └── ...
│
├── TestApp.xcodeproj/            # Xcode project config (pbxproj + shared data)
├── AGENTS.md                     # Root agent context file (read this first)
├── README.md                     # Public-facing project description
├── docs/                         # Persistent project context files
│   ├── STRUCTURE.md              # ← This file
│   ├── CONVENTIONS.md            # Code style, naming, patterns
│   ├── DECISIONS.md              # Key architectural & product decisions
│   ├── PROGRESS.md               # Current state & milestones
│   ├── ACCESSIBILITY.md          # VoiceOver & a11y conventions
│   ├── AI-BEHAVIOR.md            # Gemini prompts, interpretation rules, language
│   └── TESTING.md                # Build, verify, and known test scenarios
└── .gitignore
```

---

## Feature Modules — File Inventory

### Camera/
| File | Role | Size |
|------|------|------|
| `CameraView.swift` | Clean SwiftUI view layout: viewfinder preview, top bar, speech card, interpretation card, and large 120pt voice area. (~810 lines). | ~30 KB |
| `CameraViewModel.swift` | Central `@MainActor` ViewModel coordinating camera feed, on-device vision, speech recognition, Gemini multi-turn reasoning, scene divergence tracking, and thinking haptics. (~545 lines). | ~22 KB |
| `CameraManager.swift` | AVFoundation `AVCaptureSession` lifecycle, frame delivery to VisionService, on-demand JPEG capture (1280px max). | ~7 KB |

### Home/
| File | Role | Size |
|------|------|------|
| `WelcomeView.swift` | 4-step accessible onboarding: Welcome → Permissions / Setup → Try Asking → Get Started. Appears only on first launch. Sets `hasCompletedOnboarding` in `@AppStorage`. | ~30 KB |

### Recognition/
| File | Role | Size |
|------|------|------|
| `VisionService.swift` | Apple Vision framework requests: `VNClassifyImageRequest`, `VNRecognizeTextRequest` (OCR, id-ID + en-US), `VNGenerateImageFeaturePrintRequest`. Frame throttled. | ~5 KB |
| `RecognitionResult.swift` | Data models: `ClassificationItem`, `RecognizedTextItem`, `VNFeaturePrintObservation` reference. | ~2 KB |

### Multimodal/
| File | Role | Size |
|------|------|------|
| `MultimodalService.swift` | Gemini 2.5 Flash REST client via native `URLSession`. Multi-turn visual reasoning (`analyzeMultiTurn`), prompt builders (`buildDefaultAnalysisPrompt`, `buildVoiceQuestionPrompt`, `buildFollowUpVoicePrompt`). Language directive injection. | ~18 KB |
| `ConversationMemory.swift` | Conversational memory data models (`SceneConversationThread`, `ConversationTurn`) and empirical scene stability parameters (`SceneStabilityConfiguration`). | ~3 KB |
| `MultimodalConfig.swift` | API key resolution chain: `Secrets.swift` → `UserDefaults` → `Info.plist`. | ~2 KB |
| `Secrets.swift` | Gitignored local API key constant. | <1 KB |

### Interpretation/
| File | Role | Size |
|------|------|------|
| `InterpretationService.swift` | Multi-signal evidence fusion. Dwell/stability evaluation, scene divergence scoring, Indonesian Rupiah denomination validation, structured response parsing (HEADLINE/DESCRIPTION). | ~28 KB |
| `InterpretationResult.swift` | Domain models: `AnalysisState`, `EvidenceConfidence`, `EvidenceSource`, `InterpretationResult`. | ~3 KB |

### Speech/
| File | Role | Size |
|------|------|------|
| `SpeechService.swift` | On-device `SFSpeechRecognizer` with hold-to-talk recording, locale-aware transcription, and `UserDefaults` persistence for `selectedLocale`. | ~9 KB |
| `AccessibilityVoiceService.swift` | Singleton spoken audio coordinator. Routes through VoiceOver announcements (when active) or `AVSpeechSynthesizer` (when VoiceOver is off). Language-aware voice selection. | ~3 KB |

### QuickAccess/
| File | Role | Size |
|------|------|------|
| `QuickAccessIntent.swift` | `QuickAccessIntent` (`AppIntent`) and `TestAppShortcuts` (`AppShortcutsProvider`) exposing Action Button, Siri, and Shortcuts triggers with zero setup. | ~1 KB |
| `QuickAccessGuideView.swift` | `QuickAccessSetupSheet` and `QuickAccessOnboardingCardView` providing step-by-step setup guidance, `ShortcutsLink`, and iOS Settings deep-linking. | ~11 KB |

### Settings/
| File | Role | Size |
|------|------|------|
| `SettingsView.swift` | SwiftUI `Form` sheet: language picker (EN/ID), API key SecureField, developer diagnostics toggle. | ~5 KB |

---

## Dependency Graph (Runtime)

```text
TestAppApp
  └── CameraView
        ├── CameraManager
        │     ├── AVCaptureSession
        │     └── VisionService → RecognitionResult
        ├── SpeechService (on-device transcription)
        ├── MultimodalService (Gemini API)
        │     └── MultimodalConfig → Secrets
        ├── InterpretationService
        │     └── InterpretationResult
        ├── AccessibilityVoiceService.shared (singleton)
        └── SettingsView (sheet)
```

---

## Key Conventions

- **No ViewModels**: State lives in `CameraView` via `@State`. No separate ViewModel layer exists.
- **No third-party dependencies**: Everything uses native Apple frameworks.
- **Feature folders are flat**: Each feature folder contains only its directly related files, no nested subdirectories.
- **Services are plain classes**: `VisionService`, `InterpretationService`, `MultimodalService` are non-observable plain classes. `CameraManager` and `SpeechService` use `@Observable`.
