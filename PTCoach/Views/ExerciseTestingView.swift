import SwiftUI

/// Testing interface for pose providers and exercise implementations
struct ExerciseTestingView: View {
    @ObservedObject var integratedProcessor: IntegratedExerciseProcessor
    @State private var selectedProvider: PoseProviderType = .yolo
    @State private var selectedExercise: ExerciseType = .bicepCurl
    @State private var showingPerformanceTest = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            Text("Exercise Testing Suite")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top)
            
            // Pose Provider Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Pose Detection Method")
                    .font(.headline)
                
                Picker("Pose Provider", selection: $selectedProvider) {
                    ForEach(PoseProviderType.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .onChange(of: selectedProvider) { provider in
                    integratedProcessor.switchToPoseProvider(provider)
                }
            }
            
            // Exercise Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Exercise Type")
                    .font(.headline)
                
                Picker("Exercise", selection: $selectedExercise) {
                    Text("Bicep Curl").tag(ExerciseType.bicepCurl)
                    Text("Knee Flexion").tag(ExerciseType.kneeFlexion)
                    Text("Lateral Arm Raise").tag(ExerciseType.lateralArmRaise)
                    Text("Shoulder Flexion").tag(ExerciseType.shoulderFlexion)
                }
                .pickerStyle(MenuPickerStyle())
                .onChange(of: selectedExercise) { exercise in
                    integratedProcessor.configureExercise(exercise)
                }
            }
            
            // Quick Test Buttons
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Tests")
                    .font(.headline)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    TestButton(title: "Test Bicep Curls", icon: "💪") {
                        integratedProcessor.testBicepCurls()
                    }
                    
                    TestButton(title: "Test Knee Flexion", icon: "🦵") {
                        integratedProcessor.testKneeFlexion()
                    }
                    
                    TestButton(title: "Test Arm Raises", icon: "🙋‍♂️") {
                        integratedProcessor.testLateralArmRaise()
                    }
                    
                    TestButton(title: "Test All Exercises", icon: "🔄") {
                        integratedProcessor.testAllExercises()
                    }
                }
            }
            
            // Performance Testing
            VStack(alignment: .leading, spacing: 8) {
                Text("Performance Analysis")
                    .font(.headline)
                
                Button(action: {
                    showingPerformanceTest = true
                    Task {
                        await integratedProcessor.comparePoseProviders()
                    }
                }) {
                    HStack {
                        Image(systemName: "speedometer")
                        Text("Compare Pose Providers")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
            
            // Current Status
            VStack(alignment: .leading, spacing: 8) {
                Text("Current Status")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    StatusRow(label: "Provider", value: integratedProcessor.poseProvider)
                    StatusRow(label: "State", value: integratedProcessor.currentState)
                    StatusRow(label: "Reps", value: "\(integratedProcessor.repCount)")
                    StatusRow(label: "Angle", value: String(format: "%.1f°", integratedProcessor.smoothedAngle))
                    StatusRow(label: "Form Score", value: String(format: "%.1f%%", integratedProcessor.formScore * 100))
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Feedback Message
            if !integratedProcessor.feedbackMessage.isEmpty {
                Text(integratedProcessor.feedbackMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Reset Button
            Button("Reset Session") {
                integratedProcessor.reset()
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .foregroundColor(.red)
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
        .onAppear {
            integratedProcessor.configureExercise(selectedExercise)
            integratedProcessor.switchToPoseProvider(selectedProvider)
        }
    }
}

// MARK: - Supporting Views

struct TestButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(8)
        }
    }
}

struct StatusRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .fontWeight(.medium)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct ExerciseTestingView_Previews: PreviewProvider {
    static var previews: some View {
        ExerciseTestingView(integratedProcessor: IntegratedExerciseProcessor())
    }
}
