import AVFoundation
import SwiftUI

/// Manages camera authorization and the AVCaptureSession lifecycle.
@Observable
final class CameraManager {
    
    // MARK: - Authorization State
    
    enum CameraStatus: Equatable {
        case unconfigured
        case unauthorized
        case ready
        case unavailable
        case failed(String)
    }
    
    // MARK: - Properties
    
    var status: CameraStatus = .unconfigured
    let captureSession = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.testapp.camera.sessionQueue")
    private var isConfigured = false
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Permissions & Setup
    
    /// Requests camera permission if needed and sets up the capture session.
    func requestAccessAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupAndStartSession()
                    } else {
                        self?.status = .unauthorized
                    }
                }
            }
        case .denied, .restricted:
            status = .unauthorized
        @unknown default:
            status = .unauthorized
        }
    }
    
    // MARK: - Session Configuration
    
    private func setupAndStartSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.isConfigured {
                self.startSessionRunning()
                DispatchQueue.main.async {
                    self.status = .ready
                }
                return
            }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            // Query for back camera, fallback to any available video device
            let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video)
            
            guard let camera = camera else {
                DispatchQueue.main.async {
                    self.status = .unavailable
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            do {
                let input = try AVCaptureDeviceInput(device: camera)
                if self.captureSession.canAddInput(input) {
                    self.captureSession.addInput(input)
                } else {
                    DispatchQueue.main.async {
                        self.status = .failed("Cannot add camera input to session.")
                    }
                    self.captureSession.commitConfiguration()
                    return
                }
            } catch {
                DispatchQueue.main.async {
                    self.status = .failed(error.localizedDescription)
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            self.captureSession.commitConfiguration()
            self.isConfigured = true
            self.startSessionRunning()
            
            DispatchQueue.main.async {
                self.status = .ready
            }
        }
    }
    
    // MARK: - Session Lifecycle
    
    private func startSessionRunning() {
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }
}
