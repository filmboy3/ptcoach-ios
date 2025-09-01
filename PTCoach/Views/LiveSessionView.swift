import SwiftUI
import AVFoundation
import CoreVideo
import CoreMedia
import AudioToolbox
import UIKit

#if targetEnvironment(simulator)
import Foundation
#endif

struct LiveSessionView: View {
    let exerciseType: ExerciseType
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var sessionManager = SessionManager()
    // @StateObject private var integratedProcessor = IntegratedExerciseProcessor()
    @State private var showTestingInterface = false
    
    var body: some View {
        ZStack {
            // Camera preview or simulator placeholder
            #if targetEnvironment(simulator)
            // Simulator with network camera option
            Rectangle()
                .fill(Color.black)
                .overlay(
                    VStack {
                        Image(systemName: "iphone")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        Text("Network Camera")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text("Connect phone camera")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Button("Connect Phone") {
                            // TODO: Implement network camera connection
                            print("📱 Connecting to phone camera...")
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        
                        Spacer()
                        
                        // Enhanced Testing Interface Toggle
                        HStack {
                            Button(showTestingInterface ? "Hide Testing" : "Show Testing") {
                                showTestingInterface.toggle()
                            }
                            .padding(8)
                            .background(Color.purple.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            .font(.caption)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // Bottom controls
                        HStack {
                            Button("Back") {
                                // Navigation handled by NavigationView
                            }
                            .padding()
                            .background(Color.gray.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            
                            Spacer()
                            
                            Text(sessionManager.feedbackMessage)
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue.opacity(0.8))
                                .cornerRadius(8)
                            
                            Spacer()
                            
                            Button("Reset") {
                                sessionManager.reset()
                                // integratedProcessor.reset()
                            }
                            .padding()
                            .background(Color.red.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding()
                    }
                )
                .ignoresSafeArea()
            
            #else
            CameraPreview(session: cameraManager.session)
                .ignoresSafeArea()
            #endif
            
            // Framing guide overlay
            FramingOverlay(ok: sessionManager.hasRequiredJoints)
            
            // Landmarks debug overlay (small dots)
            LandmarksOverlay(landmarks: sessionManager.landmarks)
            
            // Overlay UI
            VStack {
                // Developer Debug Panel
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔧 DEVELOPER DEBUG")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.yellow)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Exercise: \(exerciseTitle)")
                            Text("Reps: \(sessionManager.repCount) | State: \(sessionManager.inFlexion ? "FLEXION" : "EXTENSION")")
                            Text("Angle: \(String(format: "%.1f", sessionManager.currentAngle))° | Max: \(String(format: "%.1f", sessionManager.maxAngle))°")
                            Text("Raw: \(String(format: "%.1f", sessionManager.rawAngle))° | Vel: \(String(format: "%.2f", sessionManager.angleVelocity))°/s")
                            Text("Thresholds: Enter<\(sessionManager.enterThreshold)° | Exit>\(sessionManager.exitThreshold)°")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Landmarks: \(sessionManager.landmarkCount)")
                            Text("Quality: \(String(format: "%.1f", sessionManager.poseQuality))")
                            Text("Required Joints: \(sessionManager.hasRequiredJoints ? "✅" : "❌")")
                            Text("Frame: \(sessionManager.frameCount)")
                            Text(String(format: "FPS: %.1f", sessionManager.fps))
                            Text(String(format: "Inference: %.1f ms", sessionManager.inferenceMs))
                            Text("Last Rep: \(sessionManager.lastRepText)")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.8))
                .cornerRadius(8)
                
                Spacer()
                
                // Pose Setup Guide
                if !sessionManager.hasRequiredJoints {
                    VStack {
                        Text("📍 POSE SETUP REQUIRED")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.red)
                        
                        Text("Position yourself so the camera can see:")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("• Your full body from head to feet")
                            Text("• Both hips, knees, and ankles clearly")
                            Text("• Stand 6-8 feet from camera")
                            Text("• Ensure good lighting")
                            if !sessionManager.missingJointsText.isEmpty {
                                Text("Missing: \(sessionManager.missingJointsText)")
                                    .font(.caption2)
                            }
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.red.opacity(0.8))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                
                // Feedback panel
                VStack {
                    Text(sessionManager.feedbackMessage)
                        .font(.title2)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(sessionManager.hasRequiredJoints ? Color.blue.opacity(0.8) : Color.orange.opacity(0.8))
                        .cornerRadius(10)
                }
                .padding()
                
                // Enhanced Testing Interface Toggle
                HStack {
                    Button(showTestingInterface ? "Hide Testing" : "Show Testing") {
                        showTestingInterface.toggle()
                    }
                    .padding(8)
                    .background(Color.purple.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .font(.caption)
                    
                    Spacer()
                }
                .padding(.horizontal)
            }
            
            // Enhanced Testing Interface Overlay
            // if showTestingInterface {
            //     VStack {
            //         Spacer()
            //         ExerciseTestingView(integratedProcessor: integratedProcessor)
            //             .background(Color.black.opacity(0.9))
            //             .cornerRadius(12)
            //             .padding()
            //     }
            //     .transition(.move(edge: .bottom))
            //     .animation(.easeInOut, value: showTestingInterface)
            // }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            sessionManager.startSession(for: exerciseType)
            // integratedProcessor.configureExercise(exerciseType)
            // Connect camera frames to both processors
            cameraManager.setFrameHandler { pixelBuffer in
                Task { @MainActor in
                    sessionManager.enqueueFrame(pixelBuffer)
                    // await integratedProcessor.processFrame(pixelBuffer)
                }
            }
            // Start camera session (uses its own background queue internally)
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
            sessionManager.endSession()
        }
    }
    
    private var exerciseTitle: String {
        return exerciseType.rawValue
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.frame = view.frame
        previewLayer.videoGravity = .resizeAspect // Zoom out more for tall users
        view.layer.addSublayer(previewLayer)
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Framing Overlay View
struct FramingOverlay: View {
    let ok: Bool
    private let cornerRadius: CGFloat = 12
    private let inset: CGFloat = 24
    
    var body: some View {
        GeometryReader { proxy in
            let frame = CGRect(
                x: inset,
                y: inset,
                width: max(0, proxy.size.width - inset * 2),
                height: max(0, proxy.size.height - inset * 2)
            )
            
            // Dimmed outside area with a punched-out rounded rect (even-odd fill)
            Path { path in
                path.addRect(CGRect(origin: .zero, size: proxy.size))
                let cutout = Path(roundedRect: frame, cornerRadius: cornerRadius)
                path.addPath(cutout)
            }
            .fill(Color.black.opacity(0.45), style: FillStyle(eoFill: true))
            
            // Highlight box
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(ok ? Color.green : Color.red, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Landmarks Overlay View
struct LandmarksOverlay: View {
    let landmarks: [Landmark]
    private let dotSize: CGFloat = 6
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                ForEach(0..<(landmarks.count), id: \.self) { i in
                    let lm = landmarks[i]
                    if lm.isVisible {
                        Circle()
                            .fill(Color.cyan.opacity(0.9))
                            .frame(width: dotSize, height: dotSize)
                            .position(x: CGFloat(lm.x) * proxy.size.width,
                                      y: CGFloat(lm.y) * proxy.size.height)
                    }
                }
            }
            // Mirror horizontally to better match front camera preview
            .scaleEffect(x: -1, y: 1, anchor: .center)
        }
        .allowsHitTesting(false)
    }
}



@MainActor
class SessionManager: ObservableObject, @unchecked Sendable {
    @Published var repCount = 0
    @Published var currentAngle: CGFloat = 0
    @Published var maxAngle: CGFloat = 0
    @Published var feedbackMessage = "Get ready..."
    
    // Debug properties
    @Published var landmarkCount = 0
    @Published var poseQuality: Float = 0.0
    @Published var hasRequiredJoints = false
    @Published var frameCount = 0
    @Published var inFlexion = false
    @Published var fps: Double = 0
    @Published var inferenceMs: Double = 0
    @Published var rawAngle: CGFloat = 0
    @Published var angleVelocity: CGFloat = 0
    @Published var lastRepText: String = "-"
    @Published var missingJointsText: String = ""
    @Published var landmarks: [Landmark] = []
    
    // Expose thresholds for debug display (dynamic per exercise)
    var enterThreshold: CGFloat { angleEngine.debugThresholds.enter }
    var exitThreshold: CGFloat { angleEngine.debugThresholds.exit }
    
    private var exerciseType: ExerciseType = .kneeFlexion
    private var angleEngine = AngleEngine()
    #if targetEnvironment(simulator)
    private let poseProvider: PoseProvider = MockPoseProvider()
    private var timer: Timer?
    #else
    private let poseProvider: PoseProvider = CoreMLPoseProvider()
    #endif
    
    private var lastUpdateTime: CFAbsoluteTime = 0
    private var isProcessingFrame = false
    private var previousRepCount = 0
    private let haptics = UINotificationFeedbackGenerator()
    
    func startSession(for type: ExerciseType) {
        exerciseType = type
        repCount = 0
        currentAngle = 0
        maxAngle = 0
        frameCount = 0
        feedbackMessage = "Position yourself in the camera view"
        
        // Start angle engine
        angleEngine.startSession(for: type)
        lastUpdateTime = 0
        previousRepCount = 0
        haptics.prepare()
        
        #if targetEnvironment(simulator)
        // Drive mock provider with a timer on simulator
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.simulateTick()
        }
        #endif
        print("🏁 SESSION STARTED for \(type)")
    }
    
    func endSession() {
        isProcessingFrame = false
        #if targetEnvironment(simulator)
        timer?.invalidate()
        timer = nil
        #endif
    }
    
    func enqueueFrame(_ pixelBuffer: CVPixelBuffer) {
        if isProcessingFrame { return }
        isProcessingFrame = true
        let start = CFAbsoluteTimeGetCurrent()
        Task {
            let landmarks = await poseProvider.detectPose(pixelBuffer: pixelBuffer)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            await MainActor.run {
                self.inferenceMs = elapsedMs
                self.frameCount += 1
                self.landmarkCount = landmarks.count
                self.poseQuality = Geometry.poseQuality(landmarks: landmarks)
                self.hasRequiredJoints = self.requiredJointsSatisfied(landmarks: landmarks)
                self.missingJointsText = self.missingJoints(landmarks: landmarks).joined(separator: ", ")
                self.landmarks = landmarks
                
                // Process through angle engine
                self.angleEngine.process(landmarks: landmarks)
                
                // Update UI from angle engine
                self.repCount = self.angleEngine.repCount
                self.currentAngle = self.angleEngine.currentAngle
                self.maxAngle = self.angleEngine.maxAngle
                self.feedbackMessage = self.angleEngine.feedbackMessage
                self.inFlexion = self.angleEngine.inFlexion
                self.rawAngle = self.angleEngine.rawAngle
                self.angleVelocity = self.angleEngine.angleVelocity
                
                // FPS calculation
                let now = CFAbsoluteTimeGetCurrent()
                if self.lastUpdateTime > 0 {
                    let dt = now - self.lastUpdateTime
                    if dt > 0 { self.fps = 1.0 / dt }
                }
                self.lastUpdateTime = now
                
                // Last rep timestamp text update
                if self.repCount > self.previousRepCount {
                    let df = DateFormatter()
                    df.timeStyle = .medium
                    self.lastRepText = df.string(from: Date())
                    // Play chime + haptic
                    self.playRepChime()
                }
                self.previousRepCount = self.repCount
                
                print("📱 UI UPDATE - Reps: \(self.repCount) | Angle: \(String(format: "%.1f", self.currentAngle))° | FPS: \(String(format: "%.1f", self.fps)) | Inference: \(String(format: "%.1f", self.inferenceMs)) ms")
                
                self.isProcessingFrame = false
            }
        }
    }
    
    #if targetEnvironment(simulator)
    func simulateTick() {
        if isProcessingFrame { return }
        isProcessingFrame = true
        let start = CFAbsoluteTimeGetCurrent()
        Task {
            let landmarks = await poseProvider.detectPose(pixelBuffer: nil)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
            await MainActor.run {
                self.inferenceMs = elapsedMs
                self.frameCount += 1
                self.landmarkCount = landmarks.count
                self.poseQuality = Geometry.poseQuality(landmarks: landmarks)
                self.hasRequiredJoints = self.requiredJointsSatisfied(landmarks: landmarks)
                self.missingJointsText = self.missingJoints(landmarks: landmarks).joined(separator: ", ")
                self.landmarks = landmarks
                
                // Process through angle engine
                self.angleEngine.process(landmarks: landmarks)
                
                // Update UI from angle engine
                self.repCount = self.angleEngine.repCount
                self.currentAngle = self.angleEngine.currentAngle
                self.maxAngle = self.angleEngine.maxAngle
                self.feedbackMessage = self.angleEngine.feedbackMessage
                self.inFlexion = self.angleEngine.inFlexion
                self.rawAngle = self.angleEngine.rawAngle
                self.angleVelocity = self.angleEngine.angleVelocity
                
                // FPS calculation
                let now = CFAbsoluteTimeGetCurrent()
                if self.lastUpdateTime > 0 {
                    let dt = now - self.lastUpdateTime
                    if dt > 0 { self.fps = 1.0 / dt }
                }
                self.lastUpdateTime = now
                
                // Last rep timestamp text update
                if self.repCount > self.previousRepCount {
                    let df = DateFormatter()
                    df.timeStyle = .medium
                    self.lastRepText = df.string(from: Date())
                    // Play chime + haptic
                    self.playRepChime()
                }
                self.previousRepCount = self.repCount
                
                print("📱 UI UPDATE (sim) - Reps: \(self.repCount) | Angle: \(String(format: "%.1f", self.currentAngle))° | FPS: \(String(format: "%.1f", self.fps)) | Inference: \(String(format: "%.1f", self.inferenceMs)) ms")
                
                self.isProcessingFrame = false
            }
        }
    }
    #endif
    
    private func playRepChime() {
        DispatchQueue.main.async {
            // Haptic feedback
            self.haptics.notificationOccurred(.success)
            
            // System sound - try multiple IDs for better compatibility
            AudioServicesPlaySystemSound(SystemSoundID(1057)) // Glass sound
            
            // Fallback sounds if 1057 doesn't work
            // AudioServicesPlaySystemSound(SystemSoundID(1016)) // SMS received
            // AudioServicesPlaySystemSound(SystemSoundID(1013)) // SMS sent
            
            print("🔊 CHIME PLAYED - Rep increment sound triggered")
        }
    }
    
    private func requiredJointsSatisfied(landmarks: [Landmark]) -> Bool {
        switch exerciseType {
        case .kneeFlexion, .sitToStand, .ankleFlexion, .hipFlexion:
            // Allow temporary occlusion during movement - require at least 4 of 6 key joints
            let keyJoints = [11, 12, 13, 14, 15, 16] // hips, knees, ankles
            let visibleCount = keyJoints.compactMap { idx in
                idx < landmarks.count && landmarks[idx].isVisible ? 1 : nil
            }.count
            return visibleCount >= 4 // More lenient for occlusion
        case .shoulderFlexion, .bicepCurl, .lateralArmRaise:
            // Allow temporary occlusion - require at least 5 of 8 key joints
            let keyJoints = [5, 6, 7, 8, 9, 10, 11, 12] // shoulders, elbows, wrists, hips
            let visibleCount = keyJoints.compactMap { idx in
                idx < landmarks.count && landmarks[idx].isVisible ? 1 : nil
            }.count
            return visibleCount >= 5 // More lenient for occlusion
        case .neckFlexion:
            // Neck exercises need head and shoulder landmarks
            let keyJoints = [0, 5, 6] // nose, shoulders
            let visibleCount = keyJoints.compactMap { idx in
                idx < landmarks.count && landmarks[idx].isVisible ? 1 : nil
            }.count
            return visibleCount >= 2
        }
    }
    
    private func requiredIndices() -> [Int] {
        switch exerciseType {
        case .kneeFlexion, .sitToStand, .ankleFlexion, .hipFlexion:
            return [11, 12, 13, 14, 15, 16]
        case .shoulderFlexion, .bicepCurl, .lateralArmRaise:
            return [5, 6, 7, 8, 9, 10, 11, 12]
        case .neckFlexion:
            return [0, 5, 6]
        }
    }
    
    private func missingJoints(landmarks: [Landmark]) -> [String] {
        var missing: [String] = []
        for idx in requiredIndices() {
            if idx >= landmarks.count || !landmarks[idx].isVisible {
                if let jt = JointType.fromIndex(idx) {
                    missing.append(jt.name)
                } else {
                    missing.append("joint_\(idx)")
                }
            }
        }
        return missing
    }
}

#Preview {
    LiveSessionView(exerciseType: .kneeFlexion)
}
