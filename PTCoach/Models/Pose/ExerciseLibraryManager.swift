import Foundation
import Combine

// MARK: - Exercise Library Manager

class ExerciseLibraryManager: ObservableObject {
    @Published var exercises: [DynamicExercise] = []
    @Published var isLoading = false
    @Published var searchResults: [DynamicExercise] = []
    
    private let apiClient = ExerciseAPIClient()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadInitialExercises()
    }
    
    // MARK: - Exercise Loading
    
    func loadInitialExercises() {
        isLoading = true
        
        // Load from local bundle first
        loadBundledExercises()
        
        // Then fetch from API
        Task {
            await fetchExercisesFromAPI()
        }
    }
    
    private func loadBundledExercises() {
        guard let url = Bundle.main.url(forResource: "exercise_library", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ No bundled exercise library found")
            return
        }
        
        do {
            let exercises = try JSONDecoder().decode([DynamicExercise].self, from: data)
            DispatchQueue.main.async {
                self.exercises = exercises
                self.searchResults = exercises
                print("✅ Loaded \(exercises.count) exercises from bundle")
            }
        } catch {
            print("❌ Error loading bundled exercises: \(error)")
        }
    }
    
    private func fetchExercisesFromAPI() async {
        do {
            let apiExercises = try await apiClient.fetchAllExercises()
            
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // Merge with existing exercises, avoiding duplicates
                let existingIds = Set(self.exercises.map { $0.id })
                let newExercises = apiExercises.filter { !existingIds.contains($0.id) }
                
                self.exercises.append(contentsOf: newExercises)
                self.searchResults = self.exercises
                self.isLoading = false
                
                print("✅ Fetched \(apiExercises.count) exercises from API, \(newExercises.count) new")
            }
        } catch {
            print("❌ Error fetching exercises from API: \(error)")
            DispatchQueue.main.async { [weak self] in
                self?.isLoading = false
            }
        }
    }
    
    // MARK: - Search and Filtering
    
    func searchExercises(query: String) {
        if query.isEmpty {
            searchResults = exercises
            return
        }
        
        let lowercaseQuery = query.lowercased()
        
        searchResults = exercises.filter { exercise in
            exercise.name.lowercased().contains(lowercaseQuery) ||
            exercise.category.contains { $0.lowercased().contains(lowercaseQuery) } ||
            exercise.muscleGroups.contains { $0.lowercased().contains(lowercaseQuery) } ||
            exercise.equipment.contains { $0.lowercased().contains(lowercaseQuery) }
        }
    }
    
    func filterByCategory(_ category: String) {
        if category == "all" {
            searchResults = exercises
        } else {
            searchResults = exercises.filter { exercise in
                exercise.category.contains { $0.lowercased() == category.lowercased() }
            }
        }
    }
    
    func filterByMuscleGroup(_ muscleGroup: String) {
        if muscleGroup == "all" {
            searchResults = exercises
        } else {
            searchResults = exercises.filter { exercise in
                exercise.muscleGroups.contains { $0.lowercased() == muscleGroup.lowercased() }
            }
        }
    }
    
    func filterByDifficulty(_ difficulty: String) {
        if difficulty == "all" {
            searchResults = exercises
        } else {
            searchResults = exercises.filter { exercise in
                exercise.difficulty.lowercased() == difficulty.lowercased()
            }
        }
    }
    
    func filterByEquipment(_ equipment: String) {
        if equipment == "all" {
            searchResults = exercises
        } else {
            searchResults = exercises.filter { exercise in
                exercise.equipment.contains { $0.lowercased() == equipment.lowercased() }
            }
        }
    }
    
    // MARK: - Exercise Recommendations
    
    func getRecommendedExercises(for userProfile: UserProfile) -> [DynamicExercise] {
        var recommended = exercises
        
        // Filter by user's fitness level
        recommended = recommended.filter { exercise in
            switch userProfile.fitnessLevel {
            case .beginner:
                return exercise.difficulty == "beginner"
            case .intermediate:
                return exercise.difficulty == "beginner" || exercise.difficulty == "intermediate"
            case .advanced:
                return true // All exercises
            }
        }
        
        // Filter by available equipment
        if !userProfile.availableEquipment.isEmpty {
            recommended = recommended.filter { exercise in
                exercise.equipment.allSatisfy { equipment in
                    equipment == "none" || userProfile.availableEquipment.contains(equipment)
                }
            }
        }
        
        // Filter by target muscle groups
        if !userProfile.targetMuscleGroups.isEmpty {
            recommended = recommended.filter { exercise in
                !Set(exercise.muscleGroups).isDisjoint(with: Set(userProfile.targetMuscleGroups))
            }
        }
        
        // Filter by limitations/injuries
        if !userProfile.limitations.isEmpty {
            recommended = recommended.filter { exercise in
                !hasConflictingMovements(exercise: exercise, limitations: userProfile.limitations)
            }
        }
        
        return Array(recommended.prefix(10)) // Return top 10 recommendations
    }
    
    private func hasConflictingMovements(exercise: DynamicExercise, limitations: [String]) -> Bool {
        // Check if exercise conflicts with user limitations
        for limitation in limitations {
            let limitationLower = limitation.lowercased()
            
            if limitationLower.contains("knee") && exercise.muscleGroups.contains("quadriceps") {
                return true
            }
            if limitationLower.contains("shoulder") && exercise.muscleGroups.contains("shoulders") {
                return true
            }
            if limitationLower.contains("back") && exercise.muscleGroups.contains("back") {
                return true
            }
        }
        
        return false
    }
    
    func getSimilarExercises(to exercise: DynamicExercise) -> [DynamicExercise] {
        let similar = exercises.filter { other in
            other.id != exercise.id && (
                // Same primary muscle groups
                !Set(other.muscleGroups).isDisjoint(with: Set(exercise.muscleGroups)) ||
                // Same category
                !Set(other.category).isDisjoint(with: Set(exercise.category)) ||
                // Same equipment
                !Set(other.equipment).isDisjoint(with: Set(exercise.equipment))
            )
        }
        
        return Array(similar.prefix(5))
    }
    
    func getProgressionExercises(from exercise: DynamicExercise, direction: ProgressionDirection) -> [DynamicExercise] {
        let progressionNames = direction == .easier ? exercise.progressions.easier : exercise.progressions.harder
        
        return progressionNames.compactMap { progressionName in
            exercises.first { $0.name.lowercased().contains(progressionName.lowercased()) }
        }
    }
    
    // MARK: - Exercise Details
    
    func getExercise(by id: String) -> DynamicExercise? {
        return exercises.first { $0.id == id }
    }
    
    func getExercisesByCategory() -> [String: [DynamicExercise]] {
        var categorized: [String: [DynamicExercise]] = [:]
        
        for exercise in exercises {
            for category in exercise.category {
                if categorized[category] == nil {
                    categorized[category] = []
                }
                categorized[category]?.append(exercise)
            }
        }
        
        return categorized
    }
    
    func getAllCategories() -> [String] {
        let allCategories = exercises.flatMap { $0.category }
        return Array(Set(allCategories)).sorted()
    }
    
    func getAllMuscleGroups() -> [String] {
        let allMuscleGroups = exercises.flatMap { $0.muscleGroups }
        return Array(Set(allMuscleGroups)).sorted()
    }
    
    func getAllEquipment() -> [String] {
        let allEquipment = exercises.flatMap { $0.equipment }
        return Array(Set(allEquipment)).sorted()
    }
    
    // MARK: - Workout Generation
    
    func generateWorkout(for userProfile: UserProfile, duration: Int, focus: WorkoutFocus) -> [DynamicExercise] {
        let recommended = getRecommendedExercises(for: userProfile)
        var workout: [DynamicExercise] = []
        
        // Estimate exercises based on duration (assuming 3-5 minutes per exercise)
        let targetExerciseCount = max(3, min(duration / 4, 12))
        
        switch focus {
        case .upperBody:
            workout = recommended.filter { exercise in
                exercise.category.contains("upper_body") ||
                exercise.muscleGroups.contains { ["chest", "back", "shoulders", "biceps", "triceps"].contains($0) }
            }
        case .lowerBody:
            workout = recommended.filter { exercise in
                exercise.category.contains("lower_body") ||
                exercise.muscleGroups.contains { ["quadriceps", "hamstrings", "glutes", "calves"].contains($0) }
            }
        case .core:
            workout = recommended.filter { exercise in
                exercise.category.contains("core") ||
                exercise.muscleGroups.contains("core")
            }
        case .fullBody:
            // Mix of upper, lower, and core
            let upperBody = recommended.filter { $0.category.contains("upper_body") }.prefix(targetExerciseCount / 3)
            let lowerBody = recommended.filter { $0.category.contains("lower_body") }.prefix(targetExerciseCount / 3)
            let core = recommended.filter { $0.category.contains("core") }.prefix(targetExerciseCount / 3)
            
            workout = Array(upperBody) + Array(lowerBody) + Array(core)
        case .cardio:
            workout = recommended.filter { exercise in
                exercise.category.contains("cardio") ||
                exercise.name.lowercased().contains("jump")
            }
        case .flexibility:
            workout = recommended.filter { exercise in
                exercise.category.contains("flexibility") ||
                exercise.name.lowercased().contains("stretch")
            }
        }
        
        return Array(workout.shuffled().prefix(targetExerciseCount))
    }
}

// MARK: - Supporting Models

struct UserProfile {
    let fitnessLevel: FitnessLevel
    let availableEquipment: [String]
    let targetMuscleGroups: [String]
    let limitations: [String]
    let goals: [String]
    
    enum FitnessLevel {
        case beginner, intermediate, advanced
    }
}

enum ProgressionDirection {
    case easier, harder
}

enum WorkoutFocus {
    case upperBody, lowerBody, core, fullBody, cardio, flexibility
}

// MARK: - API Client

class ExerciseAPIClient {
    private let baseURL = "https://api.ptcoach.com/v1"
    private let session = URLSession.shared
    
    func fetchAllExercises() async throws -> [DynamicExercise] {
        guard let url = URL(string: "\(baseURL)/exercises") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let exercises = try JSONDecoder().decode([DynamicExercise].self, from: data)
        return exercises
    }
    
    func searchExercises(query: String) async throws -> [DynamicExercise] {
        guard let url = URL(string: "\(baseURL)/exercises/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let exercises = try JSONDecoder().decode([DynamicExercise].self, from: data)
        return exercises
    }
    
    func getExercise(id: String) async throws -> DynamicExercise {
        guard let url = URL(string: "\(baseURL)/exercises/\(id)") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let exercise = try JSONDecoder().decode(DynamicExercise.self, from: data)
        return exercise
    }
    
    func getSimilarExercises(to exerciseId: String) async throws -> [DynamicExercise] {
        guard let url = URL(string: "\(baseURL)/exercises/\(exerciseId)/similar") else {
            throw APIError.invalidURL
        }
        
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.serverError
        }
        
        let exercises = try JSONDecoder().decode([DynamicExercise].self, from: data)
        return exercises
    }
}

enum APIError: Error {
    case invalidURL
    case serverError
    case decodingError
}
