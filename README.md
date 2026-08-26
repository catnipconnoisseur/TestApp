# TestApp

> An Apple Developer Academy Act Phase learning project exploring visual accessibility using Apple visual technologies.

---

## 🎯 Learning Objective

> **Learn how to use Apple's Vision framework and multimodal capabilities to analyze and interpret real-world visual input, and explore how Create ML could extend the solution when built-in capabilities are not sufficient.**

---

## 💡 Overview & Problem

People who are blind or visually impaired often encounter situations where everyday visual information is inaccessible (such as identifying Indonesian banknotes, local spices/ingredients, reading labels, or understanding signs).

**Intended Interaction Pipeline:**
```text
Camera → visual input → analysis → useful information → accessible response
```

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
│   │   └── HomeViewModel.swift        # Only when justified
│   │
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   ├── CameraViewModel.swift      # Only when justified
│   │   └── CameraManager.swift
│   │
│   ├── Recognition/
│   │   ├── RecognitionView.swift
│   │   ├── RecognitionViewModel.swift # Only when justified
│   │   ├── VisionService.swift
│   │   └── RecognitionResult.swift
│   │
│   └── Accessibility/
│       └── SpeechManager.swift
│
├── Tickets/
│   ├── ROADMAP.md
│   ├── T001-Baseline/
│   │   └── T001-Baseline.md
│   ├── T002-Camera/
│   │   └── T002-Camera.md
│   └── ...
│
├── AGENTS.md                          # Persistent context & architecture guidelines
└── README.md
```

---

## 📋 Hybrid Ticket Roadmap

Development progresses incrementally using a ticket-based workflow. See [`Tickets/ROADMAP.md`](Tickets/ROADMAP.md) for full roadmap details.

- [x] **T001 — Baseline App Structure** (`Complete`)
- [x] **T002 — Live Camera Preview** (`Complete`)
- [ ] **T003 — Vision Classification Baseline (Banknotes)** (`Planned`)
- [ ] **T004 — Spoken Accessibility Output (Voice/Audio)** (`Planned`)
- [ ] **T005 — Vision Exploration on Local Spices** (`Planned`)
- [ ] **T006 — Real-World Input & Uncertainty Handling** (`Planned`)
- [ ] **T007 — Multimodal Contextual Interpretation** (`Planned`)
- [ ] **T008 — Create ML Feasibility & Evaluation** (`Planned`)
