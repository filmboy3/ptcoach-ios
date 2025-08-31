import AVFoundation
import SwiftUI
import Vision

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isSessionRunning = false
    
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private var videoOutput = AVCaptureVideoDataOutput()
    private var currentPixelBuffer: CVPixelBuffer?
    private var currentInput: AVCaptureDeviceInput?
    
    var onFrameProcessed: ((CVPixelBuffer) -> Void)?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Add video input
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else {
                print("Failed to setup camera input")
                self.session.commitConfiguration()
                return
            }
            
            self.session.addInput(videoInput)
            self.currentInput = videoInput
            
            // Configure video output
            self.videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.queue"))
            self.videoOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            
            if self.session.canAddOutput(self.videoOutput) {
                self.session.addOutput(self.videoOutput)
            }
            
            // Set session preset for better performance
            if self.session.canSetSessionPreset(.medium) {
                self.session.sessionPreset = .medium
            }
            
            self.session.commitConfiguration()
        }
    }
    
    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check authorization first
            let authStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
            guard authStatus == .authorized else {
                print("Camera access not authorized")
                return
            }
            
            if !self.session.isRunning {
                print("Starting camera session...")
                self.session.startRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = self.session.isRunning
                    print("Camera session running: \(self.session.isRunning)")
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    func getCurrentFrame() -> CVPixelBuffer? {
        return currentPixelBuffer
    }
    
    // Convenience API to set the frame handler (used by LiveSessionView)
    func setFrameHandler(_ handler: @escaping (CVPixelBuffer) -> Void) {
        onFrameProcessed = handler
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Remove current input
            if let currentInput = self.currentInput {
                self.session.removeInput(currentInput)
            }
            
            // Add new input with desired position
            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else {
                print("Failed to switch camera to position: \(position)")
                self.session.commitConfiguration()
                return
            }
            
            self.session.addInput(videoInput)
            self.currentInput = videoInput
            
            self.session.commitConfiguration()
            
            print("Successfully switched camera to position: \(position)")
        }
    }
    
    // Simulate keypoints for testing
    func simulateKeypoints() -> [Landmark] {
        let jointTypes = JointType.allCases
        return jointTypes.enumerated().map { index, jointType in
            // Create realistic pose positions
            let (x, y) = getSimulatedPosition(for: jointType)
            return Landmark(
                x: x,
                y: y,
                confidence: Float.random(in: 0.7...0.95),
                jointType: jointType
            )
        }
    }
    
    private func getSimulatedPosition(for joint: JointType) -> (Float, Float) {
        // Simulate a standing person pose
        switch joint {
        case .nose: return (0.5, 0.15)
        case .leftEye: return (0.48, 0.12)
        case .rightEye: return (0.52, 0.12)
        case .leftEar: return (0.45, 0.15)
        case .rightEar: return (0.55, 0.15)
        case .leftShoulder: return (0.4, 0.3)
        case .rightShoulder: return (0.6, 0.3)
        case .leftElbow: return (0.35, 0.45)
        case .rightElbow: return (0.65, 0.45)
        case .leftWrist: return (0.3, 0.6)
        case .rightWrist: return (0.7, 0.6)
        case .leftHip: return (0.42, 0.65)
        case .rightHip: return (0.58, 0.65)
        case .leftKnee: return (0.4, 0.8)
        case .rightKnee: return (0.6, 0.8)
        case .leftAnkle: return (0.38, 0.95)
        case .rightAnkle: return (0.62, 0.95)
        }
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        currentPixelBuffer = pixelBuffer
        onFrameProcessed?(pixelBuffer)
    }
}
