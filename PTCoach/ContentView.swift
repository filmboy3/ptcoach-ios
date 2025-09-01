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
    @StateObject private var exerciseProcessor: ExerciseProcessor
    @State private var showingCamera = false
    @State private var cameraPosition: AVCaptureDevice.Position = AVCaptureDevice.Position.front
    @AppStorage("cameraPosition") private var savedCameraPosition = "front"
    @State private var showPermissionAlert = false
    @State private var landmarks: [Landmark] = []
    @State private var selectedExercise = ExerciseLibrary.shared.availableExercises[0]
    @State private var showExerciseSelector = false
    @State private var poseQuality: Float = 0.0
    @State private var frameCount: Int = 0
    @State private var repCount: Int = 0
    
    init() {
        let initialExercise = ExerciseLibrary.shared.availableExercises[0]
        self._exerciseProcessor = StateObject(wrappedValue: ExerciseProcessor(exercise: initialExercise))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingCamera {
                    // Live Camera Preview with Pose Overlay
                    GeometryReader { geometry in
                        ZStack {
                            // Camera preview - properly sized
                            CameraPreviewView(session: cameraManager.session)
                                .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                                .clipped()
                            
                            // Pose keypoints overlay
                            PoseOverlayView(landmarks: landmarks)
                                .frame(width: geometry.size.width, height: geometry.size.height * 0.75)
                                .clipped()
                            
                            // Clean HUD overlay
                            VStack {
                                // Top status bar
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(cameraManager.isSessionRunning ? Color.green : Color.red)
                                            .frame(width: 8, height: 8)
                                        
                                        Text(cameraManager.isSessionRunning ? "Active" : "Inactive")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(20)
                                    
                                    Spacer()
                                    
                                    // Form score
                                    if let results = exerciseProcessor.processingResults {
                                        HStack(spacing: 4) {
                                            Text("\(Int(results.formScore))%")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(formScoreColor(results.formScore))
                                            Text("Form")
                                                .font(.caption2)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.8))
                                        .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.top, 8)
                                
                                Spacer()
                                
                                // Bottom HUD
                                HStack {
                                    // Rep counter
                                    VStack(spacing: 2) {
                                        Text("\(exerciseProcessor.processingResults?.repCount ?? 0)")
                                            .font(.title)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        Text("REPS")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(12)
                                    
                                    Spacer()
                                    
                                    // Exercise state
                                    if let results = exerciseProcessor.processingResults {
                                        Text(results.state.uppercased())
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.blue.opacity(0.8))
                                            .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                            }
                        }
                    }
                    
                    // Simplified HUD with exercise info and rep count
                    VStack(alignment: .leading, spacing: 12) {
                        // Exercise selector button
                        Button(action: {
                            showExerciseSelector = true
                        }) {
                            HStack {
                                Text(selectedExercise.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Image(systemName: "chevron.down")
                            }
                            .foregroundColor(.white)
                        }
                        
                        // Exercise description
                        Text(selectedExercise.description)
                            .font(.body)
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // Rep counter
                        HStack {
                            Text("Reps: \(repCount)")
                                .font(.title)
                                .fontWeight(.heavy)
                                .foregroundColor(.green)
                            Spacer()
                            Text(selectedExercise.category.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(8)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(12)
                    .foregroundColor(.white)
                    .padding(.top, 60)
                    .padding(.horizontal, 20)
                    
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
                    // Camera setup screen with exercise selection
                    VStack(spacing: 30) {
                        Text("PTCoach")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Exercise Tracking & Form Analysis")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        // Exercise selection before starting camera
                        VStack(spacing: 15) {
                            Text("Select Exercise:")
                                .font(.headline)
                            
                            Button(action: {
                                showExerciseSelector = true
                            }) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(selectedExercise.name)
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                        Text(selectedExercise.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .foregroundColor(.primary)
                        }
                        
                        Button("Start Camera") {
                            startCamera()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                }
            }
            .padding()
            .navigationTitle("Track")
            .sheet(isPresented: $showExerciseSelector) {
                ExerciseSelectionView(selectedExercise: $selectedExercise) { newExercise in
                    selectedExercise = newExercise
                    exerciseProcessor.reset()
                    // Note: In a full implementation, we'd create a new processor with the new exercise
                }
            }
            .onAppear {
                cameraPosition = savedCameraPosition == "front" ? AVCaptureDevice.Position.front : AVCaptureDevice.Position.back
                // Connect pose detection to camera frames
                cameraManager.setFrameHandler { pixelBuffer in
                    Task {
                        let detectedLandmarks = await poseProvider.detectPose(pixelBuffer: pixelBuffer)
                        await MainActor.run {
                            self.landmarks = detectedLandmarks
                            self.frameCount += 1
                            self.poseQuality = Geometry.poseQuality(landmarks: detectedLandmarks)
                            
                            // Process frame through robust exercise processor
                            let results = self.exerciseProcessor.processFrame(landmarks: detectedLandmarks)
                            
                            // Update rep count from processor
                            self.repCount = results.repCount
                            
                            // Handle rep completion
                            if results.repCompleted {
                                DynamicAngleEngine.shared.playRepSound()
                                print("✅ REP COMPLETED! Total: \(results.repCount)")
                                print("📊 Form Score: \(results.formScore)%")
                                
                                // Print feedback if available
                                if !results.formFeedback.isEmpty {
                                    print("💡 Form Feedback: \(results.formFeedback.joined(separator: ", "))")
                                }
                            }
                            
                            // Handle safety warnings
                            if !results.safetyWarnings.isEmpty {
                                print("⚠️ Safety: \(results.safetyWarnings.joined(separator: ", "))")
                            }
                            
                            // Debug output every 30 frames
                            if results.frame % 30 == 0 {
                                print("🔄 Frame \(results.frame): State=\(results.state), Angle=\(Int(results.primaryAngle))°, Score=\(Int(results.formScore))%")
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func formScoreColor(_ score: Float) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .orange }
        else { return .red }
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
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.cameraManager.startSession()
                self.cameraManager.switchCamera(to: self.cameraPosition)
                self.showingCamera = true
            }
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: AVMediaType.video)
            if granted {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.cameraManager.startSession()
                    self.cameraManager.switchCamera(to: self.cameraPosition)
                    self.showingCamera = true
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async { [weak self] in
                self?.showPermissionAlert = true
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
