import Foundation
import CoreGraphics
import simd
import UIKit
import AudioToolbox

// MARK: - Dynamic Exercise Models

/// Complete exercise definition with all metadata for dynamic tracking
struct DynamicExercise: Codable, Identifiable {
    let id: String
    let name: String
    let category: [String]
    let muscleGroups: [String]
    let equipment: [String]
    let difficulty: String
    
    // Pose Detection Requirements
    let cameraPosition: CameraPosition
    let bodyOrientation: BodyOrientation
    let requiredLandmarks: [String]
    let optionalLandmarks: [String]?
    let occlusionTolerance: Float
    
    // Movement Phases
    let movementPhases: [MovementPhase]
    
    // Form Feedback
    let formCues: FormCues
    let commonErrors: [ExerciseError]
    
    // Progressions
    let variations: [String]?
    let progressions: Progressions
    let clinicalApplications: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, equipment, difficulty, variations
        case muscleGroups = "muscle_groups"
        case cameraPosition = "camera_position"
        case bodyOrientation = "body_orientation"
        case requiredLandmarks = "required_landmarks"
        case optionalLandmarks = "optional_landmarks"
        case occlusionTolerance = "occlusion_tolerance"
        case movementPhases = "movement_phases"
        case formCues = "form_cues"
        case commonErrors = "common_errors"
        case progressions
        case clinicalApplications = "clinical_applications"
    }
}

enum CameraPosition: String, Codable, CaseIterable {
    case frontFacing = "front_facing"
    case sideLeft = "side_profile_left"
    case sideRight = "side_profile_right"
    case diagonalFront = "45_degree_front"
    case diagonalBack = "45_degree_back"
    case overhead = "overhead"
    case lowAngle = "low_angle"
}

enum BodyOrientation: String, Codable, CaseIterable {
    case standing = "standing"
    case seated = "seated"
    case lyingSupine = "lying_supine"
    case lyingProne = "lying_prone"
    case lyingSide = "lying_side"
    case kneeling = "kneeling"
    case quadruped = "quadruped"
}

struct MovementPhase: Codable {
    let phaseName: String
    let jointAngles: [String: AngleRange]
    let durationMs: DurationRange?
    let velocity: VelocityRange?
    let direction: String?
    let holdRequired: Bool
    
    struct AngleRange: Codable {
        let min: CGFloat
        let max: CGFloat
    }
    
    struct DurationRange: Codable {
        let min: Int
        let max: Int
    }
    
    struct VelocityRange: Codable {
        let min: CGFloat
        let max: CGFloat
    }
    
    enum CodingKeys: String, CodingKey {
        case phaseName = "phase_name"
        case jointAngles = "joint_angles"
        case durationMs = "duration_ms"
        case velocity, direction
        case holdRequired = "hold_required"
    }
}

struct FormCues: Codable {
    let critical: [String]
    let optimization: [String]
}

struct ExerciseError: Codable {
    let error: String
    let detection: String
    let feedback: String
}

struct Progressions: Codable {
    let easier: [String]
    let harder: [String]
}

// MARK: - Enhanced Angle Engine for Dynamic Exercises

class DynamicAngleEngine: ObservableObject {
    static let shared = DynamicAngleEngine()
    
    @Published var currentExercise: DynamicExercise?
    @Published var currentPhase: MovementPhase?
    @Published var phaseProgress: Float = 0
    @Published var repCount = 0
    @Published var formScore: Float = 0
    @Published var detectedErrors: [ExerciseError] = []
    @Published var feedbackMessage = "Loading exercise..."
    @Published var currentAngle: CGFloat = 0
    @Published var maxAngle: CGFloat = 0
    @Published var inFlexion = false
    
    // Debug-exposed values
    var rawAngle: CGFloat = 0
    var angleVelocity: CGFloat = 0
    
    private var phaseStartTime: CFAbsoluteTime = 0
    private var phaseHistory: [String] = []
    private var jointAngleHistory: [[String: CGFloat]] = []
    private var previousAngle: CGFloat = 0
    private var lastTimestamp: CFAbsoluteTime = 0
    
    // Rep gating state
    private var minAngleInFlexion: CGFloat = .greatestFiniteMagnitude
    private var flexionEnterTime: CFAbsoluteTime = 0
    private var lastRepTimestamp: CFAbsoluteTime = 0
    
    // Rep gating thresholds
    private let minRepInterval: CFAbsoluteTime = 1.2
    private let minFlexionDwell: CFAbsoluteTime = 0.15
    private let minUpwardVelocity: CGFloat = 20
    
    // LLM coaching integration
    private let llmCoach = LLMCoachInterface()
    
    func loadExercise(_ exercise: DynamicExercise) {
        currentExercise = exercise
        resetSession()
        feedbackMessage = "Get ready for \(exercise.name)"
        
        // Set initial phase
        if let firstPhase = exercise.movementPhases.first {
            currentPhase = firstPhase
            phaseStartTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    func resetSession() {
        repCount = 0
        formScore = 0
        detectedErrors = []
        phaseProgress = 0
        currentAngle = 0
        maxAngle = 0
        inFlexion = false
        phaseHistory = []
        jointAngleHistory = []
        minAngleInFlexion = .greatestFiniteMagnitude
        flexionEnterTime = 0
        lastRepTimestamp = 0
    }
    
    func process(landmarks: [Landmark]) {
        guard let exercise = currentExercise else { return }
        
        let now = CFAbsoluteTimeGetCurrent()
        
        // Calculate primary angle based on exercise type
        let angle = calculatePrimaryAngle(for: exercise, landmarks: landmarks)
        
        // Update angle tracking
        updateAngleTracking(angle: angle, timestamp: now)
        
        // Detect movement phase
        detectMovementPhase(angle: angle, timestamp: now)
        
        // Update rep counting
        updateRepCounting(angle: angle, timestamp: now)
        
        // Calculate form score
        calculateFormScore(landmarks: landmarks)
        
        // Detect errors
        detectFormErrors(landmarks: landmarks, angle: angle)
        
        // Generate LLM feedback
        generateLLMFeedback()
        
        // Store history
        storeAngleHistory(angle: angle, timestamp: now)
    }
    
    private func calculatePrimaryAngle(for exercise: DynamicExercise, landmarks: [Landmark]) -> CGFloat {
        // Determine primary joint based on exercise category
        let primaryMuscles = exercise.muscleGroups
        
        if primaryMuscles.contains("quadriceps") || primaryMuscles.contains("glutes") {
            // Lower body - use knee angle
            return calculateKneeAngle(landmarks: landmarks)
        } else if primaryMuscles.contains("chest") || primaryMuscles.contains("triceps") {
            // Upper body pushing - use elbow angle
            return calculateElbowAngle(landmarks: landmarks)
        } else if primaryMuscles.contains("shoulders") {
            // Shoulder exercises - use shoulder flexion
            return calculateShoulderFlexion(landmarks: landmarks)
        } else {
            // Default to knee angle
            return calculateKneeAngle(landmarks: landmarks)
        }
    }
    
    private func calculateKneeAngle(landmarks: [Landmark]) -> CGFloat {
        guard let leftHip = landmarks.first(where: { $0.jointType?.name == "left_hip" }),
              let leftKnee = landmarks.first(where: { $0.jointType?.name == "left_knee" }),
              let leftAnkle = landmarks.first(where: { $0.jointType?.name == "left_ankle" }),
              leftHip.confidence > 0.5, leftKnee.confidence > 0.5, leftAnkle.confidence > 0.5 else {
            return 0
        }
        
        return Geometry.kneeFlexionAngle(hip: leftHip, knee: leftKnee, ankle: leftAnkle) ?? 0
    }
    
    func calculateElbowAngle(landmarks: [Landmark]) -> CGFloat {
        guard let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
              let leftElbow = landmarks.first(where: { $0.jointType?.name == "left_elbow" }),
              let leftWrist = landmarks.first(where: { $0.jointType?.name == "left_wrist" }),
              leftShoulder.confidence > 0.5, leftElbow.confidence > 0.5, leftWrist.confidence > 0.5 else {
            return 0
        }
        
        return Geometry.angle(leftShoulder.cgPoint, leftElbow.cgPoint, leftWrist.cgPoint)
    }
    
    func calculateShoulderFlexion(landmarks: [Landmark]) -> CGFloat {
        guard let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
              let leftElbow = landmarks.first(where: { $0.jointType?.name == "left_elbow" }),
              let leftHip = landmarks.first(where: { $0.jointType?.name == "left_hip" }),
              leftShoulder.confidence > 0.5, leftElbow.confidence > 0.5, leftHip.confidence > 0.5 else {
            return 0
        }
        
        return Geometry.shoulderFlexionAngle(hip: leftHip, shoulder: leftShoulder, wrist: leftElbow) ?? 0
    }
    
    private func updateAngleTracking(angle: CGFloat, timestamp: CFAbsoluteTime) {
        rawAngle = angle
        
        // Smooth the angle
        let alpha: CGFloat = 0.3
        currentAngle = alpha * angle + (1 - alpha) * currentAngle
        
        // Calculate velocity
        if lastTimestamp > 0 {
            let deltaTime = timestamp - lastTimestamp
            if deltaTime > 0 {
                angleVelocity = (currentAngle - previousAngle) / CGFloat(deltaTime)
            }
        }
        
        // Update max angle
        maxAngle = max(maxAngle, currentAngle)
        
        previousAngle = currentAngle
        lastTimestamp = timestamp
    }
    
    private func detectMovementPhase(angle: CGFloat, timestamp: CFAbsoluteTime) {
        guard let exercise = currentExercise,
              let currentPhase = currentPhase else { return }
        
        // Check if current phase conditions are met
        let phaseComplete = isPhaseComplete(phase: currentPhase, angle: angle, timestamp: timestamp)
        
        if phaseComplete {
            // Move to next phase
            if let currentIndex = exercise.movementPhases.firstIndex(where: { $0.phaseName == currentPhase.phaseName }) {
                let nextIndex = (currentIndex + 1) % exercise.movementPhases.count
                self.currentPhase = exercise.movementPhases[nextIndex]
                phaseStartTime = timestamp
                phaseHistory.append(currentPhase.phaseName)
            }
        }
        
        // Update phase progress
        updatePhaseProgress(phase: currentPhase, angle: angle, timestamp: timestamp)
    }
    
    private func isPhaseComplete(phase: MovementPhase, angle: CGFloat, timestamp: CFAbsoluteTime) -> Bool {
        let phaseElapsed = timestamp - phaseStartTime
        
        // Check minimum duration
        if let duration = phase.durationMs {
            let minDuration = Double(duration.min) / 1000.0
            if phaseElapsed < minDuration {
                return false
            }
        }
        
        // Check angle requirements
        if let primaryJointRange = phase.jointAngles.values.first {
            let inRange = angle >= primaryJointRange.min && angle <= primaryJointRange.max
            
            if phase.holdRequired {
                // For hold phases, need to maintain angle in range
                return inRange && phaseElapsed > 0.5
            } else {
                // For movement phases, need to reach the range
                return inRange
            }
        }
        
        return false
    }
    
    private func updatePhaseProgress(phase: MovementPhase, angle: CGFloat, timestamp: CFAbsoluteTime) {
        if let duration = phase.durationMs {
            let phaseElapsed = timestamp - phaseStartTime
            let maxDuration = Double(duration.max) / 1000.0
            phaseProgress = Float(min(phaseElapsed / maxDuration, 1.0))
        } else {
            // For phases without duration, use angle progress
            if let primaryJointRange = phase.jointAngles.values.first {
                let angleRange = primaryJointRange.max - primaryJointRange.min
                let angleProgress = (angle - primaryJointRange.min) / angleRange
                phaseProgress = Float(max(0, min(angleProgress, 1.0)))
            }
        }
    }
    
    private func updateRepCounting(angle: CGFloat, timestamp: CFAbsoluteTime) {
        guard let exercise = currentExercise else { return }
        
        // Use dynamic thresholds based on exercise
        let (enterThreshold, exitThreshold) = getDynamicThresholds(for: exercise)
        
        let wasInFlexion = inFlexion
        
        // Enter flexion
        if !inFlexion && angle < enterThreshold {
            inFlexion = true
            flexionEnterTime = timestamp
            minAngleInFlexion = angle
            print("🔽 Entered flexion at \(Int(angle))° (threshold: \(Int(enterThreshold))°)")
        }
        
        // Update minimum angle in flexion
        if inFlexion {
            minAngleInFlexion = min(minAngleInFlexion, angle)
        }
        
        // Exit flexion (rep completion)
        if inFlexion && angle > exitThreshold {
            let dwellTime = timestamp - flexionEnterTime
            let timeSinceLastRep = timestamp - lastRepTimestamp
            let bottomAngleReq = getBottomAngleRequirement(for: exercise)
            
            // Rep gating checks
            let validDwell = dwellTime >= minFlexionDwell
            let validInterval = timeSinceLastRep >= minRepInterval
            let validBottomAngle = minAngleInFlexion <= bottomAngleReq
            let validVelocity = angleVelocity >= minUpwardVelocity
            
            if validDwell && validInterval && validBottomAngle && validVelocity {
                repCount += 1
                lastRepTimestamp = timestamp
                playRepChime()
                
                print("✅ REP #\(repCount) - Min angle: \(Int(minAngleInFlexion))°, Dwell: \(String(format: "%.2f", dwellTime))s, Velocity: \(String(format: "%.1f", angleVelocity))°/s")
            } else {
                print("❌ Invalid rep - Dwell: \(validDwell), Interval: \(validInterval), Bottom: \(validBottomAngle), Velocity: \(validVelocity)")
            }
            
            inFlexion = false
            minAngleInFlexion = .greatestFiniteMagnitude
        }
    }
    
    private func getDynamicThresholds(for exercise: DynamicExercise) -> (enter: CGFloat, exit: CGFloat) {
        // Extract thresholds from movement phases
        let phases = exercise.movementPhases
        
        // Find flexion and extension phases
        let flexionPhase = phases.first { phase in
            phase.phaseName.lowercased().contains("descent") ||
            phase.phaseName.lowercased().contains("flexion") ||
            phase.phaseName.lowercased().contains("down")
        }
        
        let extensionPhase = phases.first { phase in
            phase.phaseName.lowercased().contains("ascent") ||
            phase.phaseName.lowercased().contains("extension") ||
            phase.phaseName.lowercased().contains("up")
        }
        
        if let flexionPhase = flexionPhase,
           let primaryJoint = flexionPhase.jointAngles.values.first {
            let enterThreshold = primaryJoint.max // Enter flexion at max angle of flexion phase
            
            if let extensionPhase = extensionPhase,
               let extensionJoint = extensionPhase.jointAngles.values.first {
                let exitThreshold = extensionJoint.min // Exit flexion at min angle of extension phase
                return (enterThreshold, exitThreshold)
            } else {
                return (enterThreshold, enterThreshold + 30) // Default exit threshold
            }
        }
        
        // Fallback to exercise-specific defaults
        let primaryMuscles = exercise.muscleGroups
        
        if primaryMuscles.contains("quadriceps") || primaryMuscles.contains("glutes") {
            return (120, 80) // Knee flexion thresholds
        } else if primaryMuscles.contains("shoulders") {
            return (150, 90) // Shoulder flexion thresholds
        } else {
            return (120, 80) // Default thresholds
        }
    }
    
    private func getBottomAngleRequirement(for exercise: DynamicExercise) -> CGFloat {
        // Find the bottom/hold phase
        let bottomPhase = exercise.movementPhases.first { phase in
            phase.phaseName.lowercased().contains("bottom") ||
            phase.phaseName.lowercased().contains("hold") ||
            phase.holdRequired
        }
        
        if let bottomPhase = bottomPhase,
           let primaryJoint = bottomPhase.jointAngles.values.first {
            return primaryJoint.max // Maximum angle allowed in bottom position
        }
        
        // Fallback based on muscle groups
        let primaryMuscles = exercise.muscleGroups
        
        if primaryMuscles.contains("quadriceps") || primaryMuscles.contains("glutes") {
            return 120 // Knee flexion bottom requirement
        } else if primaryMuscles.contains("shoulders") {
            return 60 // Shoulder flexion bottom requirement
        } else {
            return 120 // Default bottom requirement
        }
    }
    
    private func calculateFormScore(landmarks: [Landmark]) {
        guard let exercise = currentExercise else { return }
        
        var score: Float = 100.0
        
        // Check required landmarks visibility
        let requiredLandmarks = exercise.requiredLandmarks
        let visibleLandmarks = landmarks.filter { $0.confidence > 0.3 }
        let visibilityRatio = Float(visibleLandmarks.count) / Float(requiredLandmarks.count)
        
        if visibilityRatio < 0.8 {
            score -= (1.0 - visibilityRatio) * 30 // Penalize poor visibility
        }
        
        // Check angle consistency
        let angleVariation = abs(currentAngle - rawAngle)
        if angleVariation > 10 {
            score -= Float(angleVariation) * 0.5
        }
        
        // Check velocity consistency
        if abs(angleVelocity) > 100 {
            score -= 10 // Penalize jerky movements
        }
        
        formScore = max(0, min(100, score))
    }
    
    private func detectFormErrors(landmarks: [Landmark], angle: CGFloat) {
        guard let exercise = currentExercise else { return }
        
        detectedErrors = []
        
        // Check each common error from exercise definition
        for error in exercise.commonErrors {
            if evaluateErrorCondition(error: error, landmarks: landmarks, angle: angle) {
                detectedErrors.append(error)
            }
        }
    }
    
    private func evaluateErrorCondition(error: ExerciseError, landmarks: [Landmark], angle: CGFloat) -> Bool {
        let detection = error.detection.lowercased()
        
        // Simple condition evaluation (in practice, would be more sophisticated)
        if detection.contains("form_score") && detection.contains("<") {
            if let threshold = extractNumber(from: detection) {
                return formScore < threshold
            }
        }
        
        if detection.contains("angle") && detection.contains(">") {
            if let threshold = extractNumber(from: detection) {
                return angle > CGFloat(threshold)
            }
        }
        
        if detection.contains("angle") && detection.contains("<") {
            if let threshold = extractNumber(from: detection) {
                return angle < CGFloat(threshold)
            }
        }
        
        return false
    }
    
    private func extractNumber(from string: String) -> Float? {
        let pattern = #"\d+\.?\d*"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let range = NSRange(string.startIndex..., in: string)
        
        if let match = regex?.firstMatch(in: string, range: range) {
            let numberString = String(string[Range(match.range, in: string)!])
            return Float(numberString)
        }
        
        return nil
    }
    
    private func generateLLMFeedback() {
        // Generate contextual feedback using LLM
        Task {
            await llmCoach.generateFeedback(
                exercise: currentExercise,
                angle: currentAngle,
                phase: currentPhase,
                errors: detectedErrors,
                repCount: repCount,
                formScore: formScore
            ) { [weak self] feedback in
                DispatchQueue.main.async {
                    self?.feedbackMessage = feedback
                }
            }
        }
    }
    
    private func storeAngleHistory(angle: CGFloat, timestamp: CFAbsoluteTime) {
        let angleData = ["angle": angle, "timestamp": CGFloat(timestamp)]
        jointAngleHistory.append(angleData)
        
        // Keep only recent history (last 100 data points)
        if jointAngleHistory.count > 100 {
            jointAngleHistory.removeFirst()
        }
    }
    
    private func playRepChime() {
        // Play audio chime
        AudioServicesPlaySystemSound(SystemSoundID(1057))
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        print("🔊 CHIME PLAYED - Rep increment sound triggered")
    }
    
    // MARK: - Public Interface
    
    func getCurrentThresholds() -> (enter: CGFloat, exit: CGFloat) {
        guard let exercise = currentExercise else {
            return (120, 80) // Default
        }
        return getDynamicThresholds(for: exercise)
    }
    
    func getBottomAngleRequirement() -> CGFloat {
        guard let exercise = currentExercise else {
            return 120 // Default
        }
        return getBottomAngleRequirement(for: exercise)
    }
    
    func hasRequiredJoints(landmarks: [Landmark]) -> Bool {
        guard let exercise = currentExercise else { return false }
        
        let requiredLandmarks = exercise.requiredLandmarks
        let visibleLandmarks = landmarks.filter { landmark in
            guard let jointType = landmark.jointType else { return false }
            return requiredLandmarks.contains(jointType.name) && landmark.confidence > 0.3
        }
        
        let occlusionTolerance = exercise.occlusionTolerance
        let requiredRatio = 1.0 - occlusionTolerance
        let visibilityRatio = Float(visibleLandmarks.count) / Float(requiredLandmarks.count)
        
        return visibilityRatio >= requiredRatio
    }
}

// MARK: - LLM Coach Interface

class LLMCoachInterface {
    func generateFeedback(
        exercise: DynamicExercise?,
        angle: CGFloat,
        phase: MovementPhase?,
        errors: [ExerciseError],
        repCount: Int,
        formScore: Float,
        completion: @escaping (String) -> Void
    ) async {
        // Placeholder for LLM integration
        // In practice, would call OpenAI/Claude API with structured prompt
        
        var feedback = "Keep going!"
        
        if let exercise = exercise {
            if !errors.isEmpty {
                feedback = errors.first?.feedback ?? "Check your form"
            } else if formScore > 80 {
                feedback = "Great form! Keep it up!"
            } else if formScore > 60 {
                feedback = "Good work, focus on control"
            } else {
                feedback = "Slow down and focus on form"
            }
            
            if repCount > 0 && repCount % 5 == 0 {
                feedback = "Excellent! \(repCount) reps completed!"
            }
        }
        
        DispatchQueue.main.async {
            completion(feedback)
        }
    }
}
