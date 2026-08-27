import AVFoundation
import SwiftUI

// MARK: - UIKit Preview View Bridge

final class PreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

struct CameraPreviewRepresentable: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {
        uiView.videoPreviewLayer.session = session
    }
}

// MARK: - SwiftUI Camera View

struct CameraView: View {
    @State private var cameraManager = CameraManager()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            switch cameraManager.status {
            case .ready:
                CameraPreviewRepresentable(session: cameraManager.captureSession)
                    .ignoresSafeArea()
                    .accessibilityLabel("Live camera viewfinder")
                    .accessibilityHint("Point camera at objects or banknotes to capture visual input.")
                
                // Bottom Telemetry / Observation Overlay
                VStack {
                    Spacer()
                    telemetryOverlay(result: cameraManager.latestResult)
                }
                .ignoresSafeArea(edges: .bottom)
                
            case .unauthorized:
                unauthorizedView
                
            case .unavailable:
                unavailableView
                
            case .failed(let message):
                errorView(message: message)
                
            case .unconfigured:
                ProgressView("Connecting Camera...")
                    .foregroundStyle(.white)
            }
            
            // Top Controls Overlay
            VStack {
                HStack {
                    Button {
                        cameraManager.stopSession()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(16)
                    }
                    .accessibilityLabel("Close camera")
                    .accessibilityHint("Returns to the home screen")
                    
                    Spacer()
                }
                Spacer()
            }
        }
        .onAppear {
            cameraManager.requestAccessAndSetup()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    // MARK: - Telemetry / Observation Overlay
    
    private func telemetryOverlay(result: RecognitionResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            
            HStack {
                Text("Vision Telemetry (T003)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if let error = result.errorMessage {
                    Text("Error: \(error)")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.3))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                } else if result.processingTimeMs > 0 {
                    Text("Live • \(Int(result.processingTimeMs))ms")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.3))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                } else {
                    Text("Awaiting frames...")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Divider()
                .background(Color.white.opacity(0.2))
            
            // 1. Image Classification Observation
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Classification:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    if result.totalClassificationCount > 0 {
                        Text("(\(result.totalClassificationCount) categories evaluated)")
                            .font(.caption2)
                            .foregroundStyle(.secondary.opacity(0.8))
                    }
                }
                
                if !result.classifications.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(result.classifications) { item in
                            HStack {
                                Text("• \(item.identifier)")
                                    .font(.subheadline)
                                    .fontWeight(item == result.classifications.first ? .semibold : .regular)
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Text("\(Int(item.confidence * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(item.confidence > 0.3 ? .green : .white.opacity(0.7))
                            }
                        }
                    }
                } else {
                    Text("No classification returned by model")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            
            // 2. OCR Text Observation
            VStack(alignment: .leading, spacing: 4) {
                Text("OCR Text:")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                
                if !result.recognizedTexts.isEmpty {
                    Text(result.combinedText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.yellow)
                        .lineLimit(2)
                } else {
                    Text("No text detected")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.75))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vision results. Classification: \(result.topClassification?.identifier ?? "None"). Text: \(result.recognizedTexts.isEmpty ? "None" : result.combinedText)")
    }
    
    // MARK: - Fallback State Views
    
    private var unauthorizedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)
                .accessibilityHidden(true)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("TestApp needs camera permission to capture visual input for identification. Please enable Camera access in iOS Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
            
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Link("Open Settings", destination: settingsURL)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
            }
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
    
    private var unavailableView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.trianglebadge.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            
            Text("Camera Not Available")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text("No camera device was detected. If running on iOS Simulator, test on a physical iOS device with a camera.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
                .accessibilityHidden(true)
            
            Text("Camera Error")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
            
            Text(message)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 24)
        }
        .padding(24)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    CameraView()
}
