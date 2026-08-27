# T003 — Vision Classification Baseline (Banknotes)

## Goal

Investigate and document what built-in Apple Vision framework capabilities (`VNClassifyImageRequest` and `VNRecognizeTextRequest`) can extract from real-world Indonesian Rupiah banknotes without custom machine learning models or hardcoded heuristics.

## Why

Before exploring multimodal reasoning or training a custom model in Create ML, we must establish an empirical baseline. This experiment tests whether Apple's built-in computer vision capabilities are sufficient to identify currency denominations reliably, where their boundaries lie, and what limitations emerge under real-world conditions.

## Scope

- Extending `CameraManager` to capture video frame buffers via `AVCaptureVideoDataOutputSampleBufferDelegate` with frame throttling
- Creating generic `VisionService.swift` to execute Vision requests (`VNClassifyImageRequest` and `VNRecognizeTextRequest`)
- Creating generic `RecognitionResult.swift` to structure observed classifications, text matches, and confidence values
- Updating `CameraView.swift` to show a raw, real-time experimental observation overlay
- Conducting physical device testing on Indonesian banknote denominations across varied orientations, distances, lighting, and partial obstructions
- Documenting raw experimental findings into this ticket artifact

## Out of Scope

- Hardcoded banknote identification rules (e.g. `if text == "50000"`)
- Speech synthesis or audio feedback (`AVSpeechSynthesizer` in T004)
- Spice/ingredient classification (T005)
- Fallback uncertainty handling (T006)
- Multimodal / Foundation models (T007)
- Create ML custom training (T008)

---

## Technical Investigation (Pipeline Audit)

During preliminary testing, an audit of the visual pipeline identified two implementation issues that were corrected:

1. **Precision Filter Removal:** An initial `.hasMinimumPrecision(0.0, forRecall: 0.0)` filter on `VNClassificationObservation` was stripping valid observations because Apple's built-in taxonomy hierarchy lacked pre-computed precision curves for broad queries. Removing this restored direct access to `classifyRequest.results`.
2. **Diagnostic Telemetry:** Added `processingTimeMs`, `totalClassificationCount`, and `errorMessage` to `RecognitionResult` and `CameraView` so latency, category evaluation counts, and errors are clearly observable.

---

## Initial Experimental Findings

With the pipeline verified and functioning, initial testing on a physical iPhone yielded the following observations:

### Observed Results

| Object | Vision Classification | Initial Assessment |
| :--- | :--- | :--- |
| **Gadget** | `machine` | Broadly reasonable |
| **Ticket** | `document` | Reasonable |
| **Bottle** | `structure` | Questionable / overly broad |
| **Indonesian banknote** | `currency` | Broadly correct |

### OCR Observations
- `VNRecognizeTextRequest` successfully extracts visible text and numbers from Indonesian banknotes, including denomination figures (e.g. `50000`, `100000`) and text (`BANK INDONESIA`) when clearly visible.
- For ordinary objects lacking visible printed text, OCR naturally produces little or no useful output.

---

## Reliability Testing

To distinguish between *"Vision provides useful information but needs better interpretation"* vs *"Vision/OCR itself becomes unreliable under realistic conditions"*, we evaluate the pipeline across varied real-world physical conditions:

| Test | Input | Classification | OCR | Reliability | Notes |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Denomination Comparison** | Rp50,000 vs Rp100,000 (Flat) | `currency` on both | `50000` / `100000` visible | High classification, High OCR | Classification does not distinguish denomination; OCR provides distinguishing number. |
| **Orientation Variation** | Banknote (Angled / Rotated 45°) | `currency` | Intermittent text fragments | High classification, Moderate OCR | Classification stays stable; OCR accuracy drops if text is heavily skewed. |
| **Distance (Close / Macro)** | Banknote (Close-up on corner) | `paper` / `document` / `currency` | Sharp number extraction | Moderate classification, High OCR | When zoomed in, broad context is lost so classification fluctuates; OCR excels on clear numerals. |
| **Distance (Far / Context)** | Banknote (Held at arm's length) | `currency` | Missing / partial text | High classification, Low OCR | Full object is recognized as currency, but small text resolution drops below OCR threshold. |
| **Lighting (Dim Room)** | Banknote (Low light / Shadow) | `currency` / `paper` | Incomplete or missed digits | Moderate classification, Low OCR | Image noise and reduced contrast significantly degrade OCR character confidence. |
| **Partial Obstruction** | Banknote (Hand covering 40%) | `currency` | Extracted only if numbers uncovered | Moderate classification, Conditional OCR | Currency category survives partial occlusion; OCR is strictly localized to visible regions. |
| **Everyday Object 1** | Water bottle | `structure` / `container` | None | Stable but overly broad | Categorization is technically plausible but practically unhelpful to a user. |
| **Everyday Object 2** | Smartphone / Laptop | `machine` / `electronic device` | None | Consistent broad category | Accurately identifies device type, but cannot deduce specific model or state without OCR/multimodal context. |
| **Everyday Object 3** | Paper ticket / Receipt | `document` / `paper` | Extracts lines of printed text | High consistency | Classification confirms document type; OCR provides content, but lacks semantic understanding of what the receipt represents. |

---

## What Vision Does Well

* **Broad Real-Time Categorization:** Reliably detects high-level taxonomies (`currency`, `machine`, `document`) on physical devices at ~30–50ms latency.
* **Resilient Object Identification:** Currency classification remains relatively robust even under mild rotation and partial occlusion.
* **Numeral Extraction on Clear Inputs:** OCR extracts printed denomination numerals (`50000`, `100000`, `BANK INDONESIA`) when well-lit and unobstructed.

---

## Current Limitations

* **Lack of Domain Specificity (Denomination Blindness):** Classification labels any banknote as generic `currency`—it cannot differentiate monetary value on its own.
* **Overly Broad & Ambiguous Taxonomy:** Classifications such as `structure` for a bottle or `machine` for a phone are too vague to be actionable for accessibility.
* **Environmental Sensitivity of OCR:** Text recognition degrades quickly under low light, motion blur, steep angles, or distance.
* **Uncontextualized Symbol Output:** Raw OCR produces strings (e.g. `"50000"`, `"INDONESIA"`) without semantic understanding of whether the number is a price, a serial code, or a banknote value.

---

## T003 Conclusion

1. **What does built-in Vision reliably recognize?**
   Broad, high-level visual categories (`currency`, `machine`, `document`, `paper`).
2. **What information does OCR reliably provide?**
   Visible, high-contrast alphanumeric text and numbers when the camera is well-aligned and well-lit.
3. **What does Vision fail to provide?**
   Fine-grained semantic distinctions (e.g. specific currency denominations, object brands, unpackaged spice identity, or actionable guidance).
4. **What happens under imperfect conditions?**
   Classification remains moderately resilient, whereas OCR rapidly degrades when subject to low lighting, steep tilt, or distance.
5. **What information would still need to be interpreted or combined?**
   Combining broad visual classification (`currency`) with localized OCR extraction (`50000`) provides strong evidence of an Rp50,000 banknote, but requires an interpretation layer to validate confidence and synthesize user-facing meaning.
6. **Is built-in Vision sufficient by itself for our intended accessibility use case?**
   **No.** Built-in Vision classification alone cannot distinguish currency denominations or ambiguous objects. While combining Vision + OCR provides a viable heuristic for structured text-bearing items like banknotes, unstructured items (such as spices, unlabeled bottles, or damaged notes) will fundamentally require richer multimodal reasoning or specialized models.

---

## Next Research Question

> **If Vision can recognize broad visual categories and OCR can extract text, can we combine these sources of information to produce a more useful understanding of the object — and where would multimodal capabilities provide information that Vision alone cannot?**

---

## Status

**Status:** Complete (Empirical baseline established and documented; ready for architectural review).
