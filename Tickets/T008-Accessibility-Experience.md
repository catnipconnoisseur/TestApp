# T008 — Accessibility Experience & Intelligent Assistance: Research, Audit & Product Direction

**Status:** In Progress  
**Date:** 2026-08-31  
**Focus:** Accessibility UX Audit, Visual Assistant Identity, Conversational Mental Models, and System Architecture

---

## 1. Executive Summary

TestApp has evolved rapidly from a camera preview with Vision/OCR classification into a functioning prototype with continuous on-device evidence fusion and user-initiated conversational multimodal analysis powered by Gemini 2.5 Flash.

T008 evaluates the fundamental product thesis: **Is this an object classifier, or a visual accessibility assistant?**

### Key Conclusions:
1. **Classifier vs Assistant:** The app must be an **intelligent visual assistant**, not a classifier. For a visually impaired user, knowing the taxonomic category of an object ("Bottle", "Paper", "Machine") is rarely the end goal. The user's actual need is contextual, functional, and actionable ("Is this shampoo or conditioner?", "What is the expiration date?", "How much is this note?").
2. **Camera as Visual Context:** The camera provides the AI with "eyes" (visual grounding), while the conversational voice interface gives the user agency to query that grounding on their own terms.
3. **Mental Model:** The **POINT → ASK → UNDERSTAND** mental model is sound and accessible, provided it is supported by low-friction tactile interactions, predictable non-visual feedback (audio/haptics), and conversational memory anchored to the physical scene.
4. **Information Architecture (Proactive vs On-Demand):** Critical safety warnings and verified high-value tactile anchors (such as immediate currency denomination) can be highlighted immediately, but deep descriptions, instructions, and secondary details must remain **user-requested** to avoid cognitive overload and auditory fatigue ("talking over the user").
5. **Speech Coexistence:** VoiceOver and dedicated AI speech (TTS) must not conflict. The app should coordinate audio ducking and speech channels so that VoiceOver users and non-VoiceOver users have an equally seamless experience.

---

## 2. Product-Direction Assessment: Object Identifier vs Visual Assistant

```text
                  OLD PARADIGM: OBJECT IDENTIFIER
  Camera Frame ──► Computer Vision ──► Label: "Bottle" (Low utility)

                  NEW PARADIGM: VISUAL ASSISTANT
  Camera Frame ──┐
                 ├──► Contextual Visual Grounding ──► Direct, Actionable Answer
  User Question ─┘    (Multimodal Reasoning)           to Specific Need
```

### The Limits of "Object Identification"
* Traditional accessibility tools often present a rapid stream of labels: *"chair"*, *"cup"*, *"laptop"*, *"text"*.
* For a visually impaired user, identifying an object's category is often trivial through physical touch (the user already knows they are holding a cylinder or a plastic bottle).
* What touch **cannot** convey is optical information: text, color, denomination, expiration date, cooking instructions, warnings, and visual state (e.g. "Is the stove burner on?", "Is this milk expired?").
* Treating the app as an "Object Identifier" reduces its value to basic taxonomy and forces the AI into generic descriptions that waste time and battery.

### The Power of "Visual Assistance"
* When framed as a **Visual Assistant**:
  * The camera captures the visual environment without judgment.
  * The user directs attention with natural questions: *"What flavor is this?"*, *"Is this bill 50,000 or 100,000?"*, *"Where is the barcode?"*.
  * The AI acts as a patient, observant visual companion that answers directly, concisely, and truthfully without unsolicited monologues.

**Decision:** We firmly establish TestApp as an **Accessibility Visual Assistant**. On-device Vision and OCR serve as lightweight, local grounding layers, while multimodal conversational reasoning serves as the primary intelligence engine.

---

## 3. Existing Accessibility Experiences & Industry Benchmarking

| Product | Strengths | Friction Points / Failures | Key Takeaway for TestApp |
| :--- | :--- | :--- | :--- |
| **Be My AI / Be My Eyes** | Conversational follow-ups; detailed scene descriptions; high accuracy on complex scenes. | Photo-taking required; slow turnarounds (4–8s); verbose initial descriptions that user must listen through before asking specific questions. | Support direct question asking at the moment of capture without forcing a long initial description monologue. |
| **Google Lookout** | Fast dedicated modes (Currency, Food Labels, Text/Documents, Explore); instant local audio feedback. | Rigid modal switching (user must switch between 'Currency' and 'Food' tabs); cannot answer ad-hoc questions outside mode presets. | Avoid mode fatigue. Provide a single open viewport where any question can be asked naturally. |
| **Seeing AI (Microsoft)** | Versatile channel-based architecture; instant barcode & short-text reading; spatial audio tones. | Channel switching friction; disconnected AI chat mode; audio can become chaotic and chatty. | Use on-device OCR/Vision for background grounding, but channel all spoken interaction through one unified voice gesture. |
| **Apple Detection Mode / Magnifier** | Deep OS integration; door detection, people detection, point-and-speak text recognition; high haptic fidelity. | Focused on navigation/geometry rather than semantic visual reasoning; cannot explain unknown objects or complex labels. | Prioritize Apple-standard haptics, low-latency push-to-talk, and VoiceOver-first design tokens. |

---

## 4. Accessibility-First UX Audit of the Current Implementation

Walking through the complete app experience strictly from the perspective of a user who is blind or has low vision:

### A. First Launch & Onboarding (WelcomeView)
* **What works well:**
  * Clean 3-step interactive progression without scrolling (`introduction → voiceTutorial → ready`).
  * Live speech practice screen allows the user to test the hold-to-speak gesture with haptic confirmation without cloud API dependencies.
  * Clear fallback options ("Skip voice tutorial") if microphone permissions are denied.
* **Audit Findings & Friction Points:**
  * VoiceOver currently announces the button traits, but if speech recognition takes a moment to initialize on older devices, VoiceOver focus can jitter between the interaction card and the skip button.
  * The transition from onboarding to CameraView does not announce an explicit arrival landmark (e.g. `"Camera ready. Hold the bottom of the screen to ask a question."`).

### B. Camera Viewport & Idle State
* **What works well:**
  * Large bottom interaction area (~120pt height, full width) is very easy to target by feel alone (sliding up from the home indicator or tapping the lower third of the screen).
  * Root navigation structure eliminates unnecessary tabs and nested views.
* **Audit Findings & Friction Points:**
  * When opening the camera, a totally blind user has no spatial feedback on whether the object is in frame, well-lit, or in focus before asking a question.
  * When no AI answer exists yet, the local Vision result ("Object", "Machine") can be noisy if read by VoiceOver prematurely.

### C. Asking a Question (Hold-to-Talk)
* **What works well:**
  * Immediate camera snapshot capture upon touch-down guarantees that the frame matches what the phone was aimed at when the user started speaking.
  * Clear haptic click on press (`medium`) and release (`light`).
  * Empty speech is caught cleanly without burning Gemini API requests or presenting error codes.
* **Audit Findings & Friction Points:**
  * If a user hesitates for 1–2 seconds before speaking while holding the button, the speech recognizer works fine, but there is no audio "listening" earcon/tone for non-VoiceOver blind users.
  * If a user releases the button too quickly (< 0.2s), it triggers the empty-speech fallback. A minimal hold threshold (e.g. 0.3s) with clear feedback is needed.

### D. Result Delivery & Persistence (T007.3)
* **What works well:**
  * Answer persistence works: moving the phone or setting it down does not erase the answer.
  * Plain text HEADLINE + DESCRIPTION format eliminates Markdown clutter (`**`, `###`, `*`).
  * Non-destructive error handling preserves the previous answer if a new query encounters a network glitch or rate limit.
* **Audit Findings & Friction Points:**
  * VoiceOver announces the answer once via `UIAccessibility.post(notification: .announcement)`, but if the user misses it or VoiceOver gets interrupted by an incoming system notification, there is no one-tap "Repeat Answer" gesture.

---

## 5. Mental Model Evaluation: POINT → ASK → UNDERSTAND

```text
               ┌───────────────┐
               │     POINT     │  Aim camera toward physical object
               └───────┬───────┘
                       │
                       ▼
               ┌───────────────┐
               │      ASK      │  Hold bottom of screen & speak naturally
               └───────┬───────┘
                       │
                       ▼
               ┌───────────────┐
               │  UNDERSTAND   │  Receive direct, actionable audio answer
               └───────┬───────┘
                       │
                       ▼
               ┌───────────────┐
               │   ASK AGAIN   │  Follow-up in the same conversational scene
               └───────────────┘
```

### Why "POINT → ASK → UNDERSTAND" is the Right Model:
1. **Low Cognitive Load:** It mirrors natural human assistance: you point to something in the room and ask a sighted companion a question.
2. **User Agency:** The user initiates communication. The app never lectures or speaks unprompted.
3. **Forgiving:** The user does not need to frame the shot perfectly or read tiny preview text. The multimodal model compensates for angle, partial occlusions, and background clutter.

---

## 6. Automatic vs User-Requested Information Matrix

To prevent auditory fatigue while ensuring safety and convenience, we define strict rules for what information is proactively highlighted vs on-demand:

| Information Category | System Behavior | Spoken by VoiceOver Automatically? | Rationale |
| :--- | :--- | :--- | :--- |
| **Direct Answer to User Question** | **Immediate Response** | **Yes (Once)** | This is the explicit user goal. |
| **Critical Hazard / Warning** (e.g. hot surface, bleach, sharp edge) | **Proactive Caution** | **Yes (Immediate Alert)** | Safety-critical information overrides conversational silence. |
| **Verified Banknote Denomination** | **Instant Local Anchor** | **Optional / Subtle Tone** | Fast verification without cloud latency, but should not repeat continuously. |
| **General Object Taxonomy** ("Container", "Electronics") | **Visual Card Only** | **No** | Generic labels add cognitive noise without answering specific needs. |
| **Full OCR Text Stream** | **Visual Card Only** | **No** | Reading entire pages or label text unprompted causes severe auditory fatigue. |
| **Product Instructions / Ingredients** | **On User Demand Only** | **Only When Asked** | User decides when they need ingredient/usage details. |
| **Color / Visual Aesthetics** | **On User Demand Only** | **Only When Asked** | Color is subjective and should be answered when queried. |
| **Price / Expiration Dates** | **On User Demand Only** | **Only When Asked** | Specific data points best delivered in response to explicit questions. |

---

## 7. Vision vs Gemini Responsibility Model

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                             ON-DEVICE LAYER                                 │
│  • AVFoundation Camera Engine (60 FPS / Low Latency)                        │
│  • Apple Vision Framework (VNClassifyImageRequest, VNRecognizeTextRequest)  │
│  • Visual FeaturePrint Tracking (VNGenerateImageFeaturePrintRequest)        │
│  • On-Device Speech Transcription (SFSpeechRecognizer, onDevice = true)     │
│  • Local Stability & Scene Divergence Engine (< 15ms turnaround)            │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Frame Snapshot + Spoken Question
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            CLOUD REASONING LAYER                            │
│  • Gemini 2.5 Flash Multimodal Endpoint (REST via URLSession)               │
│  • Contextual Visual Understanding & Question Answering                     │
│  • Grounded Semantic Reasoning (Anti-Hallucination & Uncertainty Reporting) │
│  • Plain-Text Structured Extraction (Headline + Description)                │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Layer Separation Rules:
1. **On-Device Vision:** Responsible for real-time camera processing, optical stability detection, scene divergence tracking, on-device OCR caching, and instant tactile feedback. It never makes slow cloud network requests on its own.
2. **Cloud Gemini Multimodal:** Responsible for deep visual reasoning, OCR interpretation (understanding what the text *means*, e.g., finding the expiry date among 50 lines of text), translation, contextual explanation, and answering specific user questions.

---

## 8. Conversational Context Model

### Rule: One Physical Scene = One Conversational Thread
When a user asks about an object, follow-up questions often contain anaphora (*"What is **it** used for?"*, *"How much does **that** cost?"*, *"What color is **it**?"*).

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          CURRENT SCENE THREAD                               │
│                                                                             │
│  [Turn 1] Image 1 (Galangal) + "What is this?"                              │
│           └──► AI: "Galangal. A cooking rhizome with a peppery aroma."     │
│                                                                             │
│  [Turn 2] Image 2 (Same Scene) + "What is it used for?"                     │
│           └──► Context includes Turn 1 ("Galangal")                         │
│           └──► AI: "Cooking. It is used in soups, curries, and pastes."     │
└──────────────────────────────────────┬──────────────────────────────────────┘
                                       │ Physical Scene Divergence (Camera moves to Banknote)
                                       ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            NEW SCENE THREAD                                 │
│                                                                             │
│  [Turn 1] Image 3 (Rp50,000) + "What is this?"                              │
│           └──► Context reset for new physical object                        │
│           └──► AI: "Rp50,000 Banknote. An Indonesian currency note."        │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Context Rules:
1. **Within the Same Scene (Divergence < 0.50):** Maintain short textual conversational memory (last 2–3 question/answer pairs) so Gemini resolves pronouns (*"it"*, *"this"*, *"that"*).
2. **Upon Physical Scene Divergence (Divergence $\ge$ 0.50 confirmed):** 
   * The displayed answer remains visible to the user until they ask a new question.
   * When a new question is submitted from the new scene, the conversational context history resets, preventing context pollution (e.g. asking "What is it?" about a banknote will not reference the previous galangal spice).

---

## 9. Answer Design Architecture

### The Direct-Answer Principle
Visually impaired users rely on rapid auditory synthesis. The first 3–5 words of an answer must directly satisfy the query.

### Response Comparison Table:

| Question & Object | Quality | Example Response | Evaluation |
| :--- | :--- | :--- | :--- |
| **"What is this?"**<br>(Galangal) | **Good (Ideal)** | **HEADLINE:** Galangal<br>**DESCRIPTION:** A cooking rhizome commonly used in Southeast Asian soups and curries. It has a sharp, peppery citrus aroma. | Direct, answers immediately, concise functional description. |
| **"What is this?"**<br>(Galangal) | **Overly Verbose** | **HEADLINE:** Plant Rhizome<br>**DESCRIPTION:** Looking at the image, I can see what appears to be a piece of root or rhizome resting on a surface. It is light brown with segmented rings and measures approximately a few inches in length... | Wastes user's time; buries the identity behind visual fluff. |
| **"How much is this?"**<br>(Rp50,000 note) | **Good (Direct)** | **HEADLINE:** Rp50,000<br>**DESCRIPTION:** A blue 50,000 Indonesian Rupiah banknote featuring national hero Djuanda Kartawidjaja. | Instant denomination identification with secondary validation. |
| **"Is this milk expired?"**<br>(Date hidden) | **Safe & Grounded** | **HEADLINE:** Expiration Date Not Visible<br>**DESCRIPTION:** The printed expiration date is not visible on this side of the carton. Please rotate the carton to show the top cap or upper ridge. | Honest, un-hallucinated, gives clear physical guidance. |
| **"Is this milk expired?"**<br>(Date hidden) | **Dangerous / Hallucinated** | **HEADLINE:** Fresh Milk<br>**DESCRIPTION:** This milk looks fresh and good to drink. | **UNACCEPTABLE.** Fabricates critical health/safety information. |

---

## 10. Speech Output Coordination: VoiceOver vs Dedicated TTS

A critical architectural question is how VoiceOver and application-level audio interact:

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                          SPEECH COORDINATION MODEL                          │
│                                                                             │
│  VoiceOver Enabled (UIAccessibility.isVoiceOverRunning == true):             │
│    • Route announcements through UIAccessibility.post(.announcement)        │
│    • Do NOT fire separate AVSpeechSynthesizer simultaneously                │
│    • AudioSession ducks camera clicks during VoiceOver speech               │
│                                                                             │
│  VoiceOver Disabled (Low Vision / Sighted Testing / Non-VO Accessibility):  │
│    • Provide optional on-demand Speech Synthesis (AVSpeechSynthesizer)       │
│    • Synchronize with haptic milestones                                     │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Recommendations:
1. **Zero Double-Speaking:** When VoiceOver is running, all feedback must go through native VoiceOver announcements. Firing an independent TTS engine creates an unbearable cacophony.
2. **Audio Ducking:** The application audio session must use `.duckOthers` to ensure screen-reader speech remains crystal clear over background audio.
3. **Repeat Gesture:** Implement an accessibility action (or two-finger double tap / dedicated repeat button) that allows VoiceOver users to immediately re-hear the last AI answer.

---

## 11. Accessibility Failure-Mode Analysis Matrix

| Scenario | Potential Failure | Severity | Recommended Mitigation Strategy |
| :--- | :--- | :--- | :--- |
| **User cannot see screen** | User has no spatial guidance on object framing. | **P1** | Lightweight local audio/haptic cues (e.g. gentle tick when text or high-contrast object enters viewfinder center). |
| **User misses hold gesture** | User taps quickly instead of holding. | **P1** | Add hint on brief tap: *"Press and hold while speaking, then release."* |
| **Empty speech / silence** | User releases without speaking. | **P2** | Announce *"I didn't hear a question. Hold and ask again."* Zero API calls made. |
| **Speech recognizer error** | SFSpeechRecognizer fails or drops audio buffer. | **P1** | Friendly prompt: *"Speech recognition had a glitch. Please hold and try again."* |
| **Gemini latency (> 2.5s)** | User wonders if app froze. | **P1** | Subtle rhythmic haptic pulse or soft low-frequency tone every 1.5s during `.thinking`. |
| **Gemini rate limit (429)** | User receives raw error or blank screen. | **P0** | Non-destructive fallback message: *"The service is temporarily busy. Please try again in a moment."* Keep previous answer intact. |
| **Camera pointed at floor / dark** | User asks question but scene is pitch black. | **P1** | Check luminance/exposure on captured frame. If dark, suggest: *"The scene is very dark. Try turning on the flashlight or moving toward light."* |
| **Optical ambiguity** | Object looks like two things (e.g., galangal vs ginger). | **P2** | State primary identity, note plausible alternative, and suggest a distinguishing physical feature (e.g., aroma or skin texture). |

---

## 12. Prioritized UX Problems

### P0 — Fundamental (Core Product Integrity)
* **P0-1: Conversational Anaphora & Context Continuity:** When user asks follow-up questions (*"What is it used for?"*), Gemini currently receives only the current question without the immediate scene thread, which can cause context loss on pronouns.

### P1 — Major (Usability & Accessibility Friction)
* **P1-1: Camera Framing Feedback for Non-Sighted Users:** A user who is blind cannot confirm if an object is centered or in focus before asking.
* **P1-2: Re-Read / Repeat Answer Gesture:** If a VoiceOver announcement is interrupted by a notification or environmental noise, there is no quick gesture to re-announce the latest answer.
* **P1-3: Thinking Audio/Haptic Progress:** In low-connectivity environments where Gemini takes 2–3s, the app needs subtle periodic haptic/audio reassurance that it is actively reasoning.

### P2 — Improvement (Experience Quality)
* **P2-1: Low-Light & Motion Blur Pre-Check:** Inform the user if the captured image was taken during rapid camera rotation or in pitch darkness before sending to Gemini.
* **P2-2: Suggested Follow-Up Prompts:** Visually/auditorily offer 1–2 relevant follow-up questions tailored to the identified object.

### P3 — Polish (Refinement)
* **P3-1: Telemetry Refinement:** Streamline developer diagnostics view to keep logs lightweight.

---

## 13. Recommended Next Development Milestone: T009

### Milestone Proposal: **T009 — Conversational Memory & Accessibility Feedback Architecture**

#### 1. What Problem It Solves:
* Enables true multi-turn visual conversation (*"What is this?"* $\to$ *"What is it used for?"* $\to$ *"Does it contain sugar?"*) anchored to the physical scene.
* Bridges VoiceOver, haptics, and speech repetition for complete non-visual usability.

#### 2. Why It Matters:
* Transforms the interaction from a disconnected series of single-shot questions into a fluid, coherent dialogue with a visual assistant.

#### 3. Scope for T009:
1. **Scene-Anchored Conversational Memory:** Pass the last 1–2 turns of the active scene thread into Gemini's prompt when scene divergence is low.
2. **Context Reset on Scene Divergence:** Automatically start a fresh conversational thread when the camera confirms a new physical scene.
3. **Accessibility Audio/Haptic Polish:**
   * "Repeat Answer" accessibility action for VoiceOver.
   * Thinking haptic heartbeat during multimodal processing.
   * Tap hint for accidental quick taps on the hold area.

#### 4. What Should NOT Be Built Yet:
* Do NOT build complex chat bubble UI or scrollable message archives.
* Do NOT implement heavy custom Create ML models before testing conversational limits on physical objects.

---

## 14. Open Questions for Future Exploration

1. **Flashlight Integration:** Should the app automatically suggest or activate the iPhone torch if scene luminance is below an operational threshold?
2. **Offline Mode Strategy:** How should the app gracefully degrade when completely offline (e.g. relying 100% on on-device Vision/OCR with structured local templates for Indonesian banknotes)?
3. **Language Dynamics:** How should the assistant handle multilingual queries (e.g. user speaking Indonesian asking about an English product label)?

---

*This document serves as the research baseline and product direction guide for the ongoing evolution of TestApp.*
