import SwiftUI

struct ExerciseDashboardView: View {
    @StateObject private var yoloManager = YOLOExerciseManager()
    @State private var showingExerciseTracking = false
    @State private var showingSessionStats = false
    @State private var selectedExercise: YOLOExerciseReference?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Current Session (if active)
                    if let session = yoloManager.currentSession, session.isActive {
                        currentSessionSection(session)
                    }
                    
                    // Exercise Categories
                    exerciseCategoriesSection
                    
                    // Recent Exercises
                    recentExercisesSection
                }
                .padding()
            }
            .navigationTitle("PT Coach")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                // Refresh exercise data
            }
        }
        .fullScreenCover(isPresented: $showingExerciseTracking) {
            ExerciseTrackingView()
        }
        .sheet(isPresented: $showingSessionStats) {
            SessionStatsView(yoloManager: yoloManager)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Welcome back!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Ready for your next workout?")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Profile/Settings Button
                Button(action: {}) {
                    Image(systemName: "person.circle")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
            }
            
            // Exercise Stats Summary
            if !yoloManager.availableExercises.isEmpty {
                HStack(spacing: 20) {
                    StatItem(
                        title: "Available Exercises",
                        value: "\(yoloManager.availableExercises.count)",
                        icon: "list.bullet"
                    )
                    
                    StatItem(
                        title: "Categories",
                        value: "\(uniqueCategories.count)",
                        icon: "folder"
                    )
                    
                    StatItem(
                        title: "Difficulties",
                        value: "3",
                        icon: "chart.bar"
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "Start Tracking",
                    subtitle: "Begin exercise session",
                    icon: "play.circle.fill",
                    color: .green
                ) {
                    showingExerciseTracking = true
                }
                
                QuickActionButton(
                    title: "View Stats",
                    subtitle: "Session analytics",
                    icon: "chart.bar.fill",
                    color: .blue
                ) {
                    showingSessionStats = true
                }
            }
        }
    }
    
    private func currentSessionSection(_ session: ExerciseSession) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Current Session")
                    .font(.headline)
                
                Spacer()
                
                Button("View Details") {
                    showingSessionStats = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if let exercise = session.currentExercise {
                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        SessionMetric(
                            title: "Reps",
                            value: "\(session.repCount)",
                            color: .blue
                        )
                        
                        SessionMetric(
                            title: "Form Score",
                            value: "\(Int(session.formScore * 100))%",
                            color: session.formScore >= 0.8 ? .green : .orange
                        )
                        
                        SessionMetric(
                            title: "Duration",
                            value: formatDuration(session.sessionDuration),
                            color: .purple
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var exerciseCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercise Categories")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Array(uniqueCategories.prefix(6)), id: \.self) { category in
                    CategoryCard(
                        category: category,
                        exerciseCount: exerciseCount(for: category)
                    ) {
                        // Navigate to category exercises
                    }
                }
            }
        }
    }
    
    private var recentExercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Popular Exercises")
                    .font(.headline)
                
                Spacer()
                
                Button("See All") {
                    showingExerciseTracking = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVStack(spacing: 8) {
                ForEach(Array(yoloManager.availableExercises.prefix(5))) { exercise in
                    ExercisePreviewCard(exercise: exercise) {
                        selectedExercise = exercise
                        showingExerciseTracking = true
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var uniqueCategories: [String] {
        let allCategories = yoloManager.availableExercises.flatMap { $0.category }
        return Array(Set(allCategories)).sorted()
    }
    
    private func exerciseCount(for category: String) -> Int {
        return yoloManager.availableExercises.filter { exercise in
            exercise.category.contains(category)
        }.count
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct QuickActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(color)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SessionMetric: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CategoryCard: View {
    let category: String
    let exerciseCount: Int
    let action: () -> Void
    
    private var categoryColor: Color {
        switch category.lowercased() {
        case "strength": return .red
        case "flexibility": return .green
        case "balance": return .blue
        case "cardio": return .orange
        case "core": return .purple
        default: return .gray
        }
    }
    
    private var categoryIcon: String {
        switch category.lowercased() {
        case "strength": return "dumbbell"
        case "flexibility": return "figure.flexibility"
        case "balance": return "figure.stand"
        case "cardio": return "heart.fill"
        case "core": return "figure.core.training"
        default: return "figure.walk"
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: categoryIcon)
                    .font(.title2)
                    .foregroundColor(categoryColor)
                
                Text(category.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("\(exerciseCount) exercises")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(categoryColor.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ExercisePreviewCard: View {
    let exercise: YOLOExerciseReference
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Exercise Icon
                Image(systemName: exerciseIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                
                // Exercise Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack {
                        Text(exercise.difficulty.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(difficultyColor.opacity(0.2))
                            .foregroundColor(difficultyColor)
                            .cornerRadius(4)
                        
                        Text("\(exercise.phases.count) phases")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var exerciseIcon: String {
        if exercise.category.contains("strength") { return "dumbbell" }
        else if exercise.category.contains("flexibility") { return "figure.flexibility" }
        else if exercise.category.contains("balance") { return "figure.stand" }
        else if exercise.category.contains("cardio") { return "heart.fill" }
        else { return "figure.walk" }
    }
    
    private var difficultyColor: Color {
        switch exercise.difficulty.lowercased() {
        case "beginner": return .green
        case "intermediate": return .orange
        case "advanced": return .red
        default: return .gray
        }
    }
}

#Preview {
    ExerciseDashboardView()
}
