# TestApp — Key Decisions

> Last updated: 2026-09-02
> Decisions are recorded chronologically. Each entry explains **what** was decided, **why**, and **what was rejected**.

---

## D001 — Feature-Oriented Architecture Over MVVM

**Decision:** Use a flat feature-folder structure with Views, Services, and Managers. No enforced MVVM layer.

**Why:** The app has a single primary screen (CameraView). Introducing ViewModels for every feature adds indirection without solving a real problem. State lives in `CameraView` via `@State`, and services handle domain logic.

**Rejected:** Full MVVM with a ViewModel per feature. Will be reconsidered only if `CameraView` state becomes unmanageable.

---

## D002 — Camera as Root View, Not a Modal

**Decision:** The camera is the app's root view. There is no persistent "Home" screen to navigate away from.

**Why:** The original `HomeView` was a decorative landing screen that required 4–5 VoiceOver interactions before reaching the functional camera. For a blind user, this was a wall with no value. Now: first launch → WelcomeView onboarding → Camera. All subsequent launches → Camera directly.

**Rejected:** Keeping a permanent HomeView as a navigation hub. Also rejected: launching directly into Camera without any onboarding (new VoiceOver users need to learn the hold-to-speak pattern first).

---

## D003 — Single Voice Interaction Area Instead of Dual Buttons

**Decision:** Replace the `[Analyze]` + `[Hold to Speak]` dual-button layout with a single large (~120pt) voice interaction area at the bottom.

**Why:** Two buttons forced the user to decide which to use. Voice input ("What is this?") subsumes the Analyze button's function. A single large touch target is better for motor accessibility. The Analyze button is kept as a hidden fallback only when microphone permission is denied.

**Rejected:** Keeping both buttons side-by-side.

---

## D004 — On-Device Vision as Pre-Filter, Not Final Answer

**Decision:** On-device `VNClassifyImageRequest` provides broad category hints (e.g., "container", "document") that are used as pre-filters and sensor hints for Gemini, but never as the final user-facing answer.

**Why:** Built-in Vision classifications are too generic for meaningful accessibility responses. "Beverage Container" is not useful to a blind user who wants to know "This is a 500ml water bottle by Aqua."

**Rejected:** Using Vision classification as the primary identification engine.

---

## D005 — Gemini Multimodal AI as Primary Reasoning Engine

**Decision:** Gemini 2.5 Flash provides the final contextual understanding for all user queries. It receives the camera frame, on-device OCR/classification hints, and the user's spoken question.

**Why:** Multimodal AI can reason about context, spatial relationships, deformed objects, and answer open-ended questions — capabilities that on-device Vision alone cannot provide.

**Trade-off:** Requires network connectivity and a valid API key. Rate limiting (HTTP 429) is handled gracefully with fallback to on-device results.

---

## D006 — Structured Plain-Text Output Contract (HEADLINE / DESCRIPTION)

**Decision:** All Gemini responses must follow a strict two-part format:
```
HEADLINE: [1-4 word direct answer]
DESCRIPTION: [1-3 sentence explanation]
```

**Why:** Screen readers need concise, predictable output. A headline gives the quick answer; a description provides context. Markdown formatting (bold, bullets, headers) is explicitly forbidden because it creates auditory noise in VoiceOver.

**Rejected:** Free-form Gemini responses. Also rejected: JSON-structured responses (adds parsing complexity for minimal benefit over labeled plain text).

---

## D007 — Multi-Signal Currency Synthesis for Indonesian Rupiah

**Decision:** Indonesian banknote identification uses a multi-signal approach: on-device OCR → denomination text matching → color scheme matching → portrait/emblem recognition → Gemini visual reasoning. Signals are synthesized in `InterpretationService`.

**Why:** No single signal is reliable alone. OCR fails on wrinkled notes. Color alone is ambiguous under varied lighting. Gemini alone may hallucinate denominations. Combining all signals produces the most reliable identification.

**Implementation detail:** `InterpretationService.validRupiahDenominations` maps ~70 text variants (including Indonesian words like "lima puluh ribu") to canonical denominations.

---

## D008 — Language as a Pipeline-Wide Directive, Not a Post-Processing Translation

**Decision:** When the user selects Indonesian, the selected locale is injected into the Gemini prompt as a strict `LANGUAGE_DIRECTIVE`. The AI generates its response in Indonesian natively — it does not generate English and translate after the fact.

**Why:** Post-processing translation breaks natural phrasing and increases latency. Native generation produces more fluent Indonesian responses. The locale flows through: `SpeechService.selectedLocale` → `MultimodalService.buildLanguageDirective()` → `InterpretationService.interpret(locale:)` → `AccessibilityVoiceService.speak(languageCode:)`.

**Rejected:** Client-side translation of English responses. Also rejected: separate Indonesian-specific prompts (the unified prompt with a language directive is more maintainable).

---

## D009 — Hold-to-Talk Interaction Model

**Decision:** Voice input uses a hold-to-talk model: user presses and holds the bottom voice area → speaks → releases → transcript is captured and submitted.

**Why:** Hold-to-talk gives the user explicit control over when recording starts and stops. This avoids false activations and is predictable for VoiceOver users (double-tap to activate, double-tap to release). It matches natural walkie-talkie behavior.

**Rejected:** Push-to-talk (single tap toggle). Rejected: always-listening mode. Rejected: wake-word activation.

---

## D010 — Scene Divergence Detection for Answer Persistence

**Decision:** Once Gemini provides an answer, it persists in the interpretation card until the camera detects a significant scene change (divergence score > 0.50 sustained for 350ms).

**Why:** Users need the answer to stay visible while they naturally move the camera. Without persistence, minor hand tremors would clear the answer. The divergence score combines OCR text change (weight 0.5), classification change (weight 0.3), and feature print embedding distance (weight 0.5).

**Rejected:** Immediate clearing on any camera movement. Also rejected: time-based auto-clear (the user should control when information disappears).

---

## D011 — AccessibilityVoiceService as Dual-Mode Audio Coordinator

**Decision:** A singleton `AccessibilityVoiceService` routes all spoken output through two paths:
1. **VoiceOver active** → `UIAccessibility.post(notification: .announcement)` with language attributes
2. **VoiceOver inactive** → `AVSpeechSynthesizer` with language-matched voice

**Why:** Blind users may or may not have VoiceOver enabled. The app must always produce audible answers. When VoiceOver is active, posting accessibility announcements avoids duplicate audio streams. When VoiceOver is off, the synthesizer speaks aloud so the user still hears the answer.

---

## D012 — Zero Third-Party Dependencies

**Decision:** The entire project uses only native Apple frameworks: SwiftUI, AVFoundation, Vision, Speech, CoreImage, UIKit.

**Why:** This is a learning project for Apple Developer Academy. External dependencies would obscure the learning objective of understanding Apple's native visual and accessibility technologies. Also: fewer dependencies = simpler build, no CocoaPods/SPM resolution, and deterministic behavior.

---

## D013 — Progressive Disclosure in AI Responses

**Decision:** The AI follows intent-controlled progressive disclosure rules. It answers only what the user asked:
- "What is this?" → Name + one note
- "What color is it?" → Color only
- "Describe everything" → Full visual overview (explicit exception)

**Why:** A blind user is in control. Unsolicited information creates auditory overload. The user will ask follow-up questions if they want more detail. This mirrors natural human conversation, not robotic data dumps.

---

## D014 — Physical Deformation Resilience in Prompts

**Decision:** Both Gemini prompt builders include explicit `PHYSICAL DEFORMATION RESILIENCE` rules instructing the AI that wrinkled, folded, creased, bent, or angled objects retain their identity.

**Why:** Standard image classifiers perform worse on non-flat objects. By explicitly instructing the AI model that physical deformation does not change identity, we improve robustness for real-world conditions (crumpled banknotes, folded packaging, angled labels).

---

## D015 — Quick Access & Action Button Integration via Native App Intents

**Decision:** Expose TestApp to system shortcuts, Siri, Spotlight, and the iPhone Action Button via the native `AppIntents` framework (`QuickAccessIntent` + `AppShortcutsProvider`), with `openAppWhenRun = true` and a dedicated `launchedFromQuickAccess` launch flag.

**Why:** For blind and visually impaired users, finding and opening the app icon introduces friction in spontaneous physical environments. Integrating with the Action Button and Siri reduces the steps from *Need Visual Info → Search App → Open → Orient → Hold* to *Press Action Button → "TestApp ready" → Hold*.

**Rejected Alternatives:**
1. *Custom URL Schemes / Deep Linking:* Unnecessary complexity; `@AppStorage` / `UserDefaults` and native `AppIntents` provide direct, type-safe foregrounding without custom URL scheme registration overhead.
2. *Automatic Microphone Recording on Launch:* Rejected to preserve user agency and privacy. The user must intentionally hold the Voice Area to initiate recording.
3. *Bypassing Onboarding:* Rejected. If first-time onboarding or permissions have not been completed, standard onboarding flows remain active to guarantee safety and hardware permissions.

---

## D016 — Centralized Permissions / Setup Hub with Optional Quick Access

**Decision:** Structure the onboarding flow as **Welcome → Permissions / Setup → Try Asking → Get Started**, placing the optional Quick Access card directly inside the **Permissions / Setup** page (Screen 2) immediately following the Welcome screen.

**Why:**
- The Permissions / Setup page serves as the app's central setup hub where the user prepares the app: granting required hardware access (Camera, Microphone, Speech) and optionally setting up Quick Access.
- Users land directly on the setup hub after the Welcome screen, ensuring Quick Access is immediately discoverable without requiring navigation to later stages or buried sheets.
- "Open iOS Settings" uses a cascading URL resolver prioritizing direct Action Button deep linking (`App-prefs:root=ACTION_BUTTON` / `prefs:root=ACTION_BUTTON`) with seamless fallback to standard app settings.
- The Try Asking page remains dedicated exclusively to teaching the core voice interaction (`Touch and hold Voice Area → speak → release`).
- Keeping Quick Access optional ensures users can tap "Continue" without being blocked, while clearly communicating privacy guarantees (camera only; microphone never records automatically).

**Rejected Alternatives:**
1. *Placing Quick Access on the final Ready screen:* Rejected because users had to navigate past the interactive voice tutorial before even seeing shortcut options.
2. *Mandatory Action Button Configuration:* Rejected. Third-party apps cannot force or programmatically assign hardware buttons; forcing external navigation creates onboarding friction.
3. *Simulated Assignment Detection:* Rejected. iOS provides no public API to verify hardware Action Button assignment. The app accurately tracks user-guided completion via `@AppStorage("hasCompletedQuickAccessSetup")`.

---

## D017 — Scene-Anchored Conversational Memory (T009)

**Decision:** Maintain short-lived multi-turn conversational context anchored to the physical scene via on-device Vision `VNFeaturePrintObservation`, resetting active conversational threads only upon temporal confirmation of sustained visual divergence ($\ge 0.50$ for $\ge 0.40$s).

**Why:**
- Enables natural follow-up questions (*"What is it used for?"*, *"What color is it?"*, *"Read the ingredients"*) without forcing the user to repeat the full name of the object.
- **Local Scene Tracking:** FeaturePrint evaluation and divergence tracking happen completely on-device in `InterpretationService` / `CameraView` at 0 network cost. Gemini is only contacted when the user explicitly asks a question.
- **Temporal Debouncing & Stability:** Sustained divergence duration ($\ge 0.40$s) prevents temporary hand shakes, brief occlusions, micro-angle shifts, or lighting fluctuations from prematurely destroying an active conversational thread.
- **Persistent Answer Independence:** Resetting an active thread on confirmed scene change clears the context sent to Gemini on the next turn, but does *not* erase the visually displayed AI answer card (preserving T007.3 persistent answer requirements).
- **Lightweight Payload Strategy:** Turn 1 sends the initial image and prompt. Follow-up turns send the conversation history (alternating `user` and `model` turns) plus the current image frame, allowing Gemini to focus on the follow-up question while remaining grounded in the original interaction.
- **Empirical Tuning Constants:** All scene stability parameters are consolidated in `SceneStabilityConfiguration` as empirical tuning constants rather than hardcoded magic numbers.

**Rejected Alternatives:**
1. *Continuous Video Streaming to Gemini:* Cloud video streaming consumes excessive bandwidth, battery, and introduces unacceptable latency and token costs.
2. *Permanent / Persistent Disk Conversation History:* Unnecessary for real-time visual assistance and risks context contamination between disparate physical tasks.
3. *Single-Frame Instant Scene Reset:* Rejected because normal hand jitter and perspective rotation produce single-frame feature variance, which would erroneously wipe user context mid-conversation.

---

## D018 — Create ML Feasibility and Hybrid On-Device / Cloud Strategy

**Decision:** Defer adding a standalone custom Create ML / Core ML model to the production build, preserving the current hybrid architecture (Apple Vision OCR/classification + multi-signal evidence fusion + Gemini 2.5 Flash multimodal reasoning).

**Why:**
- **Visual Assistant vs Closed-Set Classifier:** Visually impaired users require contextual, intent-driven conversational assistance (*"What is this?"*, *"What is it used for?"*, *"Is it safe?"*). A closed-set Core ML classifier outputs only static labels and cannot participate in multi-turn dialog or progressive disclosure.
- **Deformation Resilience Already Solved via Multi-Cue Synthesis:** While on-device Vision OCR struggles on crumpled or folded banknotes, Gemini 2.5 Flash with prompt-level `PHYSICAL DEFORMATION RESILIENCE` synthesizes secondary cues (color schemes, portraits, emblem positions, layout) to correctly identify denominations without needing a custom neural network.
- **Zero App Bundle Bloat:** Keeps the app bundle lightweight (0 MB added model weight) and avoids the heavy maintenance burden of curating and updating 4,000+ annotated physical training images across currency emissions.
- **Architectural Extensibility:** Should a low-latency offline edge-classifier be mandated in the future, it can be integrated cleanly into `VisionService` via `VNCoreMLRequest` as an additional high-confidence sensor feed into `InterpretationService` without altering user-facing view logic.

**Rejected Alternatives:**
1. *Pure Core ML Architecture:* Completely rejected because it strips the app of all conversational and open-domain visual reasoning capabilities.
2. *Speculative Model Bundling:* Rejected adding placeholder or small un-benchmarked `.mlmodel` files to prevent shipping untested binary weight without a demonstrated user need.

---

## D019 — First-Time Onboarding Language Selection as App-Wide Source of Truth

**Decision:** Language preference is selected immediately on the first-time Welcome onboarding page and becomes the single, app-wide source of truth for UI localization, speech recognition locale, Gemini output language, accessibility strings, and fallback messages. The language selector is implemented as an accessible focused control that supports cycling selections via VoiceOver swipe up/down (`.accessibilityAdjustableAction`) without introducing global screen gestures that conflict with assistive navigation.

**Why:**
- **Zero Duplication:** Reuses the existing `selectedLanguageCode` stored in `UserDefaults.standard` rather than creating parallel settings (e.g. `onboardingLanguage`, `geminiLanguage`, etc.).
- **Coherent Accessible Control:** Rather than forcing blind users to hunt for separate small touch targets, the language selector acts as one unified accessibility element announcing: *"Language. English selected. Swipe up or down to change language."* Standard VoiceOver vertical swipe gestures cycle options natively via `.accessibilityAdjustableAction`.
- **Sighted Usability:** Normal sighted users tap either language card normally. Visual selection states use shape (`checkmark.circle.fill` vs `circle`), text ("Active" / "Dipilih" capsule badges), and border styling rather than color alone.
- **Explicit Spatial Guidance:** Communicates clear positional cues (*"Choose your language above, then select Continue at the bottom of the screen."*), eliminating guesswork for non-visual exploration.
- **Immediate Reactive UI:** Changing language immediately updates all Welcome text, spatial guidance, and the bottom Continue button (*"Continue"* / *"Lanjut"*) without restarting the app.
- **Sensible Default:** Defaults to Indonesian (`id-ID`) if the device's system language is Indonesian; otherwise defaults to English (`en-US`), while keeping both explicit options visible on the Welcome page.
- **Unified Flow:** Preserves onboarding for returning users while keeping language customizable at any time via the existing Settings sheet.

**Rejected Alternatives:**
1. *Global Swipe Up/Down Gesture for Language Selection:* Completely rejected because hijacking full-screen vertical swipe gestures conflicts directly with VoiceOver's rotor and navigation commands.
2. *Adding a separate dedicated language picker step in onboarding:* Rejected because introducing a 5th onboarding screen adds unnecessary friction when language selection naturally belongs on the initial Welcome screen.
3. *Relying solely on system language without explicit choice:* Rejected because users (especially bilingual or assistive technology users) frequently prefer speaking to and hearing responses from their visual assistant in a specific language distinct from their iOS system language.
