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

## 🔑 Key Features & Current Capabilities

* **Onboarding & Spatial Interaction Anchor:**
  * 3-step accessible onboarding (`WelcomeView`) establishing a consistent **Bottom Interaction Zone** matching the live camera experience.
  * Proactive camera and microphone permission setup before interactive tutorials.
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
* **Accessibility-First Design:**
  * Unified audio management via `AccessibilityVoiceService` coordinating VoiceOver speech output, audio session ducking, and haptic feedback.
  * Native VoiceOver accessibility actions (focus → double-tap to record → double-tap to finish).
  * Actions rotor support to repeat previous answers on demand.

---

## 🏗️ Project Architecture

```text
TestApp/
├── App/
│   └── TestAppApp.swift
│
├── Features/
│   ├── Home/
│   │   ├── HomeView.swift
│   │   └── WelcomeView.swift                  # 3-step onboarding with bottom interaction zone
│   │
│   ├── Camera/
│   │   ├── CameraView.swift                   # Main live camera & multimodal voice interface
│   │   └── CameraManager.swift                # AVFoundation session & 1280px frame capture
│   │
│   ├── Recognition/
│   │   ├── VisionService.swift                # Apple Vision OCR (id-ID) & image classification
│   │   └── RecognitionResult.swift            # Observation data models & text candidates
│   │
│   ├── Multimodal/
│   │   ├── MultimodalService.swift            # Gemini 2.5 Flash REST client & accessibility prompts
│   │   ├── MultimodalConfig.swift             # Dynamic API key & model settings
│   │   └── Secrets.swift                      # Secure local API key configuration
│   │
│   ├── Interpretation/
│   │   ├── InterpretationService.swift        # Multi-signal evidence fusion & currency synthesis
│   │   └── InterpretationResult.swift         # Structured plain-text interpretation models
│   │
│   ├── Speech/
│   │   ├── SpeechService.swift                # SFSpeechRecognizer on-device audio transcription
│   │   └── AccessibilityVoiceService.swift    # VoiceOver audio output & announcement coordination
│   │
│   └── Settings/
│       └── SettingsView.swift                 # Locale selection & developer diagnostics
│
├── Tickets/                                   # Development milestones & research records
│   ├── ROADMAP.md
│   ├── T001-Baseline.md
│   ├── T002-Camera.md
│   ├── T003-Vision.md
│   ├── T004-Multimodal.md
│   ├── T005-Interpretation.md
│   ├── T006-Reliability.md
│   ├── T007-Conversational-Multimodal.md
│   └── T008-Accessibility-Experience.md
│
├── AGENTS.md                                  # Persistent context & AI engineering guidelines
└── README.md
```

---

## 📋 Development Roadmap & Status

Development progresses incrementally across focused milestones. Full specifications are documented in [`Tickets/ROADMAP.md`](Tickets/ROADMAP.md).

- [x] **T001: Baseline App Structure** (`Complete`)
- [x] **T002: Live Camera Preview & AVFoundation Session** (`Complete`)
- [x] **T003: Vision Classification & Text Recognition Baseline** (`Complete`)
- [x] **T004: Multimodal Understanding Baseline (Gemini 2.5 Flash)** (`Complete`)
- [x] **T005: Interpretation & Decision Layer (Multi-Signal Fusion)** (`Complete`)
- [x] **T006: Reliability & Real-World Evaluation** (`Complete`)
- [x] **T007: Conversational Multimodal Interaction & Voice Queries** (`Complete`)
- [x] **T008: Accessibility Experience, VoiceOver Audit & Banknote Robustness** (`Complete`)
- [ ] **T009: Conversational Memory & Spatial Context Refinement** (`Planned`)
- [ ] **T010: Create ML Feasibility & Evaluation** (`Planned`)

---

## 🛠️ Requirements & Setup

* **iOS Target:** iOS 17.0+
* **Development Environment:** Xcode 15.0+ / macOS Sonoma+
* **Dependencies:** Native Swift / SwiftUI, AVFoundation, Vision, Speech, CoreImage (Zero third-party package dependencies).
* **API Key:** Google Gemini API Key configured in Settings or [`Secrets.swift`](file:///Users/tiffanychristabelanggriawan/.gemini/antigravity-ide/scratch/TestApp/Features/Multimodal/Secrets.swift).
