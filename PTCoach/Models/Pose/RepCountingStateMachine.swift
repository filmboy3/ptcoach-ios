import Foundation

/// Robust state machine for accurate rep counting
class RepCountingStateMachine: ObservableObject {
    
    enum State: String, CaseIterable {
        case idle = "idle"
        case extending = "extending"
        case extended = "extended"
        case flexing = "flexing"
        case flexed = "flexed"
        case holding = "holding"
    }
    
    @Published var currentState: State = .idle
    @Published var repCount: Int = 0
    @Published var feedbackMessage: String = ""
    
    private let exercise: ExerciseInfo
    private var phaseHistory: [PhaseRecord] = []
    private var stateStartTime: Date = Date()
    private var lastRepTime: Date = Date.distantPast
    private let minRepInterval: TimeInterval = 0.8 // Minimum seconds between reps
    private var holdStartTime: Date?
    private let requiredHoldTime: TimeInterval = 0.5 // seconds
    
    // Velocity tracking
    private var angleVelocity: CGFloat = 0
    private var lastAngle: CGFloat?
    private var lastAngleTime: Date?
    
    struct PhaseRecord {
        let state: String
        let duration: TimeInterval
        let timestamp: Date
    }
    
    init(exercise: ExerciseInfo) {
        self.exercise = exercise
    }
    
    /// Update state machine with current angle
    /// Returns: (rep_completed, feedback_message)
    func update(currentAngle: CGFloat) -> (Bool, String) {
        let currentTime = Date()
        
        // Calculate velocity
        if let lastAngle = lastAngle, let lastAngleTime = lastAngleTime {
            let dt = currentTime.timeIntervalSince(lastAngleTime)
            if dt > 0 {
                angleVelocity = (currentAngle - lastAngle) / CGFloat(dt)
            }
        }
        
        lastAngle = currentAngle
        lastAngleTime = currentTime
        
        // State transitions
        var repCompleted = false
        var feedback = ""
        
        switch currentState {
        case .idle:
            if currentAngle < exercise.extendThreshold {
                transitionTo(.extended)
                feedback = "Ready position"
            }
            
        case .extended:
            if currentAngle > exercise.extendThreshold + 10 {
                transitionTo(.flexing)
                feedback = "Starting movement"
            }
            
        case .flexing:
            if currentAngle > exercise.flexThreshold {
                transitionTo(.flexed)
                feedback = "Good flexion"
            } else if angleVelocity < -5 { // Moving back without reaching flex
                transitionTo(.extending)
                feedback = "Incomplete flexion"
            }
            
        case .flexed:
            // Check for hold requirement
            if shouldHold() {
                if holdStartTime == nil {
                    holdStartTime = currentTime
                } else if currentTime.timeIntervalSince(holdStartTime!) >= requiredHoldTime {
                    transitionTo(.holding)
                    feedback = "Hold complete"
                }
            } else {
                if currentAngle < exercise.flexThreshold - 10 {
                    transitionTo(.extending)
                    feedback = "Returning"
                }
            }
            
        case .holding:
            if currentAngle < exercise.flexThreshold - 10 {
                transitionTo(.extending)
                feedback = "Returning"
            }
            
        case .extending:
            if currentAngle < exercise.extendThreshold {
                // Check if this completes a valid rep
                if isValidRep() {
                    repCount += 1
                    repCompleted = true
                    feedback = "Rep \(repCount) complete!"
                    lastRepTime = currentTime
                }
                transitionTo(.extended)
            }
        }
        
        feedbackMessage = feedback
        return (repCompleted, feedback)
    }
    
    private func transitionTo(_ newState: State) {
        let currentTime = Date()
        
        // Record phase history
        let phaseRecord = PhaseRecord(
            state: currentState.rawValue,
            duration: currentTime.timeIntervalSince(stateStartTime),
            timestamp: currentTime
        )
        phaseHistory.append(phaseRecord)
        
        // Keep only last 10 phases
        if phaseHistory.count > 10 {
            phaseHistory.removeFirst()
        }
        
        currentState = newState
        stateStartTime = currentTime
        
        // Reset hold timer on state change
        if newState != .flexed {
            holdStartTime = nil
        }
    }
    
    private func shouldHold() -> Bool {
        // For now, determine hold requirement based on exercise name
        let exerciseName = exercise.name.lowercased()
        return exerciseName.contains("hold") || exerciseName.contains("pause")
    }
    
    private func isValidRep() -> Bool {
        let currentTime = Date()
        
        // Check minimum time between reps
        if currentTime.timeIntervalSince(lastRepTime) < minRepInterval {
            return false
        }
        
        // Check phase history for complete movement
        let recentStates = phaseHistory.suffix(5).map { $0.state }
        
        // Must have gone through flexed state
        if !recentStates.contains("flexed") && !recentStates.contains("holding") {
            return false
        }
        
        // Must have started from extended (not in very recent history)
        let olderStates = phaseHistory.prefix(max(0, phaseHistory.count - 2)).map { $0.state }
        if !olderStates.contains("extended") {
            return false
        }
        
        return true
    }
    
    /// Reset the state machine
    func reset() {
        currentState = .idle
        repCount = 0
        phaseHistory.removeAll()
        stateStartTime = Date()
        lastRepTime = Date.distantPast
        holdStartTime = nil
        lastAngle = nil
        lastAngleTime = nil
        angleVelocity = 0
        feedbackMessage = ""
    }
    
    /// Get current state information for debugging
    func getStateInfo() -> [String: Any] {
        return [
            "state": currentState.rawValue,
            "repCount": repCount,
            "velocity": angleVelocity,
            "phaseHistory": phaseHistory.suffix(3).map { "\($0.state)(\(String(format: "%.1f", $0.duration))s)" },
            "feedback": feedbackMessage
        ]
    }
}
