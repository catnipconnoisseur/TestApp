# T009 — Scene-Anchored Conversational Memory

**Status:** Complete  
**Date:** 2026-09-02  
**Focus:** Visual Scene Anchoring, Multi-Turn Dialog Reasoning, Anaphora/Pronoun Resolution, Temporal Divergence Debouncing, and Local FeaturePrint Evaluation

---

## 1. Executive Summary

Prior to T009, TestApp operated primarily as a single-turn visual question-answering tool. While the previous answer was persisted on-screen (T007.3), asking a follow-up question (*"What is it used for?"*, *"What color is it?"*, *"Read the ingredients"*) lacked conversational memory, causing the AI to lose context or require the user to repeat the full object name.

**T009 introduces Scene-Anchored Conversational Memory**, transforming TestApp into a true conversational visual assistant:
- **Point → Ask → Understand → Follow Up:** Multi-turn conversational threading anchored to physical scene stability.
- **Zero Cloud Streaming Overhead:** Continuous scene tracking is performed **100% on-device** via Apple Vision `VNFeaturePrintObservation` embeddings and OCR text matching. Gemini is only queried when the user explicitly speaks a question.
- **Temporal Debouncing:** Hand tremors, minor perspective shifts, micro-rotations, and brief partial occlusions are smoothed with a $\ge 0.40$s temporal debounce, preventing premature context wipes.
- **Scene Divergence Reset:** When sustained visual divergence ($\ge 0.50$) is confirmed, the conversation context cleanly resets for the new physical object while preserving the visual on-screen answer card for accessibility.

---

## 2. Core Architecture & Data Flow

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CAMERA & VISION LAYER                              │
│  • Continuous Video Frame Stream (AVFoundation)                             │
│  • Apple Vision VNGenerateImageFeaturePrintRequest & OCR                    │
│  • Local Divergence Tracker: Computes cosine distance vs Anchor Scene       │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │
                    ┌──────────────────┴──────────────────┐
                    │ Divergence < 0.50 (Same Scene)      │ Divergence >= 0.50 for >= 0.40s
                    ▼                                     ▼
┌──────────────────────────────────────┐  ┌───────────────────────────────────┐
│     ACTIVE CONVERSATION THREAD       │  │       SCENE CHANGE CONFIRMED      │
│  • Scene Anchor Reference            │  │  • Active Thread Context Cleared  │
│  • Turn 1: User Q + Image + AI Ans   │  │  • Stale History Removed          │
│  • Turn 2: User Follow-up + AI Ans   │  │  • Persistent Answer Remains Intact│
│  • Turn N: Progressive follow-ups    │  │  • Next Question Starts Turn 1    │
└──────────────────┬───────────────────┘  └───────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       GEMINI MULTI-TURN REST PAYLOAD                        │
│  contents: [                                                                │
│    { role: "user", parts: [ { text: "What is this?" } ] },                  │
│    { role: "model", parts: [ { text: "HEADLINE: Galangal..." } ] },         │
│    { role: "user", parts: [ { text: "What is it used for?" }, ImagePart ] } │
│  ]                                                                          │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 3. Data Models (`ConversationMemory.swift`)

### `SceneStabilityConfiguration`
Consolidates empirical constants governing visual stability and context lifetime:
```swift
struct SceneStabilityConfiguration: Sendable {
    static let divergenceThreshold: Float = 0.50
    static let confirmationDuration: TimeInterval = 0.40
    static let threadInactivityTimeout: TimeInterval = 300.0 // 5 minutes
    static let featurePrintDistanceThreshold: Float = 0.45
}
```

### `ConversationTurn`
Represents an individual question-and-answer exchange:
- `id: UUID`
- `timestamp: Date`
- `question: String`
- `answer: InterpretationResult`
- `rawAIResponse: String`

### `SceneConversationThread`
Represents an active multi-turn thread anchored to a physical scene:
- `id: UUID`
- `anchorScene: AnalyzedSceneReference`
- `turns: [ConversationTurn]`
- `createdAt: Date`
- `lastActiveAt: Date`
- `appendTurn(_:)`
- `isExpired(timeout:) -> Bool`

---

## 4. Multi-Turn Multimodal Reasoning (`MultimodalService.swift`)

Gemini 2.5 Flash request payloads are formatted as an alternating sequence of `user` and `model` content blocks:
1. **Turn 1 (Single Turn):**
   - User turn: Initial prompt (`buildVoiceQuestionPrompt`) + JPEG snapshot base64 inline data.
2. **Follow-Up Turns (Multi-Turn):**
   - History turns: Reconstructed with past user questions and past model responses (`rawAIResponse`).
   - Active turn: Follow-up prompt (`buildFollowUpVoicePrompt`) + active frame snapshot.
3. **Language & Output Contract:**
   - Strict plain-text `HEADLINE:` and `DESCRIPTION:` contract maintained on all turns.
   - Locale directives (English `en-US` or Indonesian `id-ID`) strictly enforced across all follow-up turns.

---

## 5. Local Scene Tracking & Debouncing (`CameraView.swift`)

- `handleIncomingVisionFrame(_:)`:
  - When an active thread exists, calculates divergence score against `thread.anchorScene`.
  - If divergence $\ge 0.50$, begins candidate divergence timer (`sceneDivergenceStartTime`).
  - If sustained for $\ge 0.40$s, confirms scene change and sets `activeConversationThread = nil`.
  - If divergence falls back $< 0.50$ within $0.40$s, candidate timer resets (debounced).
- `submitQuestion(_:)`:
  - Checks if `activeConversationThread` exists and is unexpired.
  - Submits multi-turn history to `MultimodalService`.
  - Appends newly synthesized answer to thread on success.

---

## 6. Empirical Threshold Validation

| Parameter | Hypothesized | Validated Value | Behavioral Observation |
|---|---|---|---|
| **Divergence Threshold** | `0.50` | `0.50` | Reliably distinguishes perspective changes on the same object from pointing at a different item. |
| **Confirmation Duration** | `0.35s` | `0.40s` | $0.40$s prevents accidental thread resets during fast pan movements while remaining responsive when intentionally switching objects. |
| **FeaturePrint Distance** | `0.40` | `0.45` | Tolerates natural ambient light and shadow shifts without triggering false scene changes. |
| **Inactivity Expiration** | N/A | `300.0s` (5m) | Gracefully cleans up old thread memory when device is idle. |

---

## 7. Behavioral Test Matrix & Verification

| Test Case | Scenario | Result |
|---|---|---|
| **Test A: Same Scene Multi-Turn** | *"What is this?"* → *"What is it used for?"* → *"What color is it?"* | ✅ Gemini resolves "it" seamlessly; responses remain concise. |
| **Test B: Same Object, Camera Shift** | Move phone closer, rotate angle, change perspective | ✅ Active thread continues; no premature reset. |
| **Test C: Temporary Occlusion** | Cover camera lens briefly (< 0.4s) and return to object | ✅ Debounce prevents reset; conversation continues. |
| **Test D: New Object Transition** | Point camera at new object for > 0.4s and ask question | ✅ Scene reset confirmed; new thread created as Turn 1. |
| **Test E: Rapid Movement** | Fast pan between objects | ✅ No race conditions or rapid toggling. |
| **Test F: Ambiguous Movement** | Partial tilt away and back within 0.3s | ✅ Context preserved without flapping. |
| **Test G: Payload Integrity** | Inspect request construction | ✅ Alternating `user`/`model` sequence verified. |
| **Test H: Bilingual Consistency** | Follow-up questions in Indonesian mode | ✅ 100% natural Indonesian output across all turns. |
| **Test I: Regression Suite** | Camera, OCR, Speech, Action Button, Persistent Answer | ✅ Zero regressions. |

---

## 8. Artifacts & Code Changes

- **New:**
  - `Features/Multimodal/ConversationMemory.swift`
- **Updated:**
  - `Features/Camera/CameraView.swift`
  - `Features/Interpretation/InterpretationService.swift`
  - `Features/Multimodal/MultimodalService.swift`
  - `docs/DECISIONS.md` (D017)
  - `docs/AI-BEHAVIOR.md`
  - `docs/TESTING.md`
  - `docs/PROGRESS.md`
  - `docs/STRUCTURE.md`
  - `Tickets/ROADMAP.md`
