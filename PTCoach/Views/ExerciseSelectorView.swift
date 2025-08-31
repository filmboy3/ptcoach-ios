import SwiftUI

struct ExerciseSelectorView: View {
    let yoloManager: YOLOExerciseManager
    let onExerciseSelected: (YOLOExerciseReference) -> Void
    
    @State private var searchText = ""
    @State private var selectedCategory = "all"
    @State private var selectedDifficulty = "all"
    @Environment(\.dismiss) private var dismiss
    
    private var filteredExercises: [YOLOExerciseReference] {
        var exercises = yoloManager.availableExercises
        
        // Apply search filter
        if !searchText.isEmpty {
            exercises = yoloManager.searchExercises(query: searchText)
        }
        
        // Apply category filter
        if selectedCategory != "all" {
            exercises = exercises.filter { exercise in
                exercise.category.contains { $0.lowercased() == selectedCategory.lowercased() }
            }
        }
        
        // Apply difficulty filter
        if selectedDifficulty != "all" {
            exercises = exercises.filter { exercise in
                exercise.difficulty.lowercased() == selectedDifficulty.lowercased()
            }
        }
        
        return exercises
    }
    
    private var categories: [String] {
        let allCategories = yoloManager.availableExercises.flatMap { $0.category }
        return ["all"] + Array(Set(allCategories)).sorted()
    }
    
    private var difficulties: [String] {
        let allDifficulties = yoloManager.availableExercises.map { $0.difficulty }
        return ["all"] + Array(Set(allDifficulties)).sorted()
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filters
                searchAndFiltersSection
                
                // Exercise List
                exerciseListSection
            }
            .navigationTitle("Select Exercise")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var searchAndFiltersSection: some View {
        VStack(spacing: 12) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search exercises...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
            
            // Filter Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // Category Filter
                    Menu {
                        ForEach(categories, id: \.self) { category in
                            Button(category.capitalized) {
                                selectedCategory = category
                            }
                        }
                    } label: {
                        HStack {
                            Text("Category: \(selectedCategory.capitalized)")
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(16)
                    }
                    
                    // Difficulty Filter
                    Menu {
                        ForEach(difficulties, id: \.self) { difficulty in
                            Button(difficulty.capitalized) {
                                selectedDifficulty = difficulty
                            }
                        }
                    } label: {
                        HStack {
                            Text("Difficulty: \(selectedDifficulty.capitalized)")
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .foregroundColor(.orange)
                        .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(Color(.systemGroupedBackground))
    }
    
    private var exerciseListSection: some View {
        List(filteredExercises) { exercise in
            ExerciseRowView(exercise: exercise) {
                onExerciseSelected(exercise)
            }
        }
        .listStyle(PlainListStyle())
    }
}

// MARK: - Exercise Row View

struct ExerciseRowView: View {
    let exercise: YOLOExerciseReference
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Exercise Name
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                // Categories and Difficulty
                HStack {
                    // Categories
                    ForEach(Array(exercise.category.prefix(2)), id: \.self) { category in
                        Text(category.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Difficulty Badge
                    Text(exercise.difficulty.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(difficultyColor.opacity(0.1))
                        .foregroundColor(difficultyColor)
                        .cornerRadius(8)
                }
                
                // Exercise Details
                HStack {
                    Label("\(exercise.phases.count) phases", systemImage: "list.number")
                    
                    Spacer()
                    
                    Label(exercise.bodyOrientation.capitalized, systemImage: "figure.stand")
                    
                    Spacer()
                    
                    Label(exercise.cameraAngle.replacingOccurrences(of: "_", with: " ").capitalized, 
                          systemImage: "camera")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
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

// MARK: - Exercise Detail View

struct ExerciseDetailView: View {
    let exercise: YOLOExerciseReference
    let onStartExercise: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    HStack {
                        ForEach(exercise.category, id: \.self) { category in
                            Text(category.capitalized)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Text(exercise.difficulty.capitalized)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(difficultyColor.opacity(0.1))
                            .foregroundColor(difficultyColor)
                            .cornerRadius(8)
                    }
                }
                
                // Exercise Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Exercise Information")
                        .font(.headline)
                    
                    InfoRow(title: "Body Position", value: exercise.bodyOrientation.capitalized)
                    InfoRow(title: "Camera Angle", value: exercise.cameraAngle.replacingOccurrences(of: "_", with: " ").capitalized)
                    InfoRow(title: "Movement Phases", value: "\(exercise.phases.count)")
                    InfoRow(title: "Rep Detection Points", value: "\(exercise.repDetectionKeypoints.count)")
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                
                // Movement Phases
                VStack(alignment: .leading, spacing: 12) {
                    Text("Movement Phases")
                        .font(.headline)
                    
                    ForEach(Array(exercise.phases.enumerated()), id: \.offset) { index, phase in
                        PhaseRowView(phase: phase, index: index + 1)
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                .cornerRadius(12)
                
                // Safety Constraints
                if !exercise.safetyConstraints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Safety Guidelines")
                            .font(.headline)
                        
                        ForEach(exercise.safetyConstraints, id: \.self) { constraint in
                            HStack(alignment: .top) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text(constraint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                }
                
                // Form Checkpoints
                if !exercise.formCheckpoints.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Form Checkpoints")
                            .font(.headline)
                        
                        ForEach(exercise.formCheckpoints, id: \.self) { checkpoint in
                            HStack(alignment: .top) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text(checkpoint)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(12)
                }
                
                // Start Button
                Button(action: {
                    onStartExercise()
                    dismiss()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Start Exercise")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
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

// MARK: - Supporting Views

struct InfoRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

struct PhaseRowView: View {
    let phase: YOLOExercisePhase
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Phase \(index): \(phase.name)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Text("\(phase.durationRangeMs[0]/1000)-\(phase.durationRangeMs[1]/1000)s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !phase.targetJointAngles.isEmpty {
                Text("Target joints: \(phase.targetJointAngles.keys.joined(separator: ", "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ExerciseSelectorView(yoloManager: YOLOExerciseManager()) { _ in }
}
