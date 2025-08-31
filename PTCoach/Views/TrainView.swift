import SwiftUI

struct TrainView: View {
    var body: some View {
        NavigationView {
            List {
                Section("Available Exercises") {
                    NavigationLink(destination: LiveSessionView(exerciseType: .kneeFlexion)) {
                        ExerciseRow(title: "Knee Flexion", 
                                  subtitle: "Range of motion exercise",
                                  icon: "figure.walk")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .shoulderFlexion)) {
                        ExerciseRow(title: "Shoulder Flexion", 
                                  subtitle: "Overhead reach exercise",
                                  icon: "figure.arms.open")
                    }
                    
                    NavigationLink(destination: LiveSessionView(exerciseType: .sitToStand)) {
                        ExerciseRow(title: "Sit to Stand", 
                                  subtitle: "Functional movement",
                                  icon: "figure.stand")
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

enum ExerciseType {
    case kneeFlexion
    case shoulderFlexion
    case sitToStand
}

#Preview {
    TrainView()
}
