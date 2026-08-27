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
    @State private var multimodalService = MultimodalService()
    
    // Multimodal Sheet State
    @State private var isAnalyzing = false
    @State private var multimodalResult: MultimodalService.MultimodalResult?
    @State private var showMultimodalSheet = false
    @State private var showAPIKeySheet = false
    @State private var apiKeyInput = MultimodalConfig.apiKey
    
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
                
                // Bottom Telemetry & Analyze Action Overlay
                VStack(spacing: 12) {
                    Spacer()
                    
                    // On-Demand Multimodal Trigger Button
                    Button {
                        triggerMultimodalAnalysis()
                    } label: {
                        HStack(spacing: 8) {
                            if isAnalyzing {
                                ProgressView()
                                    .tint(.white)
                                Text("Analyzing...")
                                    .fontWeight(.bold)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.headline)
                                Text("Analyze")
                                    .fontWeight(.bold)
                            }
                        }
                        .font(.body)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                    }
                    .disabled(isAnalyzing)
                    .accessibilityLabel("Analyze current frame with Multimodal AI")
                    .accessibilityHint("Captures the current view and requests detailed contextual reasoning")
                    .padding(.horizontal, 16)
                    
                    // Continuous Vision Telemetry Overlay (T003)
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
                    
                    // Local API Key Configuration Trigger
                    Button {
                        apiKeyInput = MultimodalConfig.apiKey
                        showAPIKeySheet = true
                    } label: {
                        Image(systemName: MultimodalConfig.hasConfiguredKey ? "key.fill" : "key.slash.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(16)
                    }
                    .accessibilityLabel(MultimodalConfig.hasConfiguredKey ? "Configure API Key" : "Set API Key (Required for Multimodal)")
                    .accessibilityHint("Opens sheet to configure local API key")
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
        .sheet(isPresented: $showMultimodalSheet) {
            multimodalResultView
        }
        .sheet(isPresented: $showAPIKeySheet) {
            apiKeyConfigurationView
        }
    }
    
    // MARK: - Multimodal Analysis Trigger
    
    private func triggerMultimodalAnalysis() {
        guard MultimodalConfig.hasConfiguredKey else {
            showAPIKeySheet = true
            return
        }
        
        guard let jpegData = cameraManager.captureCurrentFrameJPEG() else {
            multimodalResult = MultimodalService.MultimodalResult(
                text: "Unable to capture image from camera feed.",
                latencyMs: 0.0,
                status: .error("Capture Failed")
            )
            showMultimodalSheet = true
            return
        }
        
        isAnalyzing = true
        showMultimodalSheet = true
        multimodalResult = nil
        
        Task {
            let result = await multimodalService.analyzeImage(
                jpegData: jpegData,
                apiKey: MultimodalConfig.apiKey
            )
            await MainActor.run {
                self.multimodalResult = result
                self.isAnalyzing = false
            }
        }
    }
    
    // MARK: - Multimodal Result Sheet (T004)
    
    private var multimodalResultView: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                if isAnalyzing {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Analyzing image with Multimodal AI...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Analyzing image with Multimodal AI. Please wait.")
                } else if let result = multimodalResult {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            
                            // Status & Latency Badge
                            HStack {
                                switch result.status {
                                case .success:
                                    Label("Success", systemImage: "checkmark.circle.fill")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.green)
                                case .error:
                                    Label("Error", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.red)
                                case .idle:
                                    EmptyView()
                                }
                                
                                Spacer()
                                
                                if result.latencyMs > 0 {
                                    Text(String(format: "Latency: %.2fs", result.latencyMs / 1000.0))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 4)
                            
                            Divider()
                            
                            Text("Multimodal Analysis")
                                .font(.headline)
                                .accessibilityAddTraits(.isHeader)
                            
                            Text(result.text)
                                .font(.body)
                                .lineSpacing(4)
                                .accessibilityLabel("Analysis result: \(result.text)")
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Multimodal Result")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showMultimodalSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    // MARK: - Local API Key Configuration Sheet
    
    private var apiKeyConfigurationView: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Key Configuration"), footer: Text("Your API key is stored locally on this device in private storage and is never committed or tracked in Git.")) {
                    SecureField("Paste API Key", text: $apiKeyInput)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                }
                
                if MultimodalConfig.hasConfiguredKey {
                    Section {
                        Button(role: .destructive) {
                            MultimodalConfig.apiKey = ""
                            apiKeyInput = ""
                        } label: {
                            Text("Clear Stored Key")
                        }
                    }
                }
            }
            .navigationTitle("Multimodal Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showAPIKeySheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        MultimodalConfig.apiKey = apiKeyInput
                        showAPIKeySheet = false
                    }
                    .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Telemetry Overlay (T003)
    
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
