# BantuLihat / TestApp — Development Roadmap

This file tracks the evolving high-level roadmap for the 10-day Act Phase challenge.

> **Principle:** Maintain approximately 6–10 high-level tickets as lightweight intentions. Only the active ticket is designed and implemented in detail. Findings from tests actively update and refine upcoming tickets.

---

## Roadmap Overview

| Ticket | Name | Status | Purpose / Focus | Dependencies |
| :--- | :--- | :--- | :--- | :--- |
| **T001** | **Baseline App Structure** | `Complete` | SwiftUI app lifecycle, baseline UI, VoiceOver navigation | None |
| **T002** | **Live Camera Preview** | `Complete` | AVFoundation camera feed, permission handling, visual input | T001 |
| **T003** | **Vision Classification Baseline (Banknotes)** | `Planned` | Built-in Vision request on structured banknotes | T002 |
| **T004** | **Spoken Accessibility Output (Voice/Audio)** | `Planned` | Speech synthesis / accessible readout of results | T003 |
| **T005** | **Vision Exploration on Local Spices** | `Planned` | Test Vision limits on ambiguous items (turmeric, etc.) | T003 |
| **T006** | **Real-World Input & Uncertainty Handling** | `Planned` | Lighting/blur tests, confidence thresholds, fallback states | T005 |
| **T007** | **Multimodal Contextual Interpretation** | `Planned` | Broader context reasoning for ambiguous visual input | T005, T006 |
| **T008** | **Create ML Feasibility & Evaluation** | `Planned` | Evaluate custom model need vs built-in, prepare final prototype | T007 |

---

## Status Legend
- **Planned**: Identified as a possible future step (lightweight outline only).
- **In Progress**: Currently being designed, implemented, or tested.
- **Complete**: Successfully built, tested, and documented.
- **Blocked**: Waiting on a technical/research dependency.
- **Cancelled**: Abandoned because findings showed it was no longer necessary (rationale recorded).

---

## Change Log
- **2026-08-26**: Initialized roadmap; T001 completed.
