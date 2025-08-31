import SwiftUI
import AVFoundation

struct ExerciseTrackingView: View {
    @StateObject private var yoloManager = YOLOExerciseManager()
    @StateObject private var cameraManager = CameraManager()
    @State private var selectedExercise: YOLOExerciseReference?
    @State private var showingExerciseSelector = false
    @State private var isTracking = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Camera Preview
                CameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                
                // Overlay UI
                VStack {
                    // Top Status Bar
                    topStatusBar
                    
                    Spacer()
                    
                    // Bottom Controls
                    bottomControls
                }
                .padding()
                
                // Exercise Selection Sheet
                .sheet(isPresented: $showingExerciseSelector) {
                    ExerciseSelectorView(yoloManager: yoloManager) { exercise in
                        selectedExercise = exercise
                        showingExerciseSelector = false
                    }
                }
                
                // Session Stats Overlay
                if let session = yoloManager.currentSession, session.isActive {
                    sessionStatsOverlay
                }
            }
        }
        .onAppear {
            cameraManager.startSession()
        }
        .onDisappear {
            cameraManager.stopSession()
        }
    }
    
    private var topStatusBar: some View {
        HStack {
            // Exercise Info
            VStack(alignment: .leading) {
                if let exercise = selectedExercise {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("Phase \(yoloManager.currentSession?.currentPhase ?? 0 + 1)")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                } else {
                    Text("Select Exercise")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            // Form Score
            if let session = yoloManager.currentSession {
                FormScoreView(score: session.formScore)
            }
        }
        .padding()
        .background(Color.black.opacity(0.6))
        .cornerRadius(12)
    }
    
    private var bottomControls: some View {
        HStack(spacing: 20) {
            // Exercise Selection Button
            Button(action: {
                showingExerciseSelector = true
            }) {
                Image(systemName: "list.bullet")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.blue)
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Start/Stop Button
            Button(action: {
                if isTracking {
                    stopTracking()
                } else {
                    startTracking()
                }
            }) {
                Image(systemName: isTracking ? "stop.fill" : "play.fill")
                    .font(.title)
                    .foregroundColor(.white)
                    .frame(width: 70, height: 70)
                    .background(isTracking ? Color.red : Color.green)
                    .clipShape(Circle())
            }
            .disabled(selectedExercise == nil)
            
            Spacer()
            
            // Settings Button
            Button(action: {
                // Open settings
            }) {
                Image(systemName: "gear")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.gray)
                    .clipShape(Circle())
            }
        }
    }
    
    private var sessionStatsOverlay: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                VStack(spacing: 12) {
                    // Rep Counter
                    if let session = yoloManager.currentSession {
                        VStack {
                            Text("\(session.repCount)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                            Text("REPS")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        
                        // Duration
                        VStack {
                            Text(formatDuration(session.sessionDuration))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            Text("TIME")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                    }
                }
                .padding(.trailing)
            }
            
            Spacer()
        }
    }
    
    private func startTracking() {
        guard let exercise = selectedExercise else { return }
        
        yoloManager.startExerciseSession(with: exercise)
        isTracking = true
        // Camera runs continuously; integrate pose pipeline later
    }
    
    private func stopTracking() {
        yoloManager.endCurrentSession()
        isTracking = false
        // Camera remains active while view is visible
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Form Score View

struct FormScoreView: View {
    let score: Double
    
    private var scoreColor: Color {
        if score >= 0.8 { return .green }
        else if score >= 0.6 { return .yellow }
        else { return .red }
    }
    
    var body: some View {
        VStack {
            Text("\(Int(score * 100))%")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(scoreColor)
            Text("FORM")
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
    }
}


#Preview {
    ExerciseTrackingView()
}
