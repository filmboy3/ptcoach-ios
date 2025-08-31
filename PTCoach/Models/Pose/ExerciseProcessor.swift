import Foundation

/// Complete exercise processing pipeline integrating all components
class ExerciseProcessor: ObservableObject {
    
    @Published var currentAngles: [String: CGFloat] = [:]
    @Published var primaryAngle: CGFloat = 0
    @Published var frameCount: Int = 0
    @Published var processingResults: ProcessingResults?
    
    private let exercise: ExerciseInfo
    private let angleCalculator: RobustAngleCalculator
    private let stateMachine: RepCountingStateMachine
    private let formAnalyzer: FormAnalyzer
    
    struct ProcessingResults {
        let frame: Int
        let angles: [String: CGFloat]
        let primaryAngle: CGFloat
        let state: String
        let repCount: Int
        let repCompleted: Bool
        let formScore: Float
        let formFeedback: [String]
        let stateFeedback: String
        let safetyWarnings: [String]
        let currentPhase: String?
    }
    
    init(exercise: ExerciseInfo) {
        self.exercise = exercise
        self.angleCalculator = RobustAngleCalculator()
        self.stateMachine = RepCountingStateMachine(exercise: exercise)
        self.formAnalyzer = FormAnalyzer()
    }
    
    /// Process a single frame of pose landmarks
    func processFrame(landmarks: [Landmark]) -> ProcessingResults {
        frameCount += 1
        
        // Calculate all relevant angles using robust calculator
        var calculatedAngles: [String: CGFloat] = [:]
        
        // Calculate angles based on exercise joint type
        switch exercise.jointType {
        case "elbow":
            if let leftElbow = angleCalculator.calculateElbowAngle(landmarks: landmarks, side: .left) {
                calculatedAngles["elbow_left"] = leftElbow
            }
            if let rightElbow = angleCalculator.calculateElbowAngle(landmarks: landmarks, side: .right) {
                calculatedAngles["elbow_right"] = rightElbow
            }
            
        case "shoulder":
            if let leftShoulder = angleCalculator.calculateShoulderFlexion(landmarks: landmarks, side: .left) {
                calculatedAngles["shoulder_left"] = leftShoulder
            }
            if let rightShoulder = angleCalculator.calculateShoulderFlexion(landmarks: landmarks, side: .right) {
                calculatedAngles["shoulder_right"] = rightShoulder
            }
            
        case "knee":
            if let leftKnee = angleCalculator.calculateKneeFlexion(landmarks: landmarks, side: .left) {
                calculatedAngles["knee_left"] = leftKnee
            }
            if let rightKnee = angleCalculator.calculateKneeFlexion(landmarks: landmarks, side: .right) {
                calculatedAngles["knee_right"] = rightKnee
            }
            
        case "hip":
            if let leftHip = angleCalculator.calculateHipFlexion(landmarks: landmarks, side: .left) {
                calculatedAngles["hip_left"] = leftHip
            }
            if let rightHip = angleCalculator.calculateHipFlexion(landmarks: landmarks, side: .right) {
                calculatedAngles["hip_right"] = rightHip
            }
            
        case "ankle":
            if let leftAnkle = angleCalculator.calculateAnkleFlexion(landmarks: landmarks, side: .left) {
                calculatedAngles["ankle_left"] = leftAnkle
            }
            if let rightAnkle = angleCalculator.calculateAnkleFlexion(landmarks: landmarks, side: .right) {
                calculatedAngles["ankle_right"] = rightAnkle
            }
            
        case "neck":
            if let neckAngle = angleCalculator.calculateNeckFlexion(landmarks: landmarks) {
                calculatedAngles["neck"] = neckAngle
            }
            
        default:
            // Default to elbow calculation
            if let leftElbow = angleCalculator.calculateElbowAngle(landmarks: landmarks, side: .left) {
                calculatedAngles["elbow_left"] = leftElbow
            }
            if let rightElbow = angleCalculator.calculateElbowAngle(landmarks: landmarks, side: .right) {
                calculatedAngles["elbow_right"] = rightElbow
            }
        }
        
        // Calculate primary angle for state machine
        let calculatedPrimaryAngle = calculatePrimaryAngle(from: calculatedAngles)
        
        // Update state machine
        let (repCompleted, stateFeedback) = stateMachine.update(currentAngle: calculatedPrimaryAngle)
        
        // Get target angles for current state
        let targetAngles = formAnalyzer.getTargetAngles(for: exercise, currentState: stateMachine.currentState)
        
        // Analyze form
        let (formScore, formFeedback) = formAnalyzer.analyzeForm(
            exercise: exercise,
            currentAngles: calculatedAngles,
            targetAngles: targetAngles
        )
        
        // Check safety
        let safetyWarnings = formAnalyzer.checkSafetyConstraints(
            currentAngles: calculatedAngles,
            exercise: exercise
        )
        
        // Create results
        let results = ProcessingResults(
            frame: frameCount,
            angles: calculatedAngles,
            primaryAngle: calculatedPrimaryAngle,
            state: stateMachine.currentState.rawValue,
            repCount: stateMachine.repCount,
            repCompleted: repCompleted,
            formScore: formScore,
            formFeedback: formFeedback,
            stateFeedback: stateFeedback,
            safetyWarnings: safetyWarnings,
            currentPhase: determineCurrentPhase()
        )
        
        // Update published properties
        DispatchQueue.main.async { [weak self] in
            self?.currentAngles = calculatedAngles
            self?.primaryAngle = calculatedPrimaryAngle
            self?.processingResults = results
        }
        
        return results
    }
    
    /// Calculate primary angle based on exercise type and bilateral setting
    private func calculatePrimaryAngle(from angles: [String: CGFloat]) -> CGFloat {
        var primaryAngles: [CGFloat] = []
        
        // Collect relevant angles based on joint type
        switch exercise.jointType {
        case "elbow":
            if let left = angles["elbow_left"] { primaryAngles.append(left) }
            if let right = angles["elbow_right"] { primaryAngles.append(right) }
            
        case "shoulder":
            if let left = angles["shoulder_left"] { primaryAngles.append(left) }
            if let right = angles["shoulder_right"] { primaryAngles.append(right) }
            
        case "knee":
            if let left = angles["knee_left"] { primaryAngles.append(left) }
            if let right = angles["knee_right"] { primaryAngles.append(right) }
            
        case "hip":
            if let left = angles["hip_left"] { primaryAngles.append(left) }
            if let right = angles["hip_right"] { primaryAngles.append(right) }
            
        case "ankle":
            if let left = angles["ankle_left"] { primaryAngles.append(left) }
            if let right = angles["ankle_right"] { primaryAngles.append(right) }
            
        case "neck":
            if let neck = angles["neck"] { primaryAngles.append(neck) }
            
        default:
            if let left = angles["elbow_left"] { primaryAngles.append(left) }
            if let right = angles["elbow_right"] { primaryAngles.append(right) }
        }
        
        // Return average if bilateral, single value if unilateral
        if primaryAngles.isEmpty {
            return 0
        } else if primaryAngles.count == 1 {
            return primaryAngles[0]
        } else {
            // For bilateral exercises, use average
            // For unilateral, this would need exercise-specific logic
            return primaryAngles.reduce(0, +) / CGFloat(primaryAngles.count)
        }
    }
    
    /// Determine current exercise phase based on state
    private func determineCurrentPhase() -> String? {
        switch stateMachine.currentState {
        case .idle:
            return "Preparation"
        case .extended:
            return "Starting Position"
        case .flexing:
            return "Concentric Phase"
        case .flexed:
            return "Peak Contraction"
        case .holding:
            return "Hold Phase"
        case .extending:
            return "Eccentric Phase"
        }
    }
    
    /// Reset the processor for a new exercise session
    func reset() {
        frameCount = 0
        angleCalculator.resetHistory()
        stateMachine.reset()
        formAnalyzer.reset()
        
        DispatchQueue.main.async { [weak self] in
            self?.currentAngles = [:]
            self?.primaryAngle = 0
            self?.processingResults = nil
        }
    }
    
    /// Get comprehensive processing statistics
    func getProcessingStats() -> [String: Any] {
        var stats: [String: Any] = [:]
        
        // State machine stats
        stats.merge(stateMachine.getStateInfo()) { _, new in new }
        
        // Form analyzer stats
        stats.merge(formAnalyzer.getFormSummary()) { _, new in new }
        
        // Processing stats
        stats["totalFrames"] = frameCount
        stats["anglesTracked"] = currentAngles.count
        stats["primaryAngle"] = primaryAngle
        
        return stats
    }
    
    /// Update exercise (useful for switching exercises mid-session)
    func updateExercise(_ newExercise: ExerciseInfo) {
        // This would require reinitializing components
        // For now, recommend creating a new processor
        print("⚠️ Exercise switching requires creating new ExerciseProcessor instance")
    }
}
