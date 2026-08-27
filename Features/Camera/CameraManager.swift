import AVFoundation
import CoreImage
import SwiftUI
import UIKit

/// Manages camera authorization, AVCaptureSession lifecycle, video frame delivery to Vision, and on-demand frame capture.
@Observable
final class CameraManager: NSObject {
    
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
    var latestResult: RecognitionResult = RecognitionResult()
    
    let captureSession = AVCaptureSession()
    
    private let sessionQueue = DispatchQueue(label: "com.testapp.camera.sessionQueue")
    private let videoOutputQueue = DispatchQueue(label: "com.testapp.camera.videoOutputQueue", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let visionService = VisionService()
    private let ciContext = CIContext()
    
    private var isConfigured = false
    private var latestPixelBuffer: CVPixelBuffer?
    private let bufferLock = NSLock()
    
    // MARK: - Initialization
    
    override init() {
        super.init()
    }
    
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
                
                // Configure Video Data Output for Vision processing
                if self.captureSession.canAddOutput(self.videoOutput) {
                    self.videoOutput.alwaysDiscardsLateVideoFrames = true
                    self.videoOutput.videoSettings = [
                        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                    ]
                    self.videoOutput.setSampleBufferDelegate(self, queue: self.videoOutputQueue)
                    self.captureSession.addOutput(self.videoOutput)
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
    
    // MARK: - On-Demand Still Frame Capture (T004)
    
    /// Captures the most recent camera frame as compressed JPEG data for multimodal inspection.
    func captureCurrentFrameJPEG(compressionQuality: CGFloat = 0.75) -> Data? {
        bufferLock.lock()
        guard let pixelBuffer = latestPixelBuffer else {
            bufferLock.unlock()
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else {
            bufferLock.unlock()
            return nil
        }
        bufferLock.unlock()
        
        // Render in portrait orientation matching physical device holding angle
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)
        return image.jpegData(compressionQuality: compressionQuality)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        bufferLock.lock()
        self.latestPixelBuffer = pixelBuffer
        bufferLock.unlock()
        
        visionService.processFrame(pixelBuffer) { [weak self] result in
            self?.latestResult = result
        }
    }
}
