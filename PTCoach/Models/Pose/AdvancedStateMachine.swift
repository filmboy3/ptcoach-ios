import Foundation
import CoreGraphics
import simd

/// Advanced state machine for exercise tracking with temporal smoothing and validation
class AdvancedStateMachine: ObservableObject {
    
    // MARK: - Exercise States
    enum ExerciseState: String, CaseIterable {
        case idle = "Idle"
        case starting = "Starting"
        case inProgress = "In Progress"
        case peak = "Peak"
        case returning = "Returning"
        case completed = "Completed"
        case invalid = "Invalid"
    }
    
    // MARK: - Published Properties
    @Published var currentState: ExerciseState = .idle
    @Published var repCount: Int = 0
    @Published var currentAngle: CGFloat = 0
    @Published var smoothedAngle: CGFloat = 0
    @Published var angleVelocity: CGFloat = 0
    @Published var formScore: Float = 1.0
    @Published var feedbackMessage: String = ""
    @Published var isValidMovement: Bool = true
    
    // MARK: - Configuration
    private let exerciseInfo: EnhancedExerciseInfo
    private let smoothingFactor: Float = 0.7  // Temporal smoothing factor
    private let velocityThreshold: CGFloat = 5.0  // Minimum velocity for movement detection
    private let holdTimeThreshold: TimeInterval = 0.5  // Time to hold at peak/start
    private let stabilityThreshold: CGFloat = 3.0  // Angle stability requirement
    
    // MARK: - Internal State
    private var angleHistory: [CGFloat] = []
    private var timestampHistory: [TimeInterval] = []
    private var stateStartTime: TimeInterval = 0
    private var lastValidAngle: CGFloat = 0
    private var consecutiveInvalidFrames: Int = 0
    private let maxInvalidFrames: Int = 10
    
    // MARK: - Temporal Smoothing
    private var smoothingBuffer: [CGFloat] = []
    private let bufferSize: Int = 5
    
    init(exerciseInfo: EnhancedExerciseInfo) {
        self.exerciseInfo = exerciseInfo
        self.stateStartTime = CFAbsoluteTimeGetCurrent()
    }
    
    // MARK: - Main Processing Function
    func processFrame(landmarks: [Landmark]) {
        let currentTime = CFAbsoluteTimeGetCurrent()
        
        // Calculate raw angle
        let rawAngle = exerciseInfo.calculator(landmarks)
        
        // Validate landmarks and movement
        let isValidFrame = validateFrame(landmarks: landmarks, angle: rawAngle)
        
        if isValidFrame {
            consecutiveInvalidFrames = 0
            
            // Apply temporal smoothing
            let smoothed = applySmoothingFilter(rawAngle)
            
            // Calculate velocity
            let velocity = calculateVelocity(angle: smoothed, timestamp: currentTime)
            
            // Update published properties
            currentAngle = rawAngle
            smoothedAngle = smoothed
            angleVelocity = velocity
            
            // Process state machine
            processStateMachine(angle: smoothed, velocity: velocity, timestamp: currentTime)
            
            // Update form analysis
            updateFormAnalysis(landmarks: landmarks, angle: smoothed)
            
            lastValidAngle = smoothed
        } else {
            consecutiveInvalidFrames += 1
            
            // If too many invalid frames, reset to idle
            if consecutiveInvalidFrames > maxInvalidFrames {
                resetToIdle()
            }
        }
        
        isValidMovement = isValidFrame
    }
    
    // MARK: - Temporal Smoothing Filter
    private func applySmoothingFilter(_ rawAngle: CGFloat) -> CGFloat {
        // Add to smoothing buffer
        smoothingBuffer.append(rawAngle)
        if smoothingBuffer.count > bufferSize {
            smoothingBuffer.removeFirst()
        }
        
        // Apply weighted moving average
        var weightedSum: CGFloat = 0
        var totalWeight: CGFloat = 0
        
        for (index, angle) in smoothingBuffer.enumerated() {
            let weight = CGFloat(index + 1) // More recent values have higher weight
            weightedSum += angle * weight
            totalWeight += weight
        }
        
        return totalWeight > 0 ? weightedSum / totalWeight : rawAngle
    }
    
    // MARK: - Velocity Calculation
    private func calculateVelocity(angle: CGFloat, timestamp: TimeInterval) -> CGFloat {
        angleHistory.append(angle)
        timestampHistory.append(timestamp)
        
        // Keep only recent history
        let maxHistorySize = 10
        if angleHistory.count > maxHistorySize {
            angleHistory.removeFirst()
            timestampHistory.removeFirst()
        }
        
        // Calculate velocity using linear regression over recent history
        guard angleHistory.count >= 3 else { return 0 }
        
        let recentAngles = Array(angleHistory.suffix(3))
        let recentTimes = Array(timestampHistory.suffix(3))
        
        let deltaAngle = recentAngles.last! - recentAngles.first!
        let deltaTime = recentTimes.last! - recentTimes.first!
        
        return deltaTime > 0 ? CGFloat(deltaAngle / deltaTime) : 0
    }
    
    // MARK: - State Machine Logic
    private func processStateMachine(angle: CGFloat, velocity: CGFloat, timestamp: TimeInterval) {
        let timeInState = timestamp - stateStartTime
        
        switch currentState {
        case .idle:
            // Look for starting position
            if isNearThreshold(angle, exerciseInfo.enterThreshold, tolerance: 10) && 
               abs(velocity) < velocityThreshold {
                transitionToState(.starting, timestamp: timestamp)
            }
            
        case .starting:
            // Ensure stable starting position
            if timeInState > holdTimeThreshold && 
               isStableAtThreshold(angle, exerciseInfo.enterThreshold) {
                transitionToState(.inProgress, timestamp: timestamp)
            } else if !isNearThreshold(angle, exerciseInfo.enterThreshold, tolerance: 15) {
                transitionToState(.idle, timestamp: timestamp)
            }
            
        case .inProgress:
            // Check for peak position
            if isNearThreshold(angle, exerciseInfo.exitThreshold, tolerance: 10) {
                transitionToState(.peak, timestamp: timestamp)
            } else if isNearThreshold(angle, exerciseInfo.enterThreshold, tolerance: 15) {
                // Returned to start without reaching peak
                transitionToState(.starting, timestamp: timestamp)
            }
            
        case .peak:
            // Ensure stable peak position
            if timeInState > holdTimeThreshold && 
               isStableAtThreshold(angle, exerciseInfo.exitThreshold) {
                transitionToState(.returning, timestamp: timestamp)
            } else if !isNearThreshold(angle, exerciseInfo.exitThreshold, tolerance: 15) {
                transitionToState(.inProgress, timestamp: timestamp)
            }
            
        case .returning:
            // Check for return to starting position
            if isNearThreshold(angle, exerciseInfo.enterThreshold, tolerance: 10) {
                transitionToState(.completed, timestamp: timestamp)
            }
            
        case .completed:
            // Rep completed, increment counter and reset
            repCount += 1
            transitionToState(.idle, timestamp: timestamp)
            
        case .invalid:
            // Wait for valid movement to resume
            if validateMovementQuality(angle: angle, velocity: velocity) {
                transitionToState(.idle, timestamp: timestamp)
            }
        }
    }
    
    // MARK: - State Transition
    private func transitionToState(_ newState: ExerciseState, timestamp: TimeInterval) {
        currentState = newState
        stateStartTime = timestamp
        
        // Update feedback message
        updateFeedbackMessage()
    }
    
    // MARK: - Validation Functions
    private func validateFrame(landmarks: [Landmark], angle: CGFloat) -> Bool {
        // Use exercise-specific validator if available
        if let validator = exerciseInfo.validator {
            return validator(landmarks) && angle > 0
        }
        
        // Default validation
        return angle > 0 && angle < 180
    }
    
    private func isNearThreshold(_ angle: CGFloat, _ threshold: CGFloat, tolerance: CGFloat) -> Bool {
        return abs(angle - threshold) <= tolerance
    }
    
    private func isStableAtThreshold(_ angle: CGFloat, _ threshold: CGFloat) -> Bool {
        let recentAngles = Array(angleHistory.suffix(5))
        guard recentAngles.count >= 3 else { return false }
        
        let variance = calculateVariance(recentAngles)
        return variance < stabilityThreshold && isNearThreshold(angle, threshold, tolerance: 8)
    }
    
    private func calculateVariance(_ values: [CGFloat]) -> CGFloat {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / CGFloat(values.count)
        let squaredDifferences = values.map { pow($0 - mean, 2) }
        return squaredDifferences.reduce(0, +) / CGFloat(values.count - 1)
    }
    
    private func validateMovementQuality(angle: CGFloat, velocity: CGFloat) -> Bool {
        // Check for reasonable angle range
        let angleInRange = angle >= 0 && angle <= 180
        
        // Check for reasonable velocity (not too fast)
        let velocityReasonable = abs(velocity) < 100
        
        return angleInRange && velocityReasonable
    }
    
    // MARK: - Form Analysis
    private func updateFormAnalysis(landmarks: [Landmark], angle: CGFloat) {
        // Basic form scoring based on movement smoothness and range
        let smoothnessScore = calculateSmoothnessScore()
        let rangeScore = calculateRangeScore(angle)
        
        formScore = (smoothnessScore + rangeScore) / 2.0
        
        // Generate form feedback
        if formScore < 0.6 {
            feedbackMessage = "Focus on smooth, controlled movement"
        } else if formScore < 0.8 {
            feedbackMessage = "Good form, try for full range of motion"
        } else {
            feedbackMessage = "Excellent form!"
        }
    }
    
    private func calculateSmoothnessScore() -> Float {
        guard angleHistory.count >= 5 else { return 1.0 }
        
        let recentAngles = Array(angleHistory.suffix(5))
        let variance = calculateVariance(recentAngles)
        
        // Lower variance = smoother movement = higher score
        return max(0.0, min(1.0, Float(1.0 - variance / 20.0)))
    }
    
    private func calculateRangeScore(_ currentAngle: CGFloat) -> Float {
        let targetRange = abs(exerciseInfo.exitThreshold - exerciseInfo.enterThreshold)
        let currentRange = abs(currentAngle - exerciseInfo.enterThreshold)
        
        return max(0.0, min(1.0, Float(currentRange / targetRange)))
    }
    
    private func updateFeedbackMessage() {
        switch currentState {
        case .idle:
            feedbackMessage = "Get into starting position"
        case .starting:
            feedbackMessage = "Hold starting position"
        case .inProgress:
            feedbackMessage = "Continue the movement"
        case .peak:
            feedbackMessage = "Hold peak position"
        case .returning:
            feedbackMessage = "Return to start"
        case .completed:
            feedbackMessage = "Rep completed!"
        case .invalid:
            feedbackMessage = "Invalid movement detected"
        }
    }
    
    // MARK: - Reset Functions
    private func resetToIdle() {
        currentState = .idle
        stateStartTime = CFAbsoluteTimeGetCurrent()
        consecutiveInvalidFrames = 0
        feedbackMessage = "Position yourself for exercise"
    }
    
    func reset() {
        repCount = 0
        angleHistory.removeAll()
        timestampHistory.removeAll()
        smoothingBuffer.removeAll()
        resetToIdle()
    }
}
