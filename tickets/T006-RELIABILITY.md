# T006 — Reliability & Real-World Evaluation

## Goal

Evaluate whether the current visual understanding pipeline (**Vision + OCR + Multimodal AI + Interpretation Layer**) provides sufficiently reliable, consistent, responsive, and trustworthy results across diverse real-world physical conditions for a visually impaired user.

## Primary Research Question

> **"Does the current Vision + OCR + Multimodal + Interpretation pipeline provide sufficiently reliable results across different objects, environments, and capture conditions for an accessibility-oriented use case?"**

---

## 1. System Baseline Architecture Under Evaluation

The evaluation targets the complete, unmodified end-to-end pipeline:

```text
┌─────────────────────────────────────────────────────────────┐
│                    Camera Viewfinder                        │
│             (AVCaptureSession / 30fps feed)                 │
└──────────────────────────────┬──────────────────────────────┘
                               │ Continuous 30fps Frame Delivery
                               ↓
┌─────────────────────────────────────────────────────────────┐
│               VisionService (Fast On-Device)                │
│    - VNClassifyImageRequest   -> [ClassificationItem]       │
│    - VNRecognizeTextRequest   -> [RecognizedTextItem]       │
│    - VNGenerateFeaturePrint   -> [VNFeaturePrintObservation]│
└──────────────────────────────┬──────────────────────────────┘
                               │ RecognitionResult (~30–45ms)
                               ↓
┌─────────────────────────────────────────────────────────────┐
│            Automatic State Machine (CameraView)             │
│  - OBSERVING: continuous on-device scanning                 │
│  - STABILIZING: target dwell accumulation (0.70s threshold) │
│  - ANALYZING: snapshot capture (max 1024px, 0.60 JPEG, ~90KB)│
│  - RESULT_LOCKED: displayed on card; protected from frame   │
│    overwrites                                               │
│  - POSSIBLE_SCENE_CHANGE: multi-signal divergence >= 0.50   │
│  - SCENE_CHANGE_CONFIRMED: divergence sustained for 0.35s   │
└──────────────┬──────────────────────────────┬───────────────┘
               │                              │
  On-Device    │                              │ On-Demand Snapshot Request
  Fallback     ↓                              ↓
┌──────────────────────────────────────┐   ┌──────────────────────────────────┐
│       InterpretationService          │   │        MultimodalService         │
│  (Evidence Fusion & Decision Engine) │   │ (Cloud Visual-Language Reasoning)│
│                                      │   │                                  │
│  - Synthesizes Vision + OCR          │   │ - Model: gemini-2.5-flash        │
│  - Evaluates Evidence Quality        │   │ - Structured plain text contract │
│  - Integrates Multimodal when present│   │ - Timeout: 15.0s                 │
│  - Strips Markdown asterisks/syntax  │   │ - Returns MultimodalResult       │
│  - Emits InterpretationResult        │   └──────────────────┬───────────────┘
└──────────────────────┬───────────────┘                      │
                       │                                      │
                       │◄─────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│                 Accessibility UI (CameraView)               │
│  - Concise 1-4 word Headline (Header trait)                 │
│  - 2-3 sentence Plain-Text Description                      │
│  - Evidence Confidence Badge & Source Indicators            │
│  - Cautionary Warning Box (on uncertainty or conflict)      │
│  - Expandable Developer Telemetry Section (T006 View)       │
└─────────────────────────────────────────────────────────────┘
```

---

## 2. Documented Pipeline Configuration

| Parameter | Value | Functional Role |
| :--- | :--- | :--- |
| **Dwell Stability Requirement** | `0.70s` | Continuous steady visual framing required before triggering cloud snapshot. |
| **Scene-Change Confirmation** | `0.35s` | Duration multi-signal divergence must persist to confirm new target. |
| **Divergence Threshold** | `0.50` | Weighted sum of OCR change (0.5), Classification change (0.3), and Visual Feature Embedding distance (0.5). |
| **Request Cooldown** | `2.0s` | Minimum cooldown between completed AI analyses to prevent network spam. |
| **Snapshot Resolution** | `Max 1024px` | Scaled via CoreImage before JPEG generation. |
| **JPEG Compression** | `0.60` | Produces ~70KB–110KB payload (a 96% reduction vs 12MP uncompressed). |
| **Network Timeout** | `15.0s` | URLSession timeout preventing indefinite in-flight hung states. |
| **Multimodal Model** | `gemini-2.5-flash` | Active Google visual-language model endpoint. |
| **Output Contract** | Strict Plain-Text | Delimited by `HEADLINE:` and `DESCRIPTION:`, stripped of all Markdown syntax. |

---

## 3. Reliability Testing Matrix

> **Note on Evaluation Protocol:** All tests are designed for physical iPhone testing. Observed values must be populated during hands-on execution.

---

### Matrix A: Object Categories & Domain Breadth

| ID | Object | Expected Headline | Primary Visual Clues | Vision Category | OCR Expected | Multimodal Expected | Physical Test Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :---: |
| **A1** | Rp50,000 Banknote | `Rp50,000 Indonesian Banknote` | Blue hue, printed "50000", Bank Indonesia text | `currency` / `paper` | `"50000"`, `"BANK INDONESIA"` | Indonesian Rp50,000 note | `Pending Physical Test` |
| **A2** | Rp100,000 Banknote | `Rp100,000 Indonesian Banknote` | Red hue, printed "100000", portrait | `currency` / `paper` | `"100000"`, `"INDONESIA"` | Indonesian Rp100,000 note | `Pending Physical Test` |
| **A3** | Galangal (Lengkuas) | `Galangal` | Segmented rhizome, reddish-brown skin | `plant` / `structure` | None | Galangal rhizome spice | `Pending Physical Test` |
| **A4** | Turmeric (Kunyit) | `Turmeric` | Deep orange/yellow interior, cylindrical rhizome | `plant` / `food` | None | Turmeric rhizome spice | `Pending Physical Test` |
| **A5** | Ginger (Jahe) | `Ginger` | Tan/beige skin, knobby branching root | `plant` / `produce` | None | Ginger root spice | `Pending Physical Test` |
| **A6** | Shaker Bottle | `Shaker Bottle` | Cylindrical translucent plastic, screw lid, spout | `container` / `bottle` | Label text | Shaker bottle for mixing | `Pending Physical Test` |
| **A7** | Smartphone | `Smartphone` | Rectangular glass face, camera array, metallic frame | `electronic` / `phone` | None | Touchscreen mobile phone | `Pending Physical Test` |
| **A8** | Document / Receipt | `Document with Text` | White paper, structured line text | `document` / `paper` | Printed text lines | Paper receipt or document | `Pending Physical Test` |

---

### Matrix B: Environmental Lighting Variations

| ID | Test Condition | Physical Setup | Hypothesized Impact | Observed Metric | Physical Test Status |
| :--- | :--- | :--- | :--- | :--- | :---: |
| **B1** | Normal Indoor Lighting (~300–500 lux) | Standard room ambient light | Baseline performance; high OCR & Vision accuracy | Pending | `Pending Physical Test` |
| **B2** | Bright / Direct Light (>1000 lux) | Sunlight / direct desk lamp | Specular glare on glossy bottles/banknotes may wash out OCR | Pending | `Pending Physical Test` |
| **B3** | Dim / Low Light (<50 lux) | Shaded room / evening ambient | Sensor noise; slower autofocus; model may report low confidence | Pending | `Pending Physical Test` |
| **B4** | Strong Backlighting | Light source behind object | Silhouette effect; surface texture obscured; caution expected | Pending | `Pending Physical Test` |
| **B5** | Harsh Cast Shadows | Partial direct shadow across half of object | OCR may lose characters in shadow; multimodal should infer shape | Pending | `Pending Physical Test` |

---

### Matrix C: Distance & Framing Variations

| ID | Distance Range | Physical Setup | Evaluation Focus | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **C1** | Macro / Close (<10 cm) | Object fills >90% of viewfinder | Macro focus blur; partial text visibility | `Pending Physical Test` |
| **C2** | Handheld Optimal (15–25 cm) | Full object centered in frame | Standard optimal capture baseline | `Pending Physical Test` |
| **C3** | Arm's Length (50–70 cm) | Object occupies ~30% of frame | Small text resolution loss; background clutter impact | `Pending Physical Test` |
| **C4** | Far Range (>1.2 m) | Object occupies <10% of frame | System should identify broad scene or note insufficient detail | `Pending Physical Test` |

---

### Matrix D: Angle & Geometric Orientation

| ID | Angle / Orientation | Physical Setup | Evaluation Focus | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **D1** | Frontal / Perpendicular (0°) | Flat directly facing lens | Optimal baseline | `Pending Physical Test` |
| **D2** | Moderate Oblique (~30° tilt) | Angled perspective | Perspective distortion tolerance | `Pending Physical Test` |
| **D3** | Steep Oblique (~60° tilt) | Severe perspective foreshortening | Text readability & 3D shape reasoning | `Pending Physical Test` |
| **D4** | 90° / 180° Inverted Rotation | Upside-down or sideways object | Rotation invariance of OCR & Multimodal | `Pending Physical Test` |

---

### Matrix E: Partial Occlusion & Cropping

| ID | Occlusion Degree | Physical Setup | Expected Behavior | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **E1** | ~25% Occluded | Thumb/finger covering corner | Full identification preserved | `Pending Physical Test` |
| **E2** | ~50% Occluded | Half of object hidden behind book/hand | Multimodal infers category; warns of partial visibility | `Pending Physical Test` |
| **E3** | Denomination Covered | Banknote with "50000" numeral covered | Identifies "Indonesian Banknote", notes denomination unclear | `Pending Physical Test` |

---

### Matrix F: Scene Transitions & Automatic Re-Analysis

| ID | Transition Sequence | Test Protocol | Key Verification Criterion | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **F1** | Bottle $\to$ Banknote | Point at bottle $\to$ lock result $\to$ pan to banknote | Scene divergence triggered via OCR/classification shift; new result appears | `Pending Physical Test` |
| **F2** | Bottle $\to$ Galangal | Point at bottle $\to$ lock result $\to$ pan to spice (both `structure`) | Feature embedding distance (>0.40) triggers scene change despite identical label | `Pending Physical Test` |
| **F3** | Banknote $\to$ Empty Table | Point at note $\to$ pan to plain desk surface | Emptied scene resets state machine to `OBSERVING` within 0.6s | `Pending Physical Test` |
| **F4** | Target A $\to$ Target B $\to$ Target A | Bottle $\to$ Galangal $\to$ Bottle | Returning to original item successfully triggers a fresh re-analysis | `Pending Physical Test` |

---

### Matrix G: Camera Dynamics & Motion Tolerance

| ID | Motion Type | Physical Action | Expected State Machine Behavior | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **G1** | Natural Hand Tremor | Hold phone with one hand naturally on same object | Stays in `RESULT_LOCKED`; zero re-analysis spam | `Pending Physical Test` |
| **G2** | Minor Framing Adjustment | Nudge camera 2–3 cm while framing object | Stays locked; divergence remains < 0.30 | `Pending Physical Test` |
| **G3** | Rapid Continuous Panning | Sweep camera quickly across room | Remains in `OBSERVING` / `STABILIZING`; no motion blur snapshots | `Pending Physical Test` |

---

### Matrix H: Semantic Repeatability (5 Consecutive Runs per Object)

| Run # | Object | Headline Returned | Key Description Summary | Latency (ms) | Confidence | Semantic Match? |
| :---: | :--- | :--- | :--- | :---: | :---: | :---: |
| **H1** | Rp50,000 Banknote | Pending | Pending | Pending | Pending | `Pending Physical Test` |
| **H2** | Rp50,000 Banknote | Pending | Pending | Pending | Pending | `Pending Physical Test` |
| **H3** | Rp50,000 Banknote | Pending | Pending | Pending | Pending | `Pending Physical Test` |
| **H4** | Galangal | Pending | Pending | Pending | Pending | `Pending Physical Test` |
| **H5** | Galangal | Pending | Pending | Pending | Pending | `Pending Physical Test` |

---

### Matrix I: Ambiguity & Honest Uncertainty Communication

| ID | Ambiguous Scenario | Physical Setup | Desired Accessibility Outcome | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **I1** | Galangal vs Ginger | Close-up of peeled/cut root | States likely identification with explicit note on plausible alternative | `Pending Physical Test` |
| **I2** | Crumpled / Folded Banknote | Note folded in quarters | Identifies Indonesian currency; cautionary note if numeral hidden | `Pending Physical Test` |
| **I3** | Heavily Cluttered Background | Spice placed on printed newspaper | Isolates foreground target without confusing background text | `Pending Physical Test` |

---

### Matrix J: Fault Injection & Resilience Testing

| ID | Fault Injected | Simulation Method | Expected System Response | Physical Test Status |
| :--- | :--- | :--- | :--- | :---: |
| **J1** | Network Disconnected | Enable Airplane Mode | UI shows clear network warning; falls back gracefully to on-device Vision/OCR | `Pending Physical Test` |
| **J2** | API Key Cleared | Clear key in Settings sheet | Card indicates API Key required; continuous local Vision continues working | `Pending Physical Test` |
| **J3** | Request Timeout / Server Lag | Latency > 15.0s | URLSession cancels request cleanly; resets state to `OBSERVING` without crash | `Pending Physical Test` |

---

## 4. Latency & Performance Breakdown

| Measurement Stage | Description | Target Budget | Measured Range (Physical iPhone) |
| :--- | :--- | :--- | :--- |
| **1. Vision & OCR Pass** | Time to process continuous pixel buffer on device | 25–50ms | `Pending Physical Test` |
| **2. Dwell Window** | Time user must hold camera steady | 700ms | **Fixed: 700ms** |
| **3. Snapshot & Downscale** | CoreImage scale to 1024px + JPEG compression | 10–25ms | `Pending Physical Test` |
| **4. Cloud Network Roundtrip** | Payload transmission + Gemini 2.5 Flash inference | 300–700ms | `Pending Physical Test` |
| **5. Synthesis & UI Render** | Interpretation parsing + MainActor SwiftUI update | <5ms | `Pending Physical Test` |
| **Total Perceived Turnaround** | **Camera stops moving $\to$ Answer visible on card** | **~1.0s – 1.5s** | `Pending Physical Test` |

---

## 5. Accessibility Evaluation Criteria

1. **Immediate Semantic Clarity:** Does the primary headline instantly convey the single most critical piece of information in 1–4 words?
2. **Actionable Justification:** Does the explanation provide concrete sensory attributes (color, texture, markings, denomination) rather than abstract technical labels?
3. **Transparent Uncertainty:** Does the system honestly say when it cannot distinguish similar items (e.g. galangal vs ginger) or when denomination is hidden?
4. **Zero Manual Friction:** Does the user receive updated analysis seamlessly simply by pointing and holding steady?
5. **Screen Reader Ready:** Are all states, badges, and warnings accessible via VoiceOver semantics?

---

## 6. Interim User-Initiated Multimodal Architecture & Future Voice UX Direction

### 1. Previous Approach & Problems Encountered
* **Automatic Stability Triggering:** The previous iteration attempted to automatically trigger Gemini requests upon detecting a stationary scene ($0.70\text{s}$ dwell) and scene changes.
* **Observed Issues:**
  1. Gemini requests fired without explicit user intent.
  2. State machine complexity escalated with fragile edge cases.
  3. Stationary cameras risked rapid request spam and HTTP 429 rate limits.
  4. The interaction model did not clearly communicate **when** the AI was performing deep cloud reasoning versus continuous on-device scanning.

### 2. Current Architecture: User-Initiated Multimodal Analysis
* **Continuous On-Device Vision + OCR:** Operates automatically at 30fps to provide immediate local classifications, detected text, and fast structured interpretations.
* **On-Demand Gemini Multimodal AI:** Dispatched **only when the user explicitly taps the "Analyze" button**.
  - Temporarily disables button and displays `"Analyzing..."` with a spinner.
  - Captures a single 1024px JPEG snapshot (~90KB).
  - Emits clean, two-part plain-text response (`HEADLINE:` & `DESCRIPTION:`).
  - Rate limits (HTTP 429) or network errors present a helpful local fallback without automatic retries.
* **Zero Automatic Cloud Triggers:** Dwell timers, frame counts, and scene transitions update only local Vision telemetry—never triggering cloud API requests.

### 3. Future Direction: Voice-Driven Conversational Visual Understanding
The `Analyze` button serves as an intentional interim trigger until speech recognition is introduced. The architecture maintains a decoupled `MultimodalService.analyzeImage(jpegData:prompt:apiKey:)` engine to support the upcoming conversational model:
```text
User points camera at scene
            ↓
Continuous Vision + OCR scanning
            ↓
User speaks a context-specific question:
"What is this?" / "What does this text say?" / "How much money is this?"
            ↓
Multimodal AI receives:
- Current downscaled snapshot
- User's specific question as the prompt
            ↓
Voice synthesis speaks conversational, context-aware answer
```

---

## 7. Current Status

* **Status:** **In Progress (User-Initiated Multimodal Architecture implemented and compiled; ready for physical iPhone verification).**
