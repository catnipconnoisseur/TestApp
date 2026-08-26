# TestApp — AI Development Context & Architecture Guidelines

> **This file is the persistent context and working instructions for AI coding agents contributing to TestApp.**
>
> Before modifying the project, read this file or `AGENTS.md`, then read the Markdown file for the current ticket.

---

# 1. Project

**Name:** TestApp *(temporary working name)*
**Platform:** iOS
**Framework:** SwiftUI
**Language:** Swift

TestApp is an Apple Developer Academy learning project exploring how Apple's visual technologies can help people who are blind or visually impaired access everyday visual information.

The application is being developed as a **10-day Act Phase learning challenge**.

---

# 2. Learning Objective

> Learn how to use Apple's **Vision framework and multimodal capabilities to analyze and interpret real-world visual input**, and explore how **Create ML could extend the solution when built-in capabilities are not sufficient**.

Learning evidence:

> An **iterated prototype that uses the camera to recognize or understand visual information and turn it into a useful response**.

By the end of the challenge, the learner should be able to:

* Implement a visual-processing pipeline.
* Evaluate whether a technology is appropriate for a problem.
* Identify limitations of built-in capabilities.
* Explain how technology improves the interaction.
* Iterate based on real-world testing.

---

# 3. Problem

People who are blind or visually impaired can encounter situations where visual information is useful but inaccessible (e.g., Indonesian banknotes, local spices/ingredients, labels, signs).

The intended interaction is:

**Camera → visual input → analysis → useful information → accessible response**

The application should provide the **smallest useful piece of information** rather than attempting to describe everything visible.

---

# 4. Research Conclusions

* **Vision:** Specialized visual analysis (classification, text recognition, feature analysis).
* **Multimodal:** Contextual interpretation of visual input.
* **Create ML:** Extension when built-in capabilities are insufficient, not a default requirement.

---

# 5. Architecture & Project Structure

The project uses a **feature-oriented structure with lightweight architecture**.

```text
TestApp/
│
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
│   └── ...
│
├── AI/
│   ├── AGENTS.md
│   └── AI_CONTEXT.md
│
├── Resources/
│
└── README.md
```

---

# 6. Hybrid Ticket Development Workflow

We use a **hybrid ticket development system**:
* Maintain a rough roadmap of **6–10 upcoming tickets** in `Tickets/ROADMAP.md`.
* Actively develop and fully specify **only one ticket at a time**.
* Future tickets represent **intentions**, not rigid commitments.
* Statuses: `Planned` | `In Progress` | `Complete` | `Blocked` | `Cancelled`

---

# 7. Current Development State

* **Active Ticket:** **T001 — Baseline App Structure** `[Complete]`
* **Next Ready Ticket:** **T002 — Live Camera Preview** `[Planned]`
