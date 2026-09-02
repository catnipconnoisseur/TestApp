# TestApp

> An intelligent visual accessibility assistant built with SwiftUI, Apple Vision, on-device speech recognition, and Gemini multimodal AI to help people who are blind or visually impaired understand their physical surroundings.

---

## 🎯 Learning Objective

> **Learn how to use Apple's Vision framework and multimodal capabilities to analyze and interpret real-world visual input, and explore how Create ML could extend the solution when built-in capabilities are not sufficient.**

---

## 💡 Overview & Problem

People who are blind or visually impaired frequently encounter situations where everyday visual information is inaccessible—such as identifying Indonesian banknotes, recognizing packaged items, reading printed labels, or understanding signage.

Rather than acting as a simple object classifier that recites broad labels (*"Bottle"*, *"Paper"*), TestApp is designed as an **Intelligent Visual Assistant**:
* The **camera** acts as continuous optical grounding for the AI.
* The **voice interface** gives the user direct agency to ask natural, specific questions (*"What is this?"*, *"Is this bill 50,000 or 100,000?"*, *"What does this label say?"*).
* The **decision & interpretation layer** synthesizes on-device Vision, OCR, and cloud multimodal reasoning into concise, plain-text spoken answers without auditory overload.

### Core Interaction Flow:
```text
POINT CAMERA → TOUCH & HOLD TO ASK → REASONING & EVIDENCE FUSION → CONCISE SPOKEN ANSWER
```

---

## 🔑 Key Features & Capabilities

* **Hardware Quick Access & System-Level Integration:**
  * Physical iPhone **Action Button** mapping and **Siri App Shortcuts** (*"Ask TestApp"*, *"Tanya TestApp"*).
  * Direct foreground launch into live visual assistance with immediate spoken arrival announcement.
  * Powered by `AppIntents`, `AppShortcutsProvider`, and `QuickAccessIntent`.
* **Central Onboarding & Setup Hub:**
  * 4-step static, unscrollable onboarding (`WelcomeView`): `Welcome → Permissions & Setup Hub → Try Asking → Get Started`.
  * Central setup hub managing required permissions (Camera, Microphone, Speech) and optional Action Button configuration.
  * Live on-device practice area with real-time speech transcription and haptic feedback.
* **Camera-First Live Experience:**
  * High-speed, low-latency live camera viewfinder with Apple Vision continuous OCR and classification.
  * Persistent AI answer display across natural camera movement with multi-signal scene divergence detection.
* **Conversational Multimodal Intelligence:**
  * Voice query capture using on-device `SpeechService` (press-and-hold to speak, release to submit).
  * Multimodal reasoning powered by Gemini 2.5 Flash, returning structured plain-text headlines and descriptions.
  * Intent-controlled visual detail rules (Progressive Disclosure) preventing unsolicited visual monologues.
* **Physical Deformation & Banknote Robustness:**
  * Multi-signal currency synthesis combining color signatures (e.g. Red=Rp100k, Blue=Rp50k), national hero portraits, on-device OCR, and emblem layouts.
  * Robust recognition of wrinkled, folded, creased, angled, and partially occluded banknotes.
* **Accessibility-First & Bilingual Design:**
  * Seamless English (`en-US`) and Indonesian (`id-ID`) language switching across speech input, Gemini prompts, and TTS voice output.
  * Unified audio management via `AccessibilityVoiceService` coordinating VoiceOver speech output, audio session ducking, and haptic feedback.
  * Spatial anchor consistency (120pt bottom touch card across all views).

---

## 🏗️ Project Architecture

```text
TestApp/
├── App/
│   └── TestAppApp.swift                  # App entry & AppShortcut parameter registration
│
├── Features/
│   ├── Home/
│   │   └── WelcomeView.swift              # 4-step static onboarding & central setup hub
│   │
│   ├── QuickAccess/
│   │   ├── QuickAccessIntent.swift        # AppIntent & AppShortcutsProvider (Action Button)
│   │   └── QuickAccessGuideView.swift     # Compact setup sheet & onboarding card
│   │
│   ├── Camera/
│   │   ├── CameraView.swift               # Main live camera & multimodal voice interface
│   │   └── CameraManager.swift            # AVFoundation session & 1280px frame capture
│   │
│   ├── Recognition/
│   │   ├── VisionService.swift            # Apple Vision OCR (id-ID) & image classification
│   │   └── RecognitionResult.swift        # Observation data models & text candidates
│   │
│   ├── Multimodal/
│   │   ├── MultimodalService.swift        # Gemini 2.5 Flash REST client & accessibility prompts
│   │   ├── MultimodalConfig.swift         # Dynamic API key & model settings
│   │   └── Secrets.swift                  # Secure local API key configuration
│   │
│   ├── Interpretation/
│   │   ├── InterpretationService.swift    # Multi-signal evidence fusion & currency synthesis
│   │   └── InterpretationResult.swift     # Structured plain-text interpretation models
│   │
│   ├── Speech/
│   │   ├── SpeechService.swift            # SFSpeechRecognizer on-device audio transcription
│   │   └── AccessibilityVoiceService.swift# VoiceOver audio output & announcement coordination
│   │
│   └── Settings/
│       └── SettingsView.swift             # Locale selection & developer diagnostics
│
├── docs/                                  # Project technical documentation
│   ├── STRUCTURE.md
│   ├── CONVENTIONS.md
│   ├── DECISIONS.md
│   ├── PROGRESS.md
│   ├── ACCESSIBILITY.md
│   ├── AI-BEHAVIOR.md
│   └── TESTING.md
│
├── AGENTS.md                              # Technical guide & architecture reference
└── README.md
```

---

## 📋 Development Milestones & Status

- [x] **Baseline App Structure & Lifecycle** (`Complete`)
- [x] **Live Camera Preview & AVFoundation Session** (`Complete`)
- [x] **Vision Classification & Text Recognition Baseline** (`Complete`)
- [x] **Multimodal Understanding Baseline (Gemini 2.5 Flash)** (`Complete`)
- [x] **Interpretation & Decision Layer (Multi-Signal Fusion)** (`Complete`)
- [x] **Reliability & Real-World Evaluation** (`Complete`)
- [x] **Conversational Multimodal Interaction & Voice Queries** (`Complete`)
- [x] **Accessibility Experience & Banknote Robustness** (`Complete`)
- [x] **Quick Access, Action Button & Central Setup Hub** (`Complete`)
- [x] **Scene-Anchored Conversational Memory** (`Complete`)
- [ ] **Create ML Feasibility & Evaluation** (`In Progress`)

---

## 🛠️ Requirements & Setup

* **iOS Target:** iOS 17.0+
* **Development Environment:** Xcode 15.0+ / macOS Sonoma+
* **Dependencies:** Native Swift / SwiftUI, AVFoundation, Vision, Speech, CoreImage (Zero third-party package dependencies).
* **API Key:** Google Gemini API Key configured in Settings or [`Secrets.swift`](file:///Users/tiffanychristabelanggriawan/.gemini/antigravity-ide/scratch/TestApp/Features/Multimodal/Secrets.swift).
