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
- [x] Validate camera feed, lifecycle (start/stop), error states, and VoiceOver accessibility

## Implementation Notes

- **Architecture:** We introduced `CameraManager` as a dedicated manager layer to encapsulate `AVCaptureSession` configuration and authorization states.
- **Background Dispatch:** `AVCaptureSession` configuration and `startRunning()`/`stopRunning()` calls are executed asynchronously on a private serial dispatch queue (`sessionQueue`), preventing main-thread UI hitching.
- **Preview in SwiftUI:** `AVCaptureVideoPreviewLayer` is bridged via a custom `UIViewRepresentable` (`CameraPreviewRepresentable` and `PreviewUIView`), ensuring efficient hardware-accelerated CALayer rendering.
- **Privacy Requirement:** Configured documentation for `NSCameraUsageDescription` (e.g., *"TestApp uses the camera to capture visual input for object and banknote recognition."*).
- **Simulator & Hardware Fallback:** `CameraManager` detects when no physical video capture device exists and provides a `.unavailable` state with a user-friendly UI instead of failing silently or crashing.

## Validation

- [x] App compiles without build errors
- [x] Camera permission prompt triggers on first launch of the camera view
- [x] Live camera feed streams frames when permission is granted
- [x] Graceful fallback UI appears when permission is denied or running on a simulator without a camera
- [x] VoiceOver navigates camera controls, live preview label, and permission fallback states coherently
- [x] Camera session stops cleanly when dismissed to preserve device battery and hardware resources

## Result

**Status:** Complete

T002 is fully implemented and verified. The `Camera → visual input` foundation is established with complete permission management, background thread session lifecycle, and accessible fallback states.

## Learning / Findings

- **Known:** `AVCaptureSession` configuration must be offloaded from the main actor to avoid frame drops during modal presentation.
- **Hardware vs. Simulator:** Simulators return `nil` for back wide-angle camera devices; handling this explicitly in `CameraManager` prevents runtime exceptions and provides clear feedback to developers and testers.
- **VoiceOver Context:** Full-screen camera viewfinders require explicit accessibility hints so non-sighted users understand device orientation and active capture states before vision processing is attached.

## Changes from Plan

- Added `isConfigured` flag in `CameraManager` to prevent duplicate input addition when reopening the camera view multiple times within the same app session.
- Added accessibility label and hint to `CameraPreviewRepresentable` for screen reader clarity.

## Next Step

Proceed to **T003 — Vision Classification Baseline (Banknotes)** to connect Apple's Vision framework to captured visual frames.
