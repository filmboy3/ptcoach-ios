import SwiftUI
import AVFoundation
import Vision
import CoreML

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard Tab
            DashboardPlaceholderView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            // Exercise Tracking Tab
            TrackingPlaceholderView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Track")
                }
                .tag(1)
            
            // Exercise Library Tab
            LibraryView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Exercises")
                }
                .tag(2)
            
            // Statistics Tab
            StatsPlaceholderView()
                .tabItem {
                    Image(systemName: "chart.bar.fill")
                    Text("Stats")
                }
                .tag(3)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - Placeholder Views

struct DashboardPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "house.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Exercise Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("YOLO exercise tracking integration coming soon!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Features:")
                        .font(.headline)
                    
                    Label("616 YOLO exercises loaded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("Real-time pose tracking", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("Form analysis & rep counting", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    
                    Label("Safety monitoring", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Dashboard")
        }
    }
}

struct TrackingPlaceholderView: View {
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var poseProvider = CoreMLPoseProvider()
    @State private var showingCamera = false
    @State private var cameraPosition: AVCaptureDevice.Position = AVCaptureDevice.Position.front
    @AppStorage("cameraPosition") private var savedCameraPosition = "front"
    @State private var showPermissionAlert = false
    @State private var landmarks: [Landmark] = []
    @State private var poseQuality: Float = 0.0
    @State private var frameCount: Int = 0
    @State private var repCount: Int = 0
    @State private var leftArmFlexed: Bool = false
    @State private var rightArmFlexed: Bool = false
    @State private var bothArmsExtended: Bool = true
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingCamera {
                    // Live Camera Preview with Pose Overlay
                    ZStack {
                        // Camera preview - fullscreen
                        CameraPreviewView(session: cameraManager.session)
                            .ignoresSafeArea()
                        
                        // Pose keypoints overlay - fullscreen
                        PoseOverlayView(landmarks: landmarks)
                            .ignoresSafeArea()
                        
                        // Debug HUD overlay
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Circle()
                                            .fill(cameraManager.isSessionRunning ? Color.green : Color.red)
                                            .frame(width: 12, height: 12)
                                        
                                        Text(cameraManager.isSessionRunning ? "Camera Active" : "Camera Inactive")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    }
                                    
                                    Text("Landmarks: \(landmarks.count)")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Quality: \(String(format: "%.1f", poseQuality))")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    Text("Frames: \(frameCount)")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                    
                                    if landmarks.count > 0 {
                                        let leftElbowAngle = DynamicAngleEngine.shared.calculateElbowAngle(landmarks: landmarks)
                                        let rightElbowAngle = DynamicAngleEngine.shared.calculateRightElbowAngle(landmarks: landmarks)
                                        let repThreshold: CGFloat = 90.0
                                        let bothArmsFlexed = leftElbowAngle > repThreshold && rightElbowAngle > repThreshold
                                        let repStatus = bothArmsFlexed ? "BOTH FLEXED" : "PARTIAL/EXTENDED"
                                        
                                        Text("Reps: \(repCount)")
                                            .font(.title)
                                            .foregroundColor(.cyan)
                                        
                                        Text("Left: \(String(format: "%.1f°", leftElbowAngle))")
                                            .font(.title2)
                                            .foregroundColor(.yellow)
                                        
                                        Text("Right: \(String(format: "%.1f°", rightElbowAngle))")
                                            .font(.title2)
                                            .foregroundColor(.yellow)
                                        
                                        Text("Status: \(repStatus)")
                                            .font(.title2)
                                            .foregroundColor(bothArmsFlexed ? .green : .orange)
                                    }
                                }
                                .padding()
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    
                    // Camera Controls
                    HStack(spacing: 20) {
                        Button("Stop Camera") {
                            cameraManager.stopSession()
                            showingCamera = false
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Switch Camera") {
                            switchCamera()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Status and Debug Info
                    VStack(spacing: 4) {
                        HStack {
                            Circle()
                                .fill(cameraManager.isSessionRunning ? Color.green : Color.red)
                                .frame(width: 8, height: 8)
                            
                            Text(cameraManager.isSessionRunning ? "Camera Active" : "Camera Inactive")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Pose detection debug info
                        HStack {
                            Text("Landmarks: \(landmarks.count)")
                            Text("Quality: \(String(format: "%.1f", poseQuality))")
                            Text("Frames: \(frameCount)")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)
                    
                    Text("Exercise Tracking")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Real-time pose analysis with YOLO dataset")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("Start Camera") {
                        startCamera()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .navigationTitle("Track")
            .alert("Camera Access Needed", isPresented: $showPermissionAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Please enable camera access for PTCoach in Settings > Privacy > Camera.")
            }
            .onAppear {
                cameraPosition = savedCameraPosition == "front" ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
                
                // Initialize bicep curl exercise tracking
                let bicepCurlExercise = YOLOExerciseReference(
                    exerciseId: "bicep_curl",
                    name: "Bicep Curl",
                    category: ["strength"],
                    difficulty: "beginner",
                    bodyOrientation: "standing",
                    cameraAngle: "side_view",
                    phases: [],
                    repDetectionKeypoints: ["left_shoulder", "left_elbow", "left_wrist"],
                    safetyConstraints: ["Keep elbow stationary", "Control the movement"],
                    formCheckpoints: ["Start with arm extended", "Curl to 90+ degrees", "Return to start position"]
                )
                
                // Connect pose detection to camera frames
                cameraManager.setFrameHandler { pixelBuffer in
                    Task {
                        let detectedLandmarks = await poseProvider.detectPose(pixelBuffer: pixelBuffer)
                        await MainActor.run {
                            self.landmarks = detectedLandmarks
                            self.frameCount += 1
                            self.poseQuality = Geometry.poseQuality(landmarks: detectedLandmarks)
                            
                            // Calculate both elbow angles for bicep curl tracking
                            let leftElbowAngle = DynamicAngleEngine.shared.calculateElbowAngle(landmarks: detectedLandmarks)
                            let rightElbowAngle = DynamicAngleEngine.shared.calculateRightElbowAngle(landmarks: detectedLandmarks)
                            
                            // Rep detection for both arms bicep curls
                            let repThreshold: CGFloat = 90.0 // degrees
                            let leftIsFlexed = leftElbowAngle > repThreshold
                            let rightIsFlexed = rightElbowAngle > repThreshold
                            let bothArmsFlexed = leftIsFlexed && rightIsFlexed
                            let bothArmsExtendedNow = leftElbowAngle < 45.0 && rightElbowAngle < 45.0
                            
                            // Rep counting state machine
                            if bothArmsFlexed && !self.leftArmFlexed && !self.rightArmFlexed {
                                // Both arms just flexed from extended position
                                self.leftArmFlexed = true
                                self.rightArmFlexed = true
                                self.bothArmsExtended = false
                            } else if bothArmsExtendedNow && (self.leftArmFlexed || self.rightArmFlexed) {
                                // Both arms returned to extended position after being flexed - complete rep
                                self.repCount += 1
                                self.leftArmFlexed = false
                                self.rightArmFlexed = false
                                self.bothArmsExtended = true
                                
                                // Play sound and haptic feedback
                                DynamicAngleEngine.shared.playRepSound()
                            }
                            
                            // Debug logging with bicep curl info
                            let visibleCount = detectedLandmarks.filter { $0.isVisible }.count
                            let repStatus = bothArmsFlexed ? "BOTH FLEXED" : bothArmsExtendedNow ? "BOTH EXTENDED" : "PARTIAL"
                            print("🔍 BICEP CURL - Frame: \(self.frameCount), Reps: \(self.repCount), Left: \(String(format: "%.1f°", leftElbowAngle)), Right: \(String(format: "%.1f°", rightElbowAngle)), Status: \(repStatus))")
                        }
                    }
                }
            }
        }
    }
    
    private func startCamera() {
        Task {
            await requestCameraPermission()
        }
    }
    
    private func requestCameraPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        
        switch status {
        case .authorized:
            DispatchQueue.main.async {
                self.cameraManager.startSession()
                self.cameraManager.switchCamera(to: self.cameraPosition)
                self.showingCamera = true
            }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: AVMediaType.video)
            if granted {
                DispatchQueue.main.async {
                    self.cameraManager.startSession()
                    self.cameraManager.switchCamera(to: self.cameraPosition)
                    self.showingCamera = true
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.showPermissionAlert = true
            }
        @unknown default:
            break
        }
    }
    
    private func switchCamera() {
        let newPosition: AVCaptureDevice.Position = cameraPosition == AVCaptureDevice.Position.front ? AVCaptureDevice.Position.back : AVCaptureDevice.Position.front
        cameraPosition = newPosition
        savedCameraPosition = newPosition == AVCaptureDevice.Position.front ? "front" : "back"
        
        cameraManager.switchCamera(to: newPosition)
    }
}

struct StatsPlaceholderView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.purple)
                
                Text("Session Statistics")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Track your progress and form improvements")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 12) {
                    StatRow(title: "Total Sessions", value: "0")
                    StatRow(title: "Total Reps", value: "0")
                    StatRow(title: "Average Form Score", value: "N/A")
                    StatRow(title: "Exercises Completed", value: "0")
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
            }
            .padding()
            .navigationTitle("Stats")
        }
    }
}

struct StatRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.blue)
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @AppStorage("cameraPosition") private var cameraPosition = "front"
    @AppStorage("formFeedbackEnabled") private var formFeedbackEnabled = true
    @AppStorage("safetyAlertsEnabled") private var safetyAlertsEnabled = true
    @AppStorage("repCountingEnabled") private var repCountingEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section("Camera Settings") {
                    Picker("Camera Position", selection: $cameraPosition) {
                        Text("Front Camera").tag("front")
                        Text("Back Camera").tag("back")
                    }
                }
                
                Section("Exercise Tracking") {
                    Toggle("Form Feedback", isOn: $formFeedbackEnabled)
                    Toggle("Safety Alerts", isOn: $safetyAlertsEnabled)
                    Toggle("Rep Counting", isOn: $repCountingEnabled)
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("YOLO Dataset")
                        Spacer()
                        Text("616 exercises")
                            .foregroundColor(.secondary)
                    }
                    
                    
                    Button("Contact Support") {
                        // Handle support contact
                    }
                    
                    Button("Privacy Policy") {
                        // Show privacy policy
                    }
                    
                    Button("Terms of Service") {
                        // Show terms of service
                    }
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
