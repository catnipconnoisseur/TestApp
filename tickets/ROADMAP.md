# TestApp — Development Roadmap

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
| **T005** | **Interpretation & Decision Layer** | `Complete` | Combine Vision, OCR, and Multimodal evidence into structured result with automatic scene-change detection | T004 |
| **T006** | **Reliability & Real-World Evaluation** | `Complete` | Evaluate pipeline consistency, latency, accuracy, and failure modes across real-world physical conditions | T005 |
| **T007** | **Conversational Multimodal Interaction** | `Complete` | Voice-driven question answering combining camera frames with user speech and persistent answer state | T006 |
| **T008** | **Accessibility Experience & Intelligent Assistance** | `Complete` | UX audit, assistant mental model, automatic vs on-demand matrix, Action Button / Quick Access, and 4-step setup hub | T007 |
| **T009** | **Scene-Anchored Conversational Memory** | `Complete` | Scene-anchored conversational threading, FeaturePrint stability, debounced divergence resets, and multi-turn Gemini reasoning | T008 |
| **T010** | **Create ML Feasibility & Evaluation** | `Planned` | Evaluate custom model need vs built-in, prepare final prototype | T009 |

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
- **2026-08-28**: T005 completed; interpretation & decision layer, multi-signal scene divergence tracking, and clean plain-text output verified on physical iPhone.
- **2026-08-28**: T006 completed; real-world evaluation, request policies, and user-initiated multimodal pipeline verified.
- **2026-08-31**: T007 completed; on-device speech transcription, multimodal voice query, and persistent answer state verified.
- **2026-08-31**: T008 completed; accessibility UX audit, proactive permissions setup hub, Action Button & App Shortcuts integration, and banknote deformation robustness.
- **2026-09-02**: T009 completed; scene-anchored conversational memory, on-device FeaturePrint stability evaluation, temporal divergence debouncing, and multi-turn Gemini reasoning.

