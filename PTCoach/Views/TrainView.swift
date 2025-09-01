import SwiftUI

struct TrainView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Available Exercises") {
                    NavigationLink(destination: LiveSessionView(exerciseType: .bicepCurl)) {
                        ExerciseRow(title: "Bicep Curl", 
                                  subtitle: "Enhanced angle calculation",
                                  icon: "figure.strengthtraining.traditional")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .kneeFlexion)) {
                        ExerciseRow(title: "Knee Flexion", 
                                  subtitle: "Corrected 3-point angle",
                                  icon: "figure.walk")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .lateralArmRaise)) {
                        ExerciseRow(title: "Lateral Arm Raise", 
                                  subtitle: "Shoulder abduction tracking",
                                  icon: "figure.arms.open")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .shoulderFlexion)) {
                        ExerciseRow(title: "Shoulder Flexion", 
                                  subtitle: "Overhead reach exercise",
                                  icon: "figure.wave")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .sitToStand)) {
                        ExerciseRow(title: "Sit to Stand", 
                                  subtitle: "Functional movement",
                                  icon: "figure.stand")
                    }
                }
                
                Section("Advanced Exercises") {
                    NavigationLink(destination: LiveSessionView(exerciseType: .ankleFlexion)) {
                        ExerciseRow(title: "Ankle Flexion", 
                                  subtitle: "Foot movement tracking",
                                  icon: "figure.run")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .neckFlexion)) {
                        ExerciseRow(title: "Neck Flexion", 
                                  subtitle: "Head movement analysis",
                                  icon: "figure.mind.and.body")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .hipFlexion)) {
                        ExerciseRow(title: "Hip Flexion", 
                                  subtitle: "Leg raise tracking",
                                  icon: "figure.flexibility")
                    }
                }
            }
            .navigationTitle("Train")
        }
    }
}

struct ExerciseRow: View {
    let title: String
    let subtitle: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

enum ExerciseType: String, CaseIterable {
    case kneeFlexion = "Knee Flexion"
    case shoulderFlexion = "Shoulder Flexion"
    case sitToStand = "Sit to Stand"
    case bicepCurl = "Bicep Curl"
    case lateralArmRaise = "Lateral Arm Raise"
    case ankleFlexion = "Ankle Flexion"
    case neckFlexion = "Neck Flexion"
    case hipFlexion = "Hip Flexion"
}

#Preview {
    TrainView()
}
