import Foundation
import CoreGraphics
import Combine

// MARK: - YOLO Exercise Dataset Models

/// YOLO-compatible exercise reference for real-time tracking
struct YOLOExerciseReference: Codable, Identifiable {
    let exerciseId: String
    let name: String
    let category: [String]
    let difficulty: String
    let bodyOrientation: String
    let cameraAngle: String
    let phases: [YOLOExercisePhase]
    let repDetectionKeypoints: [String]
    let safetyConstraints: [String]
    let formCheckpoints: [String]
    
    var id: String { exerciseId }
    
    enum CodingKeys: String, CodingKey {
        case exerciseId = "exercise_id"
        case name, category, difficulty, phases
        case bodyOrientation = "body_orientation"
        case cameraAngle = "camera_angle"
        case repDetectionKeypoints = "rep_detection_keypoints"
        case safetyConstraints = "safety_constraints"
        case formCheckpoints = "form_checkpoints"
    }
}

/// Single movement phase with YOLO keypoint data
struct YOLOExercisePhase: Codable {
    let name: String
    let keypointSequence: [[Double]]  // COCO-17 format: [[x, y, confidence], ...]
    let targetJointAngles: [String: [Double]]  // [joint: [min, max]]
    let durationRangeMs: [Int]  // [min, max] in milliseconds
    let criticalLandmarks: [String]
    let formTolerances: [String: Double]
    
    enum CodingKeys: String, CodingKey {
        case name
        case keypointSequence = "keypoint_sequence"
        case targetJointAngles = "target_joint_angles"
        case durationRangeMs = "duration_range_ms"
        case criticalLandmarks = "critical_landmarks"
        case formTolerances = "form_tolerances"
    }
}

/// Complete YOLO dataset structure
struct YOLOExerciseDataset: Codable {
    let formatVersion: String
    let keypointFormat: String
    let exercises: [YOLOExerciseReference]
    let metadata: YOLODatasetMetadata
    
    enum CodingKeys: String, CodingKey {
        case formatVersion = "format_version"
        case keypointFormat = "keypoint_format"
        case exercises, metadata
    }
}

struct YOLODatasetMetadata: Codable {
    let totalExercises: Int
    let conversionDate: String
    let coordinateSystem: String
    
    enum CodingKeys: String, CodingKey {
        case totalExercises = "total_exercises"
        case conversionDate = "conversion_date"
        case coordinateSystem = "coordinate_system"
    }
}

// MARK: - Exercise Tracking Models

/// Real-time exercise session tracking
class ExerciseSession: ObservableObject {
    @Published var currentExercise: YOLOExerciseReference?
    @Published var currentPhase: Int = 0
    @Published var repCount: Int = 0
    @Published var isActive: Bool = false
    @Published var formScore: Double = 0.0
    @Published var safetyAlerts: [SafetyAlert] = []
    @Published var sessionDuration: TimeInterval = 0
    
    private var sessionStartTime: Date?
    private var lastRepTime: Date?
    private var phaseStartTime: Date?
    
    func startSession(with exercise: YOLOExerciseReference) {
        currentExercise = exercise
        currentPhase = 0
        repCount = 0
        isActive = true
        formScore = 0.0
        safetyAlerts.removeAll()
        sessionStartTime = Date()
        phaseStartTime = Date()
        sessionDuration = 0
    }
    
    func endSession() {
        isActive = false
        sessionStartTime = nil
        phaseStartTime = nil
        lastRepTime = nil
    }
    
    func recordRep() {
        repCount += 1
        lastRepTime = Date()
    }
    
    func updateFormScore(_ score: Double) {
        formScore = score
    }
    
    func addSafetyAlert(_ alert: SafetyAlert) {
        safetyAlerts.append(alert)
    }
    
    func updateSessionDuration() {
        if let startTime = sessionStartTime {
            sessionDuration = Date().timeIntervalSince(startTime)
        }
    }
}

/// Safety alert for form corrections
struct SafetyAlert: Identifiable {
    let id = UUID()
    let message: String
    let severity: AlertSeverity
    let timestamp: Date
    let affectedJoints: [String]
    
    enum AlertSeverity: CaseIterable {
        case low, medium, high, critical
        
        var color: String {
            switch self {
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            case .critical: return "darkred"
            }
        }
        
        var rawValue: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            case .critical: return "critical"
            }
        }
    }
}

// MARK: - Rep Detection Models

/// Rep detection state machine
class RepDetector: ObservableObject {
    @Published var currentState: RepState = .neutral
    @Published var confidence: Double = 0.0
    
    private let keypointsToTrack: [String]
    private let thresholds: RepThresholds
    private var stateHistory: [RepState] = []
    
    init(keypointsToTrack: [String], thresholds: RepThresholds = RepThresholds()) {
        self.keypointsToTrack = keypointsToTrack
        self.thresholds = thresholds
    }
    
    func updateState(with keypoints: [CGPoint], targetPhase: YOLOExercisePhase) -> Bool {
        let newState = analyzeMovementState(keypoints: keypoints, targetPhase: targetPhase)
        let repCompleted = detectRepCompletion(newState: newState)
        
        stateHistory.append(newState)
        if stateHistory.count > 10 {
            stateHistory.removeFirst()
        }
        
        currentState = newState
        return repCompleted
    }
    
    private func analyzeMovementState(keypoints: [CGPoint], targetPhase: YOLOExercisePhase) -> RepState {
        // Analyze keypoint positions relative to target phase
        let similarity = calculatePhaseSimilarity(keypoints: keypoints, targetPhase: targetPhase)
        confidence = similarity
        
        if similarity > thresholds.completionThreshold {
            return .peakPosition
        } else if similarity > thresholds.transitionThreshold {
            return .transitioning
        } else {
            return .neutral
        }
    }
    
    private func detectRepCompletion(newState: RepState) -> Bool {
        // Look for complete cycle: neutral -> transitioning -> peak -> transitioning -> neutral
        if stateHistory.count >= 5 {
            let pattern = stateHistory.suffix(5)
            return pattern.contains(.neutral) && 
                   pattern.contains(.transitioning) && 
                   pattern.contains(.peakPosition)
        }
        return false
    }
    
    private func calculatePhaseSimilarity(keypoints: [CGPoint], targetPhase: YOLOExercisePhase) -> Double {
        guard keypoints.count >= 17 else { return 0.0 }
        
        let targetKeypoints = targetPhase.keypointSequence
        guard targetKeypoints.count >= 17 else { return 0.0 }
        
        var totalDistance: Double = 0.0
        var validPoints = 0
        
        for i in 0..<min(keypoints.count, 17) {
            if targetKeypoints[i].count >= 3 && targetKeypoints[i][2] > 0.5 { // confidence > 0.5
                let targetX = targetKeypoints[i][0]
                let targetY = targetKeypoints[i][1]
                
                let distance = sqrt(pow(Double(keypoints[i].x) - targetX, 2) + 
                                  pow(Double(keypoints[i].y) - targetY, 2))
                totalDistance += distance
                validPoints += 1
            }
        }
        
        if validPoints == 0 { return 0.0 }
        
        let averageDistance = totalDistance / Double(validPoints)
        return max(0.0, 1.0 - (averageDistance * 2.0)) // Convert distance to similarity score
    }
}

enum RepState {
    case neutral
    case transitioning
    case peakPosition
    case holding
}

struct RepThresholds {
    let completionThreshold: Double
    let transitionThreshold: Double
    let holdingThreshold: Double
    
    init(completionThreshold: Double = 0.8, 
         transitionThreshold: Double = 0.6, 
         holdingThreshold: Double = 0.85) {
        self.completionThreshold = completionThreshold
        self.transitionThreshold = transitionThreshold
        self.holdingThreshold = holdingThreshold
    }
}

// MARK: - Form Analysis Models

/// Real-time form analysis engine
class FormAnalyzer: ObservableObject {
    @Published var currentFormScore: Double = 0.0
    @Published var jointAnalysis: [String: JointAnalysis] = [:]
    @Published var formFeedback: [FormFeedback] = []
    
    private let tolerances: FormTolerances
    
    init(tolerances: FormTolerances = FormTolerances()) {
        self.tolerances = tolerances
    }
    
    func analyzeForm(keypoints: [CGPoint], targetPhase: YOLOExercisePhase) -> FormAnalysisResult {
        var jointScores: [String: Double] = [:]
        var feedback: [FormFeedback] = []
        
        // Analyze each target joint angle
        for (joint, targetRange) in targetPhase.targetJointAngles {
            if let currentAngle = calculateJointAngle(joint: joint, keypoints: keypoints) {
                let score = evaluateJointAngle(
                    current: currentAngle,
                    target: targetRange,
                    tolerance: tolerances.angleTolerance
                )
                jointScores[joint] = score
                
                if score < tolerances.feedbackThreshold {
                    let feedbackMessage = generateJointFeedback(joint: joint, 
                                                              current: currentAngle, 
                                                              target: targetRange)
                    feedback.append(FormFeedback(message: feedbackMessage, 
                                               joint: joint, 
                                               severity: score < 0.5 ? .high : .medium))
                }
            }
        }
        
        let overallScore = jointScores.values.isEmpty ? 0.0 : 
                          jointScores.values.reduce(0, +) / Double(jointScores.count)
        
        currentFormScore = overallScore
        formFeedback = feedback
        
        return FormAnalysisResult(
            overallScore: overallScore,
            jointScores: jointScores,
            feedback: feedback,
            safetyAlerts: generateSafetyAlerts(jointScores: jointScores)
        )
    }
    
    private func calculateJointAngle(joint: String, keypoints: [CGPoint]) -> Double? {
        // Map joint names to keypoint indices and calculate angles
        switch joint.lowercased() {
        case "shoulder_flexion_l", "shoulder_flexion_left":
            return calculateAngle(p1: keypoints[5], p2: keypoints[7], p3: keypoints[9]) // shoulder-elbow-wrist
        case "shoulder_flexion_r", "shoulder_flexion_right":
            return calculateAngle(p1: keypoints[6], p2: keypoints[8], p3: keypoints[10])
        case "elbow_flexion_l", "elbow_flexion_left":
            return calculateAngle(p1: keypoints[5], p2: keypoints[7], p3: keypoints[9])
        case "elbow_flexion_r", "elbow_flexion_right":
            return calculateAngle(p1: keypoints[6], p2: keypoints[8], p3: keypoints[10])
        case "hip_flexion_l", "hip_flexion_left":
            return calculateAngle(p1: keypoints[11], p2: keypoints[13], p3: keypoints[15]) // hip-knee-ankle
        case "hip_flexion_r", "hip_flexion_right":
            return calculateAngle(p1: keypoints[12], p2: keypoints[14], p3: keypoints[16])
        case "knee_flexion_l", "knee_flexion_left":
            return calculateAngle(p1: keypoints[11], p2: keypoints[13], p3: keypoints[15])
        case "knee_flexion_r", "knee_flexion_right":
            return calculateAngle(p1: keypoints[12], p2: keypoints[14], p3: keypoints[16])
        default:
            return nil
        }
    }
    
    private func calculateAngle(p1: CGPoint, p2: CGPoint, p3: CGPoint) -> Double {
        let v1 = CGPoint(x: p1.x - p2.x, y: p1.y - p2.y)
        let v2 = CGPoint(x: p3.x - p2.x, y: p3.y - p2.y)
        
        let dot = v1.x * v2.x + v1.y * v2.y
        let mag1 = sqrt(v1.x * v1.x + v1.y * v1.y)
        let mag2 = sqrt(v2.x * v2.x + v2.y * v2.y)
        
        if mag1 == 0 || mag2 == 0 { return 0 }
        
        let cosAngle = dot / (mag1 * mag2)
        let clampedCos = max(-1.0, min(1.0, cosAngle))
        return acos(clampedCos) * 180.0 / .pi
    }
    
    private func evaluateJointAngle(current: Double, target: [Double], tolerance: Double) -> Double {
        guard target.count >= 2 else { return 0.0 }
        
        let minTarget = target[0]
        let maxTarget = target[1]
        
        if current >= minTarget - tolerance && current <= maxTarget + tolerance {
            return 1.0 // Perfect
        } else {
            let distance = min(abs(current - minTarget), abs(current - maxTarget))
            return max(0.0, 1.0 - (distance / (tolerance * 2)))
        }
    }
    
    private func generateJointFeedback(joint: String, current: Double, target: [Double]) -> String {
        guard target.count >= 2 else { return "Invalid target range" }
        
        let minTarget = target[0]
        let maxTarget = target[1]
        let midTarget = (minTarget + maxTarget) / 2
        
        if current < minTarget {
            return "Increase \(joint.replacingOccurrences(of: "_", with: " ")) angle"
        } else if current > maxTarget {
            return "Decrease \(joint.replacingOccurrences(of: "_", with: " ")) angle"
        } else {
            return "\(joint.replacingOccurrences(of: "_", with: " ")) looks good"
        }
    }
    
    private func generateSafetyAlerts(jointScores: [String: Double]) -> [SafetyAlert] {
        var alerts: [SafetyAlert] = []
        
        for (joint, score) in jointScores {
            if score < tolerances.safetyThreshold {
                let alert = SafetyAlert(
                    message: "Check \(joint.replacingOccurrences(of: "_", with: " ")) alignment",
                    severity: score < 0.3 ? .critical : .high,
                    timestamp: Date(),
                    affectedJoints: [joint]
                )
                alerts.append(alert)
            }
        }
        
        return alerts
    }
}

struct FormAnalysisResult {
    let overallScore: Double
    let jointScores: [String: Double]
    let feedback: [FormFeedback]
    let safetyAlerts: [SafetyAlert]
}

struct FormFeedback: Identifiable {
    let id = UUID()
    let message: String
    let joint: String
    let severity: SafetyAlert.AlertSeverity
    let timestamp = Date()
}

struct JointAnalysis {
    let currentAngle: Double
    let targetRange: [Double]
    let score: Double
    let feedback: String
}

struct FormTolerances {
    let angleTolerance: Double
    let positionTolerance: Double
    let feedbackThreshold: Double
    let safetyThreshold: Double
    
    init(angleTolerance: Double = 15.0,
         positionTolerance: Double = 0.1,
         feedbackThreshold: Double = 0.7,
         safetyThreshold: Double = 0.4) {
        self.angleTolerance = angleTolerance
        self.positionTolerance = positionTolerance
        self.feedbackThreshold = feedbackThreshold
        self.safetyThreshold = safetyThreshold
    }
}
