# T001 — Baseline App Structure

## Goal

Create the smallest possible working SwiftUI application that launches cleanly, displays a clear home screen with an entry point for visual identification, and establishes a stable accessibility-first foundation.

## Why

Before introducing camera feeds, hardware permissions, or computer vision models, we need to verify that our core UI lifecycle, state transitions, and VoiceOver accessibility work reliably in isolation.

## Scope

- SwiftUI app lifecycle (`@main` struct)
- Single-screen home view (`HomeView`)
- Minimal UI state management (`idle` vs. `result`)
- Primary action button ("Identify")
- Placeholder result view
- Accessibility labels, hints, and cohesive element grouping
- Structured project organization (`App/`, `Features/`, `Tickets/`)

## Out of Scope

- Camera capture and `AVFoundation`
- Vision framework (`VNRequest`, etc.)
- Banknote recognition logic
- Spice/ingredient classification logic
- Multimodal / Foundation models
- Create ML models
- Architecture overhead (MVVM, Coordinators, Repositories)
- Third-party packages

## Tasks

- [x] Configure `TestAppApp.swift` in `App/`
- [x] Implement `HomeView.swift` in `Features/Home/`
- [x] Define simple two-state enum (`idle`, `result`)
- [x] Add decorative icon with `.accessibilityHidden(true)`
- [x] Combine title and subtitle into a single accessible header element
- [x] Add large-target primary action button with accessible label and hint
- [x] Add placeholder result container for state transition feedback
- [x] Validate build and VoiceOver navigation

## Implementation Notes

- **State Model:** Used a lightweight `AppState` enum (`.idle`, `.result(String)`) to enforce mutually exclusive UI states without boolean flag clutter.
- **Accessibility Hierarchy:** Combined the title and subtitle using `.accessibilityElement(children: .combine)` so VoiceOver announces the app purpose in a single coherent sentence.
- **Touch Targets:** Used `.controlSize(.large)` and `.frame(maxWidth: .infinity)` to ensure touch targets easily exceed the Apple HIG 44x44 pt standard for motor accessibility.
- **Dynamic Type:** Relied on semantic typography styles (`.largeTitle`, `.subheadline`, `.title2`, `.title3`) to respect system-wide font scaling.

## Validation

- [x] App compiles without build errors
- [x] App launches successfully in iOS Simulator
- [x] Home screen layout renders correctly with header, spacer, and primary button
- [x] Tapping "Identify" transitions state and reveals placeholder result card
- [x] VoiceOver / Accessibility Inspector reads header and button coherently
- [x] No app-breaking runtime crashes

## Result

**Status:** Complete

The baseline SwiftUI app structure is fully functional and verified. The UI transitions smoothly from idle state to the simulated result state, and all accessibility attributes are correctly structured.

## Learning / Findings

- **Known:** Minimal state-driven SwiftUI can represent simple prototype flows cleanly without needing full MVVM boilerplate.
- **Assumption:** VoiceOver announcements are clearest when decorative icons are hidden and related text items are combined into a single semantic element.
- **Experiment Tested:** Verified that our UI hierarchy and accessibility foundation work in total isolation before introducing camera hardware complexity.

## Next Step

Begin **T002 — Live Camera Preview** to connect Apple's AVFoundation camera feed and establish the `Camera → visual input` pipeline.
