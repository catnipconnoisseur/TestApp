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
