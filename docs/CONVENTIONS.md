# TestApp — Code Conventions

> Last updated: 2026-09-02

---

## Language & Frameworks

- **Language:** Swift (latest stable)
- **UI Framework:** SwiftUI
- **Platform:** iOS 17.0+
- **Third-party dependencies:** None. Zero external packages. Everything uses native Apple frameworks.

---

## Architecture Style

### Feature-Oriented Flat Structure
- One folder per feature concern under `Features/`.
- No nested sub-folders within feature folders.
- No shared `Utils/`, `Helpers/`, or `Extensions/` folders. If a utility is needed, it belongs in the feature that uses it.

### Layer Responsibilities
| Layer | When to Use | Example |
|-------|-------------|---------|
| **View** | UI layout, presentation, user interaction, connecting UI to state | `CameraView`, `WelcomeView` |
| **Manager** | Owns system-level resources or hardware lifecycles | `CameraManager` (AVFoundation) |
| **Service** | Encapsulates specialized domain processing or external APIs | `VisionService`, `MultimodalService`, `SpeechService` |
| **Model** | Structured domain data | `RecognitionResult`, `InterpretationResult` |
| **ViewModel** | **Not used.** Only introduce if a View's state/logic becomes unmanageable. Currently all state lives in `CameraView` via `@State`. |

### Architectural Growth Rule
> **Introduce a layer when the current code has a real problem that the layer solves.** Do not add architecture preemptively.

---

## State Management

- **`@State`**: Primary mechanism. All mutable UI state in `CameraView` uses `@State`.
- **`@Observable` macro**: Used on `CameraManager` and `SpeechService` for automatic SwiftUI observation.
- **`@AppStorage`**: Used for persistent user preferences (`hasCompletedOnboarding`).
- **`UserDefaults`**: Used directly for `selectedLanguageCode` and `apiKey` storage.
- **No Combine, no `ObservableObject`**: The codebase uses the modern `@Observable` macro, not the legacy `ObservableObject` + `@Published` pattern.

---

## Naming Conventions

### Files
- Views: `{Feature}View.swift` (e.g., `CameraView.swift`, `SettingsView.swift`)
- Managers: `{Domain}Manager.swift` (e.g., `CameraManager.swift`)
- Services: `{Domain}Service.swift` (e.g., `VisionService.swift`, `SpeechService.swift`)
- Models: `{Domain}Result.swift` or descriptive noun (e.g., `RecognitionResult.swift`)

### Types
- **Enums**: PascalCase, often `private` when scoped to a single file (e.g., `InteractionState`, `OnboardingStep`).
- **Structs/Classes**: PascalCase.
- **Properties**: camelCase.
- **Constants**: camelCase within type scope (e.g., `defaultDwellThreshold`, `smoothingWindowSize`).

### MARK Comments
The codebase uses `// MARK: -` extensively for section organization:
```swift
// MARK: - Properties
// MARK: - Initialization
// MARK: - Public Interface
// MARK: - Session Configuration
// MARK: - Evidence Synthesis
```
Follow this pattern in all files. Use descriptive section names.

---

## SwiftUI Patterns

### View Composition
Large views like `CameraView` decompose into computed properties:
```swift
private var cameraReadyView: some View { ... }
private var topBar: some View { ... }
private var bottomInteractionArea: some View { ... }
private var interpretationCard: some View { ... }
```
This keeps the `body` property clean and navigable.

### Accessibility
Every interactive element must have:
- `.accessibilityLabel()` — What it is
- `.accessibilityHint()` — What it does (for non-obvious interactions)
- `.accessibilityElement(children: .combine)` — When grouping child elements

See `docs/ACCESSIBILITY.md` for detailed VoiceOver conventions.

### Animations
- Use `withAnimation(.easeInOut(duration: 0.15–0.35))` for state transitions.
- Haptic feedback via `UIImpactFeedbackGenerator` for interaction confirmation.
- No spring animations on accessibility-critical elements.

### Sheets
- Settings is presented as a `.sheet` with `.presentationDetents([.medium, .large])`.
- No navigation stack pushes from the camera view.

---

## Concurrency Patterns

### Async/Await
- `MultimodalService.analyzeImage()` is `async`.
- `SpeechService.stopRecordingAndGetTranscript()` is `async`.
- Camera voice queries use `Task { }` blocks from the main actor.

### GCD (Legacy)
- `CameraManager` uses `DispatchQueue` for session and video output queues.
- `VisionService` uses a serial `DispatchQueue` with manual `isProcessing` throttle.
- These are intentional: AVFoundation requires GCD-based delegate callbacks.

### Thread Safety
- `InterpretationService` uses `NSLock` for its shared classification buffer.
- `CameraManager` uses `NSLock` for pixel buffer access.
- `VisionService` is `@unchecked Sendable` with a serial queue.

---

## Error Handling

- Services return structured result types (e.g., `MultimodalResult` with `ResponseStatus` enum) rather than throwing errors.
- Camera and speech errors are surfaced through state enums (e.g., `CameraStatus.failed(String)`, `SpeechServiceStatus.failed(String)`).
- HTTP errors from Gemini are classified: `rateLimited`, `authenticationError`, `serverError`, `networkError`, `parsingError`.

---

## Logging

- Use `print("[SERVICE_NAME] message")` for development logging (e.g., `[SPEECH]`, `[VOICE]`, `[VisionService]`).
- No structured logging framework is used.
- Logging is acceptable during development but should not expose sensitive data (API keys, full response bodies).

---

## Git Conventions

### Commit Messages
- Use conventional commit format: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`.
- **STRICTLY NO ticket numbers** in commit messages (`T001`, `T002`, etc. are forbidden).
- Be descriptive: `feat(recognition): enhance visual recognition accuracy for wrinkled banknotes`.

### Branching
- Single `main` branch. No feature branches unless explicitly needed for risky experiments.

### Commit/Push Permission
- **Never auto-commit or auto-push.** Always wait for explicit user instruction.

---

## What NOT to Do

- Do not introduce `ObservableObject` / `@Published`. Use `@Observable` macro instead.
- Do not create empty folders preemptively.
- Do not add third-party packages without explicit user approval.
- Do not use Markdown syntax in Gemini AI responses (plain text only).
- Do not expose system internals (confidence levels, source badges) in user-facing UI.
- Do not create separate branches for routine ticket work.
