import Foundation

/// Analyze exercise form and provide corrective feedback
class FormAnalyzer: ObservableObject {
    
    @Published var currentFormScore: Float = 100.0
    @Published var formFeedback: [String] = []
    @Published var safetyWarnings: [String] = []
    
    private var formScoreHistory: [Float] = []
    private let maxHistorySize = 30
    private var errorCounts: [String: Int] = [:]
    private var lastFeedbackTime: [String: Date] = [:]
    private let feedbackCooldown: TimeInterval = 3.0
    
    struct FormError {
        let joint: String
        let deviation: Float
        let message: String
        let severity: Severity
        
        enum Severity {
            case minor, moderate, severe
        }
    }
    
    /// Analyze current form and return score and feedback
    func analyzeForm(exercise: ExerciseInfo,
                    currentAngles: [String: CGFloat],
                    targetAngles: [String: (CGFloat, CGFloat)]?) -> (Float, [String]) {
        
        var formScore: Float = 100.0
        var feedback: [String] = []
        
        guard let targets = targetAngles else {
            return (0.0, ["Cannot determine target angles"])
        }
        
        // Check each tracked joint
        for (joint, (minAngle, maxAngle)) in targets {
            guard let currentAngle = currentAngles[joint] else { continue }
            
            let angle = Float(currentAngle)
            let minTarget = Float(minAngle)
            let maxTarget = Float(maxAngle)
            
            // Calculate deviation
            var deviation: Float = 0
            var feedbackMessage: String?
            
            if angle < minTarget {
                deviation = minTarget - angle
                formScore -= min(deviation * 2, 30) // Max 30 point deduction per joint
                
                if deviation > 15 {
                    feedbackMessage = "\(joint.capitalized): Increase angle by \(Int(deviation))°"
                }
            } else if angle > maxTarget {
                deviation = angle - maxTarget
                formScore -= min(deviation * 2, 30)
                
                if deviation > 15 {
                    feedbackMessage = "\(joint.capitalized): Decrease angle by \(Int(deviation))°"
                }
            }
            
            if let message = feedbackMessage {
                feedback.append(message)
            }
        }
        
        // Track form score history
        formScoreHistory.append(max(0, formScore))
        if formScoreHistory.count > maxHistorySize {
            formScoreHistory.removeFirst()
        }
        
        // Check for consistent poor form
        if formScoreHistory.count >= 10 {
            let recentAverage = formScoreHistory.suffix(10).reduce(0, +) / Float(10)
            if recentAverage < 60 {
                feedback.append("Focus on form - slow down if needed")
            }
        }
        
        let filteredFeedback = filterFeedback(feedback)
        
        // Update published properties
        DispatchQueue.main.async { [weak self] in
            self?.currentFormScore = max(0, formScore)
            self?.formFeedback = filteredFeedback
        }
        
        return (max(0, formScore), filteredFeedback)
    }
    
    /// Check for safety issues
    func checkSafetyConstraints(currentAngles: [String: CGFloat],
                              exercise: ExerciseInfo) -> [String] {
        var warnings: [String] = []
        
        // Check for hyperextension
        for (joint, angle) in currentAngles {
            let angleDegrees = Float(angle)
            
            if joint.contains("elbow") && angleDegrees > 180 {
                warnings.append("⚠️ Elbow hyperextension detected")
            } else if joint.contains("knee") && angleDegrees > 185 {
                warnings.append("⚠️ Knee hyperextension detected")
            } else if joint.contains("shoulder") && angleDegrees > 180 {
                warnings.append("⚠️ Shoulder overextension")
            }
        }
        
        // Check for dangerous velocities (would need velocity data)
        // This could be added when velocity tracking is implemented
        
        // Update published property
        DispatchQueue.main.async { [weak self] in
            self?.safetyWarnings = warnings
        }
        
        return warnings
    }
    
    /// Analyze movement quality based on smoothness and control
    func analyzeMovementQuality(angleHistory: [CGFloat]) -> (Float, String?) {
        guard angleHistory.count >= 5 else {
            return (50.0, nil)
        }
        
        // Calculate smoothness (lower variance = smoother)
        let mean = angleHistory.reduce(0, +) / CGFloat(angleHistory.count)
        let variance = angleHistory.map { pow($0 - mean, 2) }.reduce(0, +) / CGFloat(angleHistory.count)
        let standardDeviation = sqrt(variance)
        
        // Convert to quality score (0-100)
        let smoothnessScore = max(0, 100 - Float(standardDeviation))
        
        var feedback: String?
        if smoothnessScore < 60 {
            feedback = "Movement is jerky - focus on smooth, controlled motion"
        } else if smoothnessScore > 85 {
            feedback = "Excellent movement control!"
        }
        
        return (smoothnessScore, feedback)
    }
    
    /// Get target angles for current exercise phase
    func getTargetAngles(for exercise: ExerciseInfo, 
                        currentState: RepCountingStateMachine.State) -> [String: (CGFloat, CGFloat)]? {
        
        // Map state to target angles based on exercise type
        switch currentState {
        case .extended, .idle:
            return getExtendedTargets(for: exercise)
        case .flexed, .holding:
            return getFlexedTargets(for: exercise)
        case .flexing, .extending:
            return getTransitionTargets(for: exercise)
        }
    }
    
    private func getExtendedTargets(for exercise: ExerciseInfo) -> [String: (CGFloat, CGFloat)] {
        let extendThreshold = exercise.extendThreshold
        let tolerance: CGFloat = 15
        
        switch exercise.jointType {
        case "elbow":
            return [
                "elbow_left": (extendThreshold - tolerance, extendThreshold + tolerance),
                "elbow_right": (extendThreshold - tolerance, extendThreshold + tolerance)
            ]
        case "shoulder":
            return [
                "shoulder_left": (extendThreshold - tolerance, extendThreshold + tolerance)
            ]
        case "knee":
            return [
                "knee_left": (extendThreshold - tolerance, extendThreshold + tolerance)
            ]
        default:
            return [:]
        }
    }
    
    private func getFlexedTargets(for exercise: ExerciseInfo) -> [String: (CGFloat, CGFloat)] {
        let flexThreshold = exercise.flexThreshold
        let tolerance: CGFloat = 15
        
        switch exercise.jointType {
        case "elbow":
            return [
                "elbow_left": (flexThreshold - tolerance, flexThreshold + tolerance),
                "elbow_right": (flexThreshold - tolerance, flexThreshold + tolerance)
            ]
        case "shoulder":
            return [
                "shoulder_left": (flexThreshold - tolerance, flexThreshold + tolerance)
            ]
        case "knee":
            return [
                "knee_left": (flexThreshold - tolerance, flexThreshold + tolerance)
            ]
        default:
            return [:]
        }
    }
    
    private func getTransitionTargets(for exercise: ExerciseInfo) -> [String: (CGFloat, CGFloat)] {
        // During transitions, allow wider range
        let midpoint = (exercise.flexThreshold + exercise.extendThreshold) / 2
        let tolerance: CGFloat = 30
        
        switch exercise.jointType {
        case "elbow":
            return [
                "elbow_left": (midpoint - tolerance, midpoint + tolerance),
                "elbow_right": (midpoint - tolerance, midpoint + tolerance)
            ]
        case "shoulder":
            return [
                "shoulder_left": (midpoint - tolerance, midpoint + tolerance)
            ]
        case "knee":
            return [
                "knee_left": (midpoint - tolerance, midpoint + tolerance)
            ]
        default:
            return [:]
        }
    }
    
    /// Filter feedback to avoid repetition
    private func filterFeedback(_ feedback: [String]) -> [String] {
        let currentTime = Date()
        var filtered: [String] = []
        
        for message in feedback {
            // Check cooldown
            if let lastTime = lastFeedbackTime[message] {
                if currentTime.timeIntervalSince(lastTime) < feedbackCooldown {
                    continue
                }
            }
            
            filtered.append(message)
            lastFeedbackTime[message] = currentTime
        }
        
        // Limit to top 2 most important feedback items
        return Array(filtered.prefix(2))
    }
    
    /// Reset analyzer state
    func reset() {
        formScoreHistory.removeAll()
        errorCounts.removeAll()
        lastFeedbackTime.removeAll()
        
        DispatchQueue.main.async { [weak self] in
            self?.currentFormScore = 100.0
            self?.formFeedback = []
            self?.safetyWarnings = []
        }
    }
    
    /// Get form analysis summary
    func getFormSummary() -> [String: Any] {
        let averageScore = formScoreHistory.isEmpty ? 0 : 
            formScoreHistory.reduce(0, +) / Float(formScoreHistory.count)
        
        return [
            "currentScore": currentFormScore,
            "averageScore": averageScore,
            "totalFeedbackItems": formFeedback.count,
            "safetyWarnings": safetyWarnings.count,
            "historySize": formScoreHistory.count
        ]
    }
}
