# T010 — Create ML Feasibility & Evaluation

**Status:** Complete  
**Date:** 2026-09-02  
**Focus:** Create ML & Core ML Feasibility, Comparative Capabilities Matrix, Indonesian Rupiah Case Study, Failure Mode Analysis, and Architectural Decision  

---

## 1. Executive Summary

This ticket evaluates whether introducing **Create ML** (training) and a custom on-device **Core ML** model (inference) into TestApp would meaningfully improve the application's visual assistance capabilities compared to the current hybrid pipeline (**Apple Vision OCR/Classification** + **`InterpretationService` multi-signal fusion** + **Gemini 2.5 Flash multimodal reasoning**).

### Primary Findings:
1. **Decision: DEFER custom Core ML model adoption; PRESERVE the current multi-signal hybrid architecture.**
2. **Visual Assistant vs Closed-Set Classifier:** Visually impaired users require open-ended contextual answers (*"What is this?"*, *"Is this bill 50,000 or 100,000?"*, *"What is it used for?"*). A custom Core ML image classifier cannot answer follow-up questions or perform conversational reasoning.
3. **Deformed Banknote Handling:** While on-device Vision OCR struggles on crumpled banknotes, Gemini 2.5 Flash with prompt-level `PHYSICAL DEFORMATION RESILIENCE` successfully recovers denomination identification by synthesizing multi-cue visual evidence (color palette, portrait, emblem, layout).
4. **Dataset & Maintenance Burden:** Training a robust custom model for Indonesian banknotes requires $\ge 4,000$ verified physical images across multiple emission series, heavy wear, varied angles, and lighting conditions. The maintenance cost outweighs the marginal gain over the existing pipeline.

---

## 2. Comparative Matrix

| Evaluation Dimension | Built-in Apple Vision (OCR + Classify) | Custom Create ML / Core ML Model | Cloud Multimodal AI (Gemini 2.5 Flash) | Evidence Category |
| :--- | :--- | :--- | :--- | :--- |
| **Inference Latency** | **15–40 ms** | **20–50 ms** | **1,000–2,500 ms** | **[Measured]** (Vision/Gemini) / **[Estimated]** (Core ML) |
| **Network Dependency** | 100% Offline | 100% Offline | Requires Internet Connection | **[Measured]** |
| **App Bundle Impact** | **0 MB** (iOS System API) | **+12 MB to +35 MB** | **0 MB** (Native REST Client) | **[Measured]** (Vision/Gemini) / **[Estimated]** (Core ML) |
| **Task Flexibility** | Fixed taxonomy + text extraction | Closed-set classes only (e.g. 7 notes) | Open-domain Q&A, instructions, safety | **[Observed]** |
| **Deformed Object Handling** | Poor on crumpled banknotes | Moderate (only if trained on folds) | High (multi-signal visual synthesis) | **[Observed]** |
| **Conversational Follow-up** | None | None | Multi-turn dialog context | **[Measured]** |
| **Training & Data Cost** | **Zero** (Pre-trained by Apple) | **High** ($\ge 4,000$ annotated images) | **Zero** (Foundation Model API) | **[Observed]** |
| **Maintenance Burden** | Minimal | High (re-training on new currency series) | Low (prompt configuration) | **[Observed]** |
| **Privacy Footprint** | 100% On-Device | 100% On-Device | Transient frame sent via HTTPS | **[Measured]** |

---

## 3. Detailed Report

For full architectural breakdown, dataset augmentation plans, accessibility impact, and empirical observations, refer to:
[`docs/T010-CREATEML-FEASIBILITY.md`](file:///Users/tiffanychristabelanggriawan/.gemini/antigravity-ide/scratch/TestApp/docs/T010-CREATEML-FEASIBILITY.md)
