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
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingCamera {
                    // Live Camera Preview with Pose Overlay
                    ZStack {
                        CameraPreviewView(session: cameraManager.session)
                            .frame(height: 400)
                            .cornerRadius(12)
                            .clipped()
                        
                        // Pose keypoints overlay
                        PoseOverlayView(landmarks: landmarks)
                            .frame(height: 400)
                            .cornerRadius(12)
                            .clipped()
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(landmarks.isEmpty ? Color.red : Color.green, lineWidth: 2)
                    )
                    
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
                
                // Connect pose detection to camera frames
                cameraManager.setFrameHandler { pixelBuffer in
                    Task {
                        let detectedLandmarks = await poseProvider.detectPose(pixelBuffer: pixelBuffer)
                        await MainActor.run {
                            self.landmarks = detectedLandmarks
                            self.frameCount += 1
                            self.poseQuality = Geometry.poseQuality(landmarks: detectedLandmarks)
                            
                            // Debug logging
                            let visibleCount = detectedLandmarks.filter { $0.isVisible }.count
                            print("🔍 POSE DETECTION - Frame: \(self.frameCount), Visible landmarks: \(visibleCount)/\(detectedLandmarks.count), Quality: \(String(format: "%.1f", self.poseQuality))")
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
                }
                
                Section("Support") {
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
