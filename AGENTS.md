# TestApp — AI Development Context & Architecture Guidelines

> **This file is the persistent context and working instructions for AI coding agents contributing to TestApp.**
>
> Before modifying the project, read this file first, then read the Markdown file for the current ticket.

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

People who are blind or visually impaired can encounter situations where visual information is useful but inaccessible.

Examples include:

* Identifying Indonesian banknotes.
* Identifying local spices and ingredients.
* Reading labels.
* Understanding signs.
* Identifying everyday visual information.

The intended interaction is:

**Camera → visual input → analysis → useful information → accessible response**

The application should provide the **smallest useful piece of information**, rather than attempting to describe everything visible.

Example:

Instead of:

> "I see a rectangular object with several colors and text..."

Prefer:

> "Rp50,000."

or:

> "This appears to be turmeric."

---

# 4. Research Conclusions

## Vision

Vision is suited to specialized visual analysis such as:

* Image classification
* Text recognition
* Object/feature analysis
* Other structured computer-vision tasks

## Multimodal Capabilities

Multimodal capabilities can provide broader contextual interpretation of visual input.

Conceptually:

**Vision → specialized visual analysis**

**Multimodal → contextual interpretation**

They may eventually be combined.

## Create ML

Create ML is a possible extension, not a default requirement.

The intended decision process is:

**Built-in Vision → test → identify limitation → investigate multimodal → test → Create ML if justified**

Do not introduce Create ML simply because the project involves AI/ML.

---

# 5. Current Candidate Features

## Indonesian Banknotes

Potential interaction:

**Camera → denomination recognition → accessible response**

Example:

> "Rp50,000."

Banknote recognition is an established accessibility use case, so this is not being treated as an entirely novel problem. It is useful as a practical feature and recognition baseline.

## Local Spices / Ingredients

Potential interaction:

**Camera → ingredient recognition → accessible response**

Example:

> "This appears to be turmeric."

This is technically interesting because appearance may vary considerably depending on:

* Lighting
* Camera angle
* Distance
* Container
* Preparation
* Background
* Similar-looking ingredients

This makes spices particularly useful for investigating the limitations of visual recognition.

---

# 6. Reliability Principle

The application must eventually be tested with imperfect real-world input.

Examples:

* Poor lighting
* Blur
* Different angles
* Different distances
* Partial views
* Different containers
* Different backgrounds
* Similar-looking objects
* Unfamiliar objects

Important principle:

> **A confidently incorrect answer can be worse than an uncertain answer.**

Therefore, uncertainty and failure handling will eventually become part of the design.

---

# 7. Technology Selection Principle

Never implement a technology merely because it sounds impressive.

Ask:

> **Does this technology genuinely improve the solution?**

For example:

* If Vision is sufficient, do not unnecessarily introduce multimodal processing.
* If multimodal processing is sufficient, do not unnecessarily train a custom model.
* If Create ML does not meaningfully improve recognition, do not use it simply to demonstrate ML.

The technology should serve the problem.

---

# 8. Hybrid Ticket Development Workflow

We use a **hybrid ticket development system**:
* Maintain a rough roadmap of **6–10 upcoming tickets** in advance (in `Tickets/ROADMAP.md`) to provide clear direction.
* Actively develop and fully specify **only one ticket at a time**.
* Future tickets represent **intentions**, not rigid commitments.
* The roadmap is adjusted dynamically based on what is learned from completed tickets.

### Development Cycle

**Roadmap → Ticket → Implement → Test → Learn → Adjust Roadmap → Next Ticket**

### Ticket Statuses

* `Planned` — identified as a possible future step (lightweight outline only)
* `In Progress` — currently being actively planned, implemented, or tested
* `Complete` — successfully implemented, tested, and documented
* `Blocked` — cannot proceed because of a technical or research dependency
* `Cancelled` — no longer useful based on discoveries (with reason documented)

---

# 9. Working High-Level Roadmap

| Ticket | Name | Status | Focus / Dependency |
| :--- | :--- | :--- | :--- |
| **T001** | **Baseline App Structure** | `Complete` | SwiftUI app lifecycle, baseline UI, VoiceOver |
| **T002** | **Live Camera Preview** | `Planned` | AVFoundation camera feed, permission, visual input pipeline |
| **T003** | **Vision Classification Baseline (Banknotes)** | `Planned` | Built-in Vision request on structured banknotes *(depends on T002)* |
| **T004** | **Spoken Accessibility Output (Voice/Audio)** | `Planned` | Speech synthesis / accessible readout *(depends on T003)* |
| **T005** | **Vision Exploration on Local Spices** | `Planned` | Test Vision limits on ambiguous items *(depends on T003)* |
| **T006** | **Real-World Input & Uncertainty Handling** | `Planned` | Lighting/blur tests, confidence thresholds, fallback states *(depends on T005)* |
| **T007** | **Multimodal Contextual Interpretation** | `Planned` | Broader context reasoning for ambiguous items *(depends on T005, T006)* |
| **T008** | **Create ML Feasibility & Evaluation** | `Planned` | Evaluate custom model need vs built-in, prepare final prototype *(depends on T007)* |

*Note: Future tickets (T003+) will only be specified in detail when they become active and will be updated based on experimental findings.*

---

# 10. Act Phase Cycles

The Act Phase consists of five cycles:

### Cycle 1
Technology investigation and problem understanding.

### Cycle 2
Initial prototype.

### Cycle 3
Prototype iteration.

### Cycle 4
Further iteration and refinement.

### Cycle 5
Final iteration and preparation for evaluation.

September 7–8 are reserved for evaluation.

---

# 11. Architecture & Project Structure

The project should use a **feature-oriented structure with lightweight architecture**.

The architecture should grow according to actual complexity:
> **Introduce a layer when the current code has a real problem that the layer solves.**

Preferred structure:

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
│   ├── T001-Baseline.md
│   ├── T002-Camera.md
│   └── ...
│
├── Resources/
│
├── AGENTS.md
└── README.md
```

### Architectural Layer Responsibilities
* **Views**: UI layout, presentation, user interaction, connecting UI to state.
* **ViewModels**: Used only when a view has meaningful state or presentation logic that justifies extraction from the view.
* **Managers**: Own system-level resources or hardware lifecycles (e.g. `CameraManager` for AVFoundation).
* **Services**: Encapsulate external or specialized domain processing (e.g. `VisionService` for Vision requests).
* **Models**: Structured domain data (e.g. `RecognitionResult` for classification, confidence, uncertainty).

Do not create empty folders prematurely. Only create a feature folder when that feature is actively implemented.

---

# 12. Ticket Documentation Template

Every ticket has its own Markdown file directly under `Tickets/` (`Tickets/TXXX-Name.md`).

```markdown
# TXXX — Ticket Name

## Goal
One or two sentences describing what this ticket accomplishes.

## Why
Why this ticket matters to the current learning/build progression.

## Scope
- What will be implemented
- What will be tested

## Out of Scope
- Things intentionally postponed
- Future technology/features

## Tasks
- [ ] Task 1
- [ ] Task 2

## Implementation Notes
Brief notes about important technical decisions.

## Validation
- [ ] Test 1
- [ ] Test 2

## Result
**Status:** In Progress / Complete / Blocked / Cancelled
Briefly describe what actually happened.

## Learning / Findings
What did I learn from completing this ticket?

## Changes from Plan
Only include if something changed from the original plan.

## Next Step
One sentence describing the logical next ticket.
```

---

# 13. AI Working Rules

When working on this project:

## Always
* Read `AGENTS.md` first.
* Identify the current ticket.
* Read that ticket's Markdown file.
* Work only within the current ticket.
* Keep changes small.
* Explain important technical decisions.
* Test before moving forward.
* Record meaningful discoveries.
* Preserve existing working functionality.

## Never
* Implement future tickets without permission.
* Rewrite unrelated code.
* Add architecture prematurely.
* Add unnecessary dependencies.
* Add AI/ML just because it sounds impressive.
* Assume an API works without checking when current documentation matters.
* Create large amounts of code without explaining the purpose.

---

# 14. Git Workflow

This is a **solo development project**. The Git workflow remains intentionally simple:

```text
Ticket → Implement → Test → Commit → main
```

### Branch Strategy
* Use a single primary branch: `main`.
* Do NOT create separate branches for every ticket by default.
* Use a separate branch (e.g. `experiment/...`) only for risky architectural spikes or potentially breaking changes that need isolation.

### Commit & Push Permission Rule
* **CRITICAL:** Do NOT automatically commit or push changes to Git/GitHub unless the user explicitly asks you to do so (e.g., "commit and push", "push this to GitHub").
* Always wait for the user's explicit instruction before executing any `git commit` or `git push` commands.

> **Rule:** One developer → one main branch → one ticket at a time → commit/push ONLY when explicitly requested.

---

# 15. Current Development State

* **Active Ticket:** **T002 — Live Camera Preview** `[Complete]`
* **Next Ready Ticket:** **T003 — Vision Classification Baseline (Banknotes)** `[Planned]`

---

# 16. Source of Truth

When information conflicts:

1. Current user instruction
2. Current ticket file
3. `AGENTS.md`
4. Existing implementation

The current user instruction always takes priority.
