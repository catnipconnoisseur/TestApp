import AVFoundation
import SwiftUI

/// Manages camera authorization and the AVCaptureSession lifecycle.
@Observable
final class CameraManager {
    
    // MARK: - Authorization State
    
    enum CameraStatus {
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
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Permissions & Setup
    
    /// Requests camera permission if needed and sets up the capture session.
    func requestAccessAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            status = .ready
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.status = .ready
                        self?.setupSession()
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
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .photo
            
            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
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
            self.startSession()
        }
    }
    
    // MARK: - Session Lifecycle
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
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
