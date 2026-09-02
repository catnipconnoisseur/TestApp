# TestApp — AI Agent Entry Point

> **This is the root context file for AI coding agents.** Read this file first before making any changes.

---

## Quick Orientation

**TestApp** is an iOS visual accessibility assistant built with SwiftUI, Apple Vision, on-device speech recognition, and Gemini multimodal AI. It helps people who are blind or visually impaired understand their physical surroundings by pointing their camera and asking spoken questions.

**Core interaction model:** POINT → ASK → UNDERSTAND

---

## Context Files & Navigation

Detailed project context is maintained in `docs/` and task tracking in `tickets/`. Read the relevant file before working on a specific area.

| File | Contents |
|------|----------|
| [`docs/STRUCTURE.md`](docs/STRUCTURE.md) | File tree, feature modules, dependency graph |
| [`docs/CONVENTIONS.md`](docs/CONVENTIONS.md) | Code style, naming, architecture patterns, state management, git rules |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Key architectural & product decisions with rationale |
| [`docs/PROGRESS.md`](docs/PROGRESS.md) | Completed milestones, planned work, current state, tech debt |
| [`docs/ACCESSIBILITY.md`](docs/ACCESSIBILITY.md) | VoiceOver, announcements, audio, haptics, touch targets |
| [`docs/AI-BEHAVIOR.md`](docs/AI-BEHAVIOR.md) | Gemini prompts, language directives, currency recognition, progressive disclosure |
| [`docs/TESTING.md`](docs/TESTING.md) | Build commands, manual checklists, edge cases, debugging tips |
| [`tickets/ROADMAP.md`](tickets/ROADMAP.md) | Development roadmap & completed/planned tickets |

---

## Critical Rules

### Always
- Read this file and relevant `docs/` files before making changes
- Check `tickets/ROADMAP.md` for current ticket context and scope
- Keep changes small and focused
- Explain important technical decisions
- Test before moving forward (build at minimum)
- Preserve existing working functionality
- Use `@Observable` macro (not `ObservableObject` / `@Published`)
- Use plain text in AI responses (no Markdown syntax)
- Route all spoken output through `AccessibilityVoiceService.shared`

### Never
- Commit or push to Git without explicit user instruction
- Include ticket numbers (T001, T002, etc.) in commit messages
- Add third-party dependencies without approval
- Add architecture layers (ViewModels, Coordinators) unless solving a real problem
- Remove the LANGUAGE DIRECTIVE or PHYSICAL DEFORMATION RESILIENCE from Gemini prompts
- Make the AI narrate unsolicited — the user is in control
- Expose system internals (confidence levels, source badges) in user-facing UI

---

## Git Rules

- Single `main` branch
- Conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- **STRICTLY NO ticket numbers** in any commit message
- **Never auto-commit or auto-push** — wait for explicit user instruction

---

## Technology Stack

| Layer | Technology |
|-------|-----------|
| UI | SwiftUI |
| Camera | AVFoundation (`AVCaptureSession`) |
| Vision | Apple Vision (`VNClassifyImageRequest`, `VNRecognizeTextRequest`, `VNGenerateImageFeaturePrintRequest`) |
| Speech Input | SFSpeechRecognizer (on-device) |
| Speech Output | AVSpeechSynthesizer + UIAccessibility announcements |
| AI Reasoning | Gemini 2.5 Flash (REST API via URLSession) |
| Storage | UserDefaults (no CoreData, no CloudKit) |
| Dependencies | Zero third-party packages |

---

## Source of Truth

When information conflicts:
1. Current user instruction
2. This file (`AGENTS.md`)
3. Relevant `docs/` or `tickets/` file
4. Existing implementation

The current user instruction always takes priority.

---

## Maintenance Rules for `docs/` & `tickets/`

Update documentation when:
- **`STRUCTURE.md`**: A file is added, removed, or moved
- **`CONVENTIONS.md`**: A new pattern is established or an existing pattern changes
- **`DECISIONS.md`**: A significant technical or product decision is made
- **`PROGRESS.md`**: A milestone is completed or a new issue is discovered
- **`ACCESSIBILITY.md`**: VoiceOver behavior, announcements, or audio routing changes
- **`AI-BEHAVIOR.md`**: Gemini prompts, interpretation rules, or language routing changes
- **`TESTING.md`**: New test scenarios are discovered or build procedures change
- **`ROADMAP.md`**: Ticket status or timeline changes

Do NOT update docs for trivial changes (typo fixes, minor refactors that don't change behavior).
