import SwiftUI

struct ProgressViewScreen: View {
    @StateObject private var progressManager = ProgressManager()
    
    var body: some View {
        NavigationView {
            List {
                Section("Recent Sessions") {
                    ForEach(progressManager.sessions) { session in
                        SessionRow(session: session)
                    }
                }
                
                Section("Actions") {
                    Button(action: {
                        progressManager.exportPDF()
                    }) {
                        HStack {
                            Image(systemName: "doc.text")
                            Text("Export PDF Summary")
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .navigationTitle("Progress")
        }
    }
}

struct SessionRow: View {
    let session: ProgressExerciseSession
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.exerciseType)
                    .font(.headline)
                Spacer()
                Text(session.date, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Reps: \(session.repCount)")
                    .font(.caption)
                Spacer()
                Text("Max Angle: \(Int(session.maxAngle))°")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct ProgressExerciseSession: Identifiable {
    let id = UUID()
    let exerciseType: String
    let date: Date
    let repCount: Int
    let maxAngle: Double
    let duration: TimeInterval
}

class ProgressManager: ObservableObject {
    @Published var sessions: [ProgressExerciseSession] = []
    
    init() {
        loadMockSessions()
    }
    
    private func loadMockSessions() {
        sessions = [
            ProgressExerciseSession(exerciseType: "Knee Flexion", date: Date().addingTimeInterval(-86400), repCount: 12, maxAngle: 125, duration: 300),
            ProgressExerciseSession(exerciseType: "Shoulder Flexion", date: Date().addingTimeInterval(-172800), repCount: 8, maxAngle: 145, duration: 240),
            ProgressExerciseSession(exerciseType: "Sit to Stand", date: Date().addingTimeInterval(-259200), repCount: 5, maxAngle: 90, duration: 180)
        ]
    }
    
    func exportPDF() {
        // Mock PDF export
        print("📄 PDF exported to: Documents/PTCoach_Progress_\(Date().timeIntervalSince1970).pdf")
        print("✅ Export completed successfully")
    }
}

#Preview {
    ProgressViewScreen()
}
