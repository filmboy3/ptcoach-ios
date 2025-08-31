import SwiftUI
import Charts

struct SessionStatsView: View {
    let yoloManager: YOLOExerciseManager
    @Environment(\.dismiss) private var dismiss
    
    private var sessionStats: SessionStatistics? {
        yoloManager.getSessionStatistics()
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if let stats = sessionStats {
                        // Header Stats
                        headerStatsSection(stats)
                        
                        // Progress Chart
                        progressChartSection(stats)
                        
                        // Form Analysis
                        formAnalysisSection(stats)
                        
                        // Safety Alerts
                        if let session = yoloManager.currentSession, !session.safetyAlerts.isEmpty {
                            safetyAlertsSection(session.safetyAlerts)
                        }
                        
                        // Export Options
                        exportSection
                    } else {
                        emptyStateView
                    }
                }
                .padding()
            }
            .navigationTitle("Session Stats")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func headerStatsSection(_ stats: SessionStatistics) -> some View {
        VStack(spacing: 16) {
            Text(stats.exerciseName)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 30) {
                StatCard(
                    title: "Reps",
                    value: "\(stats.repCount)",
                    icon: "repeat",
                    color: .blue
                )
                
                StatCard(
                    title: "Duration",
                    value: formatDuration(stats.duration),
                    icon: "clock",
                    color: .green
                )
                
                StatCard(
                    title: "Form Score",
                    value: "\(Int(stats.formScorePercentage))%",
                    icon: "checkmark.circle",
                    color: formScoreColor(stats.formScorePercentage)
                )
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func progressChartSection(_ stats: SessionStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Progress")
                .font(.headline)
            
            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Phases Completed")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(stats.phasesCompleted)/\(stats.totalPhases)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                ProgressView(value: stats.completionPercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text("\(Int(stats.completionPercentage))% Complete")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func formAnalysisSection(_ stats: SessionStatistics) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Form Analysis")
                .font(.headline)
            
            // Form Score Breakdown
            VStack(spacing: 8) {
                HStack {
                    Text("Overall Form Score")
                        .font(.subheadline)
                    
                    Spacer()
                    
                    Text("\(Int(stats.formScorePercentage))%")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(formScoreColor(stats.formScorePercentage))
                }
                
                ProgressView(value: stats.formScorePercentage / 100.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: formScoreColor(stats.formScorePercentage)))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                // Form Feedback
                HStack {
                    Image(systemName: formScoreIcon(stats.formScorePercentage))
                        .foregroundColor(formScoreColor(stats.formScorePercentage))
                    
                    Text(formScoreFeedback(stats.formScorePercentage))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private func safetyAlertsSection(_ alerts: [SafetyAlert]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Safety Alerts")
                    .font(.headline)
                
                Spacer()
                
                Text("\(alerts.count)")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.1))
                    .foregroundColor(.red)
                    .cornerRadius(8)
            }
            
            ForEach(alerts.prefix(5)) { alert in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: alertIcon(alert.severity))
                        .foregroundColor(alertColor(alert.severity))
                        .font(.caption)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.message)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text(formatTime(alert.timestamp))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            if alerts.count > 5 {
                Text("... and \(alerts.count - 5) more alerts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var exportSection: some View {
        VStack(spacing: 12) {
            Text("Export Session Data")
                .font(.headline)
            
            HStack(spacing: 12) {
                Button(action: exportAsJSON) {
                    HStack {
                        Image(systemName: "doc.text")
                        Text("Export JSON")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                
                Button(action: shareSession) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Active Session")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Start an exercise to see session statistics")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formScoreColor(_ score: Double) -> Color {
        if score >= 80 { return .green }
        else if score >= 60 { return .yellow }
        else { return .red }
    }
    
    private func formScoreIcon(_ score: Double) -> String {
        if score >= 80 { return "checkmark.circle.fill" }
        else if score >= 60 { return "exclamationmark.triangle.fill" }
        else { return "xmark.circle.fill" }
    }
    
    private func formScoreFeedback(_ score: Double) -> String {
        if score >= 80 { return "Excellent form! Keep it up." }
        else if score >= 60 { return "Good form with room for improvement." }
        else { return "Focus on form corrections." }
    }
    
    private func alertColor(_ severity: SafetyAlert.AlertSeverity) -> Color {
        switch severity {
        case .low: return .yellow
        case .medium: return .orange
        case .high: return .red
        case .critical: return .purple
        }
    }
    
    private func alertIcon(_ severity: SafetyAlert.AlertSeverity) -> String {
        switch severity {
        case .low: return "info.circle.fill"
        case .medium: return "exclamationmark.triangle.fill"
        case .high: return "exclamationmark.octagon.fill"
        case .critical: return "exclamationmark.triangle.fill"
        }
    }
    
    private func exportAsJSON() {
        guard let exportData = yoloManager.exportSessionData() else { return }
        
        do {
            let jsonData = try JSONEncoder().encode(exportData)
            let jsonString = String(data: jsonData, encoding: .utf8) ?? ""
            
            // Save to Documents directory
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let fileName = "session_\(Date().timeIntervalSince1970).json"
            let fileURL = documentsPath.appendingPathComponent(fileName)
            
            try jsonString.write(to: fileURL, atomically: true, encoding: .utf8)
            print("✅ Session data exported to: \(fileURL)")
        } catch {
            print("❌ Export failed: \(error)")
        }
    }
    
    private func shareSession() {
        // Implement sharing functionality
        print("📤 Sharing session data...")
    }
}

// MARK: - Stat Card View

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

#Preview {
    SessionStatsView(yoloManager: YOLOExerciseManager())
}
