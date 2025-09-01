import Foundation
import Combine
import CoreGraphics

// MARK: - YOLO Exercise Manager

/// Main manager for YOLO exercise dataset and real-time tracking
@MainActor
class YOLOExerciseManager: ObservableObject, @unchecked Sendable {
    @Published var dataset: YOLOExerciseDataset?
    @Published var availableExercises: [YOLOExerciseReference] = []
    @Published var currentSession: ExerciseSession?
    @Published var isLoading = false
    @Published var error: YOLOError?
    
    private let repDetector = RepDetector(keypointsToTrack: [])
    private let formAnalyzer = LegacyFormAnalyzer()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        loadYOLODataset()
        setupSessionObservers()
    }
    
    // MARK: - Dataset Loading
    
    private func loadYOLODataset() {
        isLoading = true
        error = nil
        
        guard let url = Bundle.main.url(forResource: "complete_yolo_dataset_robust", withExtension: "json") else {
            self.error = .datasetNotFound
            self.isLoading = false
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let dataset = try decoder.decode(YOLOExerciseDataset.self, from: data)
            
            DispatchQueue.main.async {
                self.dataset = dataset
                self.availableExercises = dataset.exercises
                self.isLoading = false
                print("✅ Loaded \(dataset.exercises.count) YOLO exercises")
            }
        } catch {
            DispatchQueue.main.async {
                self.error = .decodingError(error)
                self.isLoading = false
                print("❌ Error loading YOLO dataset: \(error)")
            }
        }
    }
    
    // MARK: - Exercise Selection and Search
    
    func searchExercises(query: String) -> [YOLOExerciseReference] {
        guard !query.isEmpty else { return availableExercises }
        
        let lowercaseQuery = query.lowercased()
        return availableExercises.filter { exercise in
            exercise.name.lowercased().contains(lowercaseQuery) ||
            exercise.category.contains { $0.lowercased().contains(lowercaseQuery) } ||
            exercise.exerciseId.lowercased().contains(lowercaseQuery)
        }
    }
    
    func getExercisesByCategory(_ category: String) -> [YOLOExerciseReference] {
        if category.lowercased() == "all" {
            return availableExercises
        }
        
        return availableExercises.filter { exercise in
            exercise.category.contains { $0.lowercased() == category.lowercased() }
        }
    }
    
    func getExercisesByDifficulty(_ difficulty: String) -> [YOLOExerciseReference] {
        if difficulty.lowercased() == "all" {
            return availableExercises
        }
        
        return availableExercises.filter { exercise in
            exercise.difficulty.lowercased() == difficulty.lowercased()
        }
    }
    
    func getExercise(by id: String) -> YOLOExerciseReference? {
        return availableExercises.first { $0.exerciseId == id }
    }
    
    // MARK: - Exercise Session Management
    
    func startExerciseSession(with exercise: YOLOExerciseReference) {
        let session = ExerciseSession()
        session.startSession(with: exercise)
        self.currentSession = session
        
        // Configure rep detector for this exercise
        _ = RepDetector(keypointsToTrack: exercise.repDetectionKeypoints)
        
        print("🏃‍♂️ Started exercise session: \(exercise.name)")
    }
    
    func endCurrentSession() {
        currentSession?.endSession()
        currentSession = nil
        print("🛑 Ended exercise session")
    }
    
    func pauseCurrentSession() {
        currentSession?.isActive = false
        print("⏸️ Paused exercise session")
    }
    
    func resumeCurrentSession() {
        currentSession?.isActive = true
        print("▶️ Resumed exercise session")
    }
    
    // MARK: - Real-time Pose Analysis
    
    func processFrame(keypoints: [CGPoint]) -> FrameAnalysisResult? {
        guard let session = currentSession,
              let exercise = session.currentExercise,
              session.isActive,
              keypoints.count >= 17 else {
            return nil
        }
        
        let currentPhaseIndex = session.currentPhase
        guard currentPhaseIndex < exercise.phases.count else { return nil }
        
        let currentPhase = exercise.phases[currentPhaseIndex]
        
        // Update rep detection
        let repCompleted = repDetector.updateState(with: keypoints, targetPhase: currentPhase)
        if repCompleted {
            session.recordRep()
        }
        
        // Analyze form (using legacy analyzer for now)
        let formResult = formAnalyzer.analyzeForm(keypoints: keypoints, targetPhase: currentPhase)
        session.updateFormScore(formResult.overallScore)
        
        // Add safety alerts
        for alert in formResult.safetyAlerts {
            session.addSafetyAlert(alert)
        }
        
        // Update session duration
        session.updateSessionDuration()
        
        return FrameAnalysisResult(
            repDetected: repCompleted,
            formScore: formResult.overallScore,
            feedback: formResult.feedback,
            safetyAlerts: formResult.safetyAlerts,
            repCount: session.repCount,
            currentPhase: currentPhaseIndex
        )
    }
    
    // MARK: - Exercise Progression
    
    func advanceToNextPhase() {
        guard let session = currentSession,
              let exercise = session.currentExercise else { return }
        
        if session.currentPhase < exercise.phases.count - 1 {
            session.currentPhase += 1
            print("➡️ Advanced to phase \(session.currentPhase + 1)")
        } else {
            print("✅ Exercise completed - all phases done")
        }
    }
    
    func goToPreviousPhase() {
        guard let session = currentSession else { return }
        
        if session.currentPhase > 0 {
            session.currentPhase -= 1
            print("⬅️ Returned to phase \(session.currentPhase + 1)")
        }
    }
    
    func resetCurrentPhase() {
        currentSession?.currentPhase = 0
        currentSession?.repCount = 0
        print("🔄 Reset to first phase")
    }
    
    // MARK: - Statistics and Analytics
    
    func getSessionStatistics() -> SessionStatistics? {
        guard let session = currentSession else { return nil }
        
        return SessionStatistics(
            exerciseName: session.currentExercise?.name ?? "Unknown",
            duration: session.sessionDuration,
            repCount: session.repCount,
            averageFormScore: session.formScore,
            safetyAlertsCount: session.safetyAlerts.count,
            phasesCompleted: session.currentPhase + 1,
            totalPhases: session.currentExercise?.phases.count ?? 0
        )
    }
    
    func getExerciseRecommendations(basedOn exercise: YOLOExerciseReference) -> [YOLOExerciseReference] {
        // Find exercises with similar categories or muscle groups
        let similar = availableExercises.filter { other in
            other.exerciseId != exercise.exerciseId && (
                !Set(other.category).isDisjoint(with: Set(exercise.category)) ||
                other.difficulty == exercise.difficulty ||
                other.bodyOrientation == exercise.bodyOrientation
            )
        }
        
        return Array(similar.prefix(5))
    }
    
    // MARK: - Data Export
    
    func exportSessionData() -> SessionExportData? {
        guard let session = currentSession,
              let exercise = session.currentExercise else { return nil }
        
        return SessionExportData(
            exerciseId: exercise.exerciseId,
            exerciseName: exercise.name,
            startTime: Date(), // Should track actual start time
            duration: session.sessionDuration,
            repCount: session.repCount,
            averageFormScore: session.formScore,
            safetyAlerts: session.safetyAlerts.map { alert in
                SessionExportData.AlertData(
                    message: alert.message,
                    severity: alert.severity.rawValue,
                    timestamp: alert.timestamp
                )
            },
            phasesCompleted: session.currentPhase + 1
        )
    }
    
    // MARK: - Private Helpers
    
    private func setupSessionObservers() {
        // Observe session changes and update UI accordingly
        $currentSession
            .sink { session in
                if let session = session {
                    print("📊 Session updated: \(session.repCount) reps, score: \(String(format: "%.1f", session.formScore * 100))%")
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Supporting Models

struct FrameAnalysisResult {
    let repDetected: Bool
    let formScore: Double
    let feedback: [FormFeedback]
    let safetyAlerts: [SafetyAlert]
    let repCount: Int
    let currentPhase: Int
}

struct SessionStatistics {
    let exerciseName: String
    let duration: TimeInterval
    let repCount: Int
    let averageFormScore: Double
    let safetyAlertsCount: Int
    let phasesCompleted: Int
    let totalPhases: Int
    
    var completionPercentage: Double {
        guard totalPhases > 0 else { return 0.0 }
        return Double(phasesCompleted) / Double(totalPhases) * 100.0
    }
    
    var formScorePercentage: Double {
        return averageFormScore * 100.0
    }
}

struct SessionExportData: Codable {
    let exerciseId: String
    let exerciseName: String
    let startTime: Date
    let duration: TimeInterval
    let repCount: Int
    let averageFormScore: Double
    let safetyAlerts: [AlertData]
    let phasesCompleted: Int
    
    struct AlertData: Codable {
        let message: String
        let severity: String
        let timestamp: Date
    }
}

enum YOLOError: Error, LocalizedError {
    case datasetNotFound
    case decodingError(Error)
    case invalidExercise
    case sessionNotActive
    
    var errorDescription: String? {
        switch self {
        case .datasetNotFound:
            return "YOLO exercise dataset not found in app bundle"
        case .decodingError(let error):
            return "Failed to decode YOLO dataset: \(error.localizedDescription)"
        case .invalidExercise:
            return "Invalid exercise selected"
        case .sessionNotActive:
            return "No active exercise session"
        }
    }
}

