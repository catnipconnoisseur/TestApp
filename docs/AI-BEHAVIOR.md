# TestApp — AI Behavior & Prompt Engineering

> Last updated: 2026-09-02

---

## AI Architecture Overview

```text
Camera Frame (JPEG, ≤1280px)
    ↓
On-Device Vision (VisionService)
    ├── VNClassifyImageRequest → broad category hints
    ├── VNRecognizeTextRequest → OCR text (id-ID, en-US)
    └── VNGenerateImageFeaturePrintRequest → visual fingerprint
    ↓
InterpretationService
    ├── Dwell/stability evaluation
    ├── Multi-signal currency synthesis
    └── Scene divergence detection
    ↓
MultimodalService (Gemini 2.5 Flash)
    ├── Default analysis prompt (auto-triggered on stable scene)
    └── Voice question prompt (user-initiated via speech)
    ↓
Structured Response (HEADLINE + DESCRIPTION)
    ↓
InterpretationService.interpret()
    ├── Currency context → denomination validation
    ├── Conflict detection → cautionary note
    └── General identification → confidence assessment
    ↓
AccessibilityVoiceService.speak()
    ├── VoiceOver → announcement with language attributes
    └── No VoiceOver → AVSpeechSynthesizer
```

---

## Gemini Model

- **Model**: `gemini-2.5-flash`
- **Endpoint**: `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent`
- **Timeout**: 15 seconds
- **Input**: Single JPEG frame (base64 encoded) + text prompt
- **API Key**: Resolved via `MultimodalConfig` chain: `Secrets.swift` → `UserDefaults` → `Info.plist`

---

## Prompt Builders

### 1. Default Analysis Prompt (`buildDefaultAnalysisPrompt`)
Used for automatic scene identification when a stable visual candidate is detected.

**Inputs:**
- `onDeviceHints: [String]` — OCR text, classification labels from Vision
- `locale: Locale` — determines language directive

**Structure:**
```
Role: Visual accessibility assistant
[ON-DEVICE SENSOR OBSERVATIONS]
Plain text only — no Markdown
[LANGUAGE DIRECTIVE]
[PHYSICAL DEFORMATION & CURRENCY RULES]
[OUTPUT CONTRACT: HEADLINE + DESCRIPTION]
```

### 2. Voice Question Prompt (`buildVoiceQuestionPrompt`)
Used when the user speaks a specific question via hold-to-talk.

**Inputs:**
- `userQuestion: String` — transcribed speech
- `previousContext: String?` — the last identified object/answer (for pronoun resolution)
- `onDeviceHints: [String]` — OCR text, classification labels from Vision
- `locale: Locale` — determines language directive

**Structure:**
```
Role: Visual accessibility assistant answering a specific question
[ACTIVE SCENE CONTEXT — previous identification for "it"/"this" resolution]
[ON-DEVICE SENSOR OBSERVATIONS]
USER'S QUESTION: "[question]"
[LANGUAGE DIRECTIVE]
[PROGRESSIVE DISCLOSURE & REASONING RULES]
[OUTPUT CONTRACT: HEADLINE + DESCRIPTION]
```

---

## Language Directive System

The language directive is injected into every prompt based on `SpeechService.selectedLocale`:

### English (default)
```
LANGUAGE DIRECTIVE:
- The user's active application language is ENGLISH.
- You MUST generate your entire response in natural English.
```

### Indonesian
```
LANGUAGE DIRECTIVE (STRICT MANDATORY REQUIREMENT):
- The user's active application language is BAHASA INDONESIA.
- You MUST generate your ENTIRE response strictly in natural, fluent Bahasa Indonesia.
- NEVER respond in English, even if the user's question was phrased in English.
- Translate any necessary visual descriptions naturally into Indonesian.
```

The Indonesian directive is intentionally more forceful because Gemini defaults to English without strong instruction.

---

## Output Contract

Every Gemini response must follow:
```
HEADLINE: [1-4 word direct answer]
DESCRIPTION: [1-3 clear sentences answering the question]
```

### Parsing
`InterpretationService.parseStructuredMultimodalText()` extracts HEADLINE and DESCRIPTION from the raw response. If the markers are missing, the full text becomes the description with a generic headline.

### Strict Rules
- **Plain text only.** No Markdown syntax (no `**bold**`, no `#headers`, no `- bullets`).
- **No empty placeholders** like `****`.
- **No robotic filler phrases** ("Based on my analysis...", "I can see that...").
- **Natural human phrasing** — "This is turmeric" not "The object in the image appears to be..."

---

## Progressive Disclosure Rules

The AI follows **intent-controlled information scope**:

| User Intent | AI Behavior |
|-------------|-------------|
| "What is this?" | Concise name + at most one short functional note |
| "What color is it?" | State the colors directly, nothing else |
| "What does it look like?" | Physical form, material, key visible features |
| "What's written on it?" | Read relevant visible text directly |
| "Where is the button?" | Clear relative positions (top-right, bottom-left) |
| "Describe everything you see" | **Exception**: Full visual overview (only when explicitly requested) |
| Unanswerable question | Clearly state the information cannot be determined |

**Core rule:** Do NOT volunteer unsolicited visual details unless specifically asked or essential for safety.

---

## Currency Recognition Behavior

### Indonesian Rupiah Multi-Signal Synthesis

The AI is instructed to synthesize all visible cues:

| Signal | Weight | Example |
|--------|--------|---------|
| Printed numerals | High | "100000", "50000" |
| Dominant color | Medium | Red = Rp100k, Blue = Rp50k, Green = Rp20k |
| National hero portrait | Medium | Soekarno-Hatta = Rp100k, Djuanda = Rp50k |
| "Bank Indonesia" text | Contextual | Confirms currency context |
| Garuda Pancasila emblem | Contextual | Confirms Indonesian origin |

### Deformation Resilience
The prompt explicitly states:
> "Objects may be wrinkled, folded, creased, bent, held at an angle, partially occluded, or under uneven lighting/shadows. Physical deformation does NOT change an object's identity."

### Denomination Validation (On-Device)
`InterpretationService.validRupiahDenominations` contains ~70 text variant mappings:
- Numeric: "100000", "100.000", "100,000"
- Informal: "100k", "100rb", "100 rb"
- Indonesian words: "seratus ribu", "lima puluh ribu"
- National heroes: "soekarno", "djuanda", "ratulangi"

### Uncertain Denomination Handling
If the denomination cannot be determined with confidence:
- Headline: "Indonesian Banknote (Denomination Unclear)" / "Uang Kertas (Pecahan Belum Jelas)"
- Cautionary note: "Try turning or flattening the note under good light."
- Confidence: `.moderate` (not `.strong`)

---

## Conflict Detection

`InterpretationService` detects contradictions between Vision and Multimodal:
- Vision says "machine/computer" + Multimodal says "rhizome/spice" → Conflicting Evidence
- Produces cautionary note: "Conflicting visual indicators detected. Reposition camera and re-analyze."

---

## Error Handling in AI Responses

| HTTP Status | User Message | AI Behavior |
|-------------|-------------|-------------|
| 429 (Rate Limited) | "AI service is temporarily busy. Using on-device vision." | Fall back to on-device results |
| 401/403 (Auth Error) | "Authentication failed. Please verify your API key." | Show error state |
| 5xx (Server Error) | "Remote server error." | Show error state |
| Network failure | "Unable to analyze image due to a network connection error." | Show error state |
| Malformed response | "Unable to parse model response." | Show error state |

---

---

## Scene-Anchored Multi-Turn Conversational Memory (T009)

TestApp maintains contextual memory across follow-up questions while the camera is focused on the same physical scene.

### Conversation Lifecycle
1. **Thread Start (Turn 1):** User asks a question ("What is this?"). A `SceneConversationThread` is initialized, anchored to the current `AnalyzedSceneReference`. Gemini receives Turn 1 prompt + image snapshot.
2. **Follow-Up Turns (Turn 2..N):** While the camera remains on the same scene (FeaturePrint divergence $< 0.50$), follow-up questions ("What is it used for?", "What color is it?", "Read the text") are appended to the active thread. Gemini receives alternating `user` and `model` turns from history plus the new prompt + active frame.
3. **Pronoun / Anaphora Resolution:** The AI resolves references such as "it", "this", "that", "its purpose", or "the ingredients" using prior conversation context, answering directly without re-explaining the object identity from scratch.
4. **Scene Reset:** When sustained visual divergence ($\ge 0.50$ for $\ge 0.40$s) is confirmed, the active conversation thread is destroyed (`activeConversationThread = nil`). The next question becomes Turn 1 of a brand new scene thread.
5. **Inactivity Expiration:** If no questions are asked for 5 minutes (`SceneStabilityConfiguration.threadInactivityTimeout = 300.0`), the thread expires automatically.

### Multi-Turn Language Consistency
The active app locale (`Locale`) is strictly enforced on *every* turn. Even if the user asks a follow-up in English while the app is set to Indonesian, the AI always generates its response in Bahasa Indonesia (and vice versa).

---

## Important: What AI Agents Must NOT Change

1. **Do not remove the LANGUAGE DIRECTIVE** from prompts — the AI will revert to English.
2. **Do not remove PHYSICAL DEFORMATION RESILIENCE** rules — recognition accuracy on wrinkled notes will degrade.
3. **Do not allow Markdown in Gemini responses** — it creates VoiceOver noise.
4. **Do not bypass `InterpretationService` currency validation** — Gemini sometimes hallucinates denominations.
5. **Do not make the AI narrate unsolicited** — the user is in control.
6. **Do not send continuous camera frames to Gemini** — scene tracking is purely local on-device via Apple Vision FeaturePrints.

