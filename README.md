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
│   │   └── HomeView.swift
│   │
│   ├── Camera/
│   │   ├── CameraView.swift
│   │   └── CameraManager.swift
│   │
│   ├── Recognition/
│   │   ├── VisionService.swift
│   │   └── RecognitionResult.swift
│   │
│   ├── Multimodal/
│   │   ├── MultimodalService.swift
│   │   └── MultimodalConfig.swift
│   │
│   ├── Interpretation/
│   │   ├── InterpretationService.swift
│   │   └── InterpretationResult.swift
│   │
│   └── Accessibility/
│       └── SpeechManager.swift
│
├── AGENTS.md                          # Persistent context & architecture guidelines
└── README.md
```

---

## 📋 Development Roadmap

Development progresses incrementally across focused milestones. See [`Tickets/ROADMAP.md`](Tickets/ROADMAP.md) for full roadmap details.

- [x] **Baseline App Structure** (`Complete`)
- [x] **Live Camera Preview** (`Complete`)
- [x] **Vision Classification Baseline (Banknotes)** (`Complete`)
- [x] **Multimodal Understanding Baseline** (`Complete`)
- [x] **Interpretation & Decision Layer** (`Complete`)
- [ ] **Spoken Accessibility Output (Voice/Audio)** (`Planned`)
- [ ] **Vision Exploration on Local Spices** (`Planned`)
- [ ] **Real-World Input & Uncertainty Handling** (`Planned`)
- [ ] **Create ML Feasibility & Evaluation** (`Planned`)
