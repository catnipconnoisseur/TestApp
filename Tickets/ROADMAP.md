# BantuLihat / TestApp — Development Roadmap

This file tracks the evolving high-level roadmap for the 10-day Act Phase challenge.

> **Principle:** Maintain approximately 6–10 high-level tickets as lightweight intentions. Only the active ticket is designed and implemented in detail. Findings from tests actively update and refine upcoming tickets.

---

## Roadmap Overview

| Ticket | Name | Status | Purpose / Focus | Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **T001** | **Baseline App Structure** | `Complete` | SwiftUI app lifecycle, baseline UI, VoiceOver navigation | None |
| **T002** | **Live Camera Preview** | `Complete` | AVFoundation camera feed, permission handling, visual input | T001 |
| **T003** | **Vision Classification Baseline (Banknotes)** | `Complete` | Built-in Vision request on structured banknotes | T002 |
| **T004** | **Multimodal Understanding Baseline** | `Complete` | Compare Vision+OCR vs Multimodal contextual reasoning | T003 |
| **T005** | **Spoken Accessibility Output (Voice/Audio)** | `Planned` | Speech synthesis / accessible readout of results | T004 |
| **T006** | **Vision Exploration on Local Spices** | `Planned` | Test Vision & Multimodal limits on ambiguous spices | T004 |
| **T007** | **Real-World Input & Uncertainty Handling** | `Planned` | Lighting/blur tests, confidence thresholds, fallback states | T006 |
| **T008** | **Create ML Feasibility & Evaluation** | `Planned` | Evaluate custom model need vs built-in, prepare final prototype | T007 |

---

## Status Legend
- **Planned / Not Started**: Identified as a possible future step (lightweight outline only).
- **In Progress**: Currently being designed, implemented, or tested.
- **Complete**: Successfully built, tested, and documented.
- **Blocked**: Waiting on a technical/research dependency.
- **Cancelled**: Abandoned because findings showed it was no longer necessary (rationale recorded).

---

## Change Log
- **2026-08-26**: Initialized roadmap; T001 completed.
- **2026-08-27**: T002 completed and verified on device/simulator.
- **2026-08-27**: T003 completed; baseline Vision + OCR documented.
- **2026-08-27**: T004 completed; multimodal in-app proof of concept, prompt generalization, and empirical benchmarks verified on physical iPhone.
