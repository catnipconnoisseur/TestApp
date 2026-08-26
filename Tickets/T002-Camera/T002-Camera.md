# T002 — Live Camera Preview

## Goal

Establish the application's first real visual-input pipeline by integrating Apple's `AVFoundation` to display a live camera feed within the app, including camera permission handling.

## Why

Before computer vision or multimodal analysis can take place, the application must capture live visual input from the physical world. This ticket establishes the `Camera → visual input` foundation while verifying hardware permission flows.

## Scope

- AVFoundation camera session configuration (`AVCaptureSession`)
- Camera manager (`CameraManager.swift`) to manage capture lifecycle and authorization
- Camera preview presentation in SwiftUI (`CameraPreviewView` / `CameraView.swift`)
- Camera permission states (authorized, denied, restricted, not determined)
- Graceful UI fallback / prompt when camera access is denied
- Connecting `HomeView` to the live camera preview

## Out of Scope

- Vision framework processing (`VNRequest`, `VNImageRequestHandler`, etc.)
- Banknote recognition logic
- Spice/ingredient classification
- Multimodal / Foundation models
- Create ML models
- Audio/speech readout

## Tasks

- [x] Create `Features/Camera/CameraManager.swift` to manage `AVCaptureSession` and permissions
- [x] Create `Features/Camera/CameraView.swift` to render the live camera preview using `AVCaptureVideoPreviewLayer`
- [x] Update `Features/Home/HomeView.swift` to present the live camera view when entering identification mode
- [x] Handle camera permission denial gracefully with an accessible message and guidance to iOS Settings
- [x] Add fallback state for environments without a camera (e.g. Simulator)
- [ ] Validate camera feed on physical device or simulator fallback

## Implementation Notes

- **Architecture:** We introduce `CameraManager` as a dedicated manager layer because it wraps hardware lifecycle and system permission state, matching our lightweight architecture rule.
- **Preview in SwiftUI:** `AVCaptureVideoPreviewLayer` requires a `UIViewRepresentable` bridge to embed UIKit CALayer rendering into SwiftUI.
- **Simulator Considerations:** The iOS Simulator does not have a physical camera, so `CameraManager` handles device unavailability cleanly without crashing.
- **Privacy Requirement:** For running on a physical iOS device, Xcode requires the `NSCameraUsageDescription` key (e.g., *"TestApp uses the camera to recognize real-world objects and banknotes."*) in the target's `Info.plist`.

## Validation

- [x] App compiles without build errors
- [ ] Camera permission prompt triggers on first launch of the camera view
- [ ] Live camera feed streams frames when permission is granted
- [ ] Graceful fallback UI appears when permission is denied or running on a simulator without a camera
- [ ] VoiceOver navigates camera controls and permission fallback states coherently

## Result

**Status:** In Progress

Implemented `CameraManager.swift` and `CameraView.swift`, and connected the camera preview to `HomeView.swift`. Ready for device/simulator validation.

## Learning / Findings

*(To be recorded upon completing validation)*

## Changes from Plan

*(To be recorded if implementation deviates from plan)*

## Next Step

Validate on device/simulator, complete T002, and proceed to **T003 — Vision Classification Baseline (Banknotes)**.
