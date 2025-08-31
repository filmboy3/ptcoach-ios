import Foundation
import CoreGraphics

/// Engine for processing pose landmarks into angles and rep counts
class AngleEngine: ObservableObject {
    @Published var currentAngle: CGFloat = 0
    @Published var maxAngle: CGFloat = 0
    @Published var repCount = 0
    @Published var feedbackMessage = "Get ready..."
    @Published var inFlexion = false
    // Debug-exposed values
    var rawAngle: CGFloat = 0
    var angleVelocity: CGFloat = 0 // degrees per second
    
    private var exerciseType: ExerciseType = .kneeFlexion
    private var previousAngle: CGFloat = 0
    private var lastTimestamp: CFAbsoluteTime = 0
    
    // Rep gating state
    private var minAngleInFlexion: CGFloat = .greatestFiniteMagnitude
    private var flexionEnterTime: CFAbsoluteTime = 0
    private var lastRepTimestamp: CFAbsoluteTime = 0
    
    // Rep gating thresholds
    private let minRepInterval: CFAbsoluteTime = 1.2 // seconds
    private let minFlexionDwell: CFAbsoluteTime = 0.15 // seconds inside flexion before eligible
    private let minUpwardVelocity: CGFloat = 20 // deg/s required when exiting flexion
    
    // Default hysteresis thresholds (used only as fallback)
    private let defaultEnterThreshold: CGFloat = 120
    private let defaultExitThreshold: CGFloat = 160
    
    func startSession(for type: ExerciseType) {
        exerciseType = type
        repCount = 0
        currentAngle = 0
        maxAngle = 0
        previousAngle = 0
        inFlexion = false
        feedbackMessage = "Position yourself in the camera view"
        rawAngle = 0
        angleVelocity = 0
        lastTimestamp = 0
        // Reset rep gating state
        minAngleInFlexion = .greatestFiniteMagnitude
        flexionEnterTime = 0
        lastRepTimestamp = 0
    }

    private func thresholds() -> (enter: CGFloat, exit: CGFloat) {
        switch exerciseType {
        case .kneeFlexion:
            // Based on exercise guidelines: seated knee flexion, side view preferred
            return (enter: 120, exit: 80) // Enter flexion at 120°, exit when extending to 80°
        case .sitToStand:
            // Full sit-to-stand cycle with hip/knee extension at top
            return (enter: 130, exit: 10) // Enter at sit (130°), exit when standing (10°)
        case .shoulderFlexion:
            // Shoulder flexion: angle decreases as arm raises (0° overhead, ~180° by side)
            return (enter: 150, exit: 90) // Enter flexion at 150°, exit when lowering to 90°
        }
    }
    
    // Expose thresholds for debug/UI without duplicating logic
    var debugThresholds: (enter: CGFloat, exit: CGFloat) { thresholds() }
    
    func process(landmarks: [Landmark]) {
        print("\n🔍 ANGLE ENGINE PROCESSING")
        print("📍 Received \(landmarks.count) landmarks")
        
        guard hasRequiredJoints(landmarks) else {
            feedbackMessage = "I can't see all required joints - adjust your position"
            print("❌ Missing required joints for \(exerciseType)")
            return
        }
        
        let angle = calculateAngle(landmarks: landmarks)
        rawAngle = angle
        print("📐 Raw angle calculated: \(String(format: "%.1f", angle))°")
        
        guard !angle.isNaN && angle > 0 else { 
            print("❌ Invalid angle: \(angle)")
            return 
        }
        
        // Apply smoothing
        currentAngle = Geometry.smoothAngle(current: angle, previous: previousAngle)
        maxAngle = max(maxAngle, currentAngle)
        
        // Compute velocity (deg/s) based on time delta
        let now = CFAbsoluteTimeGetCurrent()
        if lastTimestamp > 0 {
            let dt = now - lastTimestamp
            if dt > 0 {
                angleVelocity = (currentAngle - previousAngle) / CGFloat(dt)
            }
        }
        lastTimestamp = now
        
        print("📊 Current: \(String(format: "%.1f", currentAngle))° | Max: \(String(format: "%.1f", maxAngle))°")
        print("🎯 Rep state: inFlexion=\(inFlexion) | Count=\(repCount)")
        
        // Rep counting with hysteresis
        updateRepCount()
        
        // Form feedback
        updateFeedback()
        
        previousAngle = currentAngle
    }
    
    private func calculateAngle(landmarks: [Landmark]) -> CGFloat {
        switch exerciseType {
        case .kneeFlexion:
            return Geometry.kneeFlexionAngle(
                hip: landmarks[11],
                knee: landmarks[13],
                ankle: landmarks[15]
            ) ?? 0
            
        case .shoulderFlexion:
            return Geometry.shoulderFlexionAngle(
                hip: landmarks[11],
                shoulder: landmarks[5],
                wrist: landmarks[9]
            ) ?? 0
            
        case .sitToStand:
            let leftKnee = Geometry.kneeFlexionAngle(
                hip: landmarks[11],
                knee: landmarks[13],
                ankle: landmarks[15]
            ) ?? 0
            let rightKnee = Geometry.kneeFlexionAngle(
                hip: landmarks[12],
                knee: landmarks[14],
                ankle: landmarks[16]
            ) ?? 0
            return (leftKnee + rightKnee) / 2
        }
    }
    
    private func bottomAngleRequirement() -> CGFloat {
        switch exerciseType {
        case .kneeFlexion:
            return 120 // must reach <= 120° at bottom (seated knee flexion target)
        case .sitToStand:
            return 120 // must reach <= 120° to confirm full sit
        case .shoulderFlexion:
            return 60 // must reach <= 60° overhead (shoulder flexion target)
        }
    }
    
    private func updateRepCount() {
        let wasInFlexion = inFlexion
        let now = CFAbsoluteTimeGetCurrent()
        let (enterThreshold, exitThreshold) = thresholds()
        
        if !inFlexion && currentAngle < enterThreshold {
            inFlexion = true
            flexionEnterTime = now
            minAngleInFlexion = currentAngle
            print("🔽 ENTERED FLEXION at \(String(format: "%.1f", currentAngle))° (enter<\(enterThreshold)°) | dwell≥\(String(format: "%.2f", minFlexionDwell))s")
        } else if inFlexion {
            // Track the deepest angle reached while in flexion
            minAngleInFlexion = min(minAngleInFlexion, currentAngle)
            
            // Check exit condition (leaving flexion)
            if currentAngle > exitThreshold {
                inFlexion = false
                let dwellOK = (now - flexionEnterTime) >= minFlexionDwell
                let bottomOK = minAngleInFlexion <= bottomAngleRequirement()
                let velOK = angleVelocity >= minUpwardVelocity
                let intervalOK = (now - lastRepTimestamp) >= minRepInterval
                
                if dwellOK && bottomOK && velOK && intervalOK {
                    repCount += 1
                    lastRepTimestamp = now
                    print("🔼 EXITED FLEXION at \(String(format: "%.1f", currentAngle))° (exit>\(exitThreshold)°)")
                    print("🎉 REP COMPLETED! New count: \(repCount) | bottom=\(String(format: "%.1f", minAngleInFlexion))° | vel=\(String(format: "%.1f", angleVelocity))°/s")
                } else {
                    print("⚠️ REP REJECTED | dwellOK=\(dwellOK) bottomOK=\(bottomOK) (min=\(String(format: "%.1f", minAngleInFlexion))° req≤\(bottomAngleRequirement())°) vel=\(String(format: "%.1f", angleVelocity))°/s req≥\(minUpwardVelocity) intervalOK=\(intervalOK)")
                }
            }
        }
        
        if wasInFlexion != inFlexion {
            print("🔄 State changed: \(wasInFlexion ? "flexion" : "extension") → \(inFlexion ? "flexion" : "extension")")
        }
    }
    
    private func updateFeedback() {
        switch exerciseType {
        case .kneeFlexion:
            feedbackMessage = Geometry.KneeFlexion.getFormFeedback(angle: currentAngle)
        case .shoulderFlexion:
            feedbackMessage = Geometry.ShoulderFlexion.getFormFeedback(angle: currentAngle)
        case .sitToStand:
            let phase = Geometry.SitToStand.detectPhase(kneeAngle: currentAngle)
            switch phase {
            case .sitting:
                feedbackMessage = "Ready to stand up"
            case .transition:
                feedbackMessage = "Good transition"
            case .standing:
                feedbackMessage = "Great! Now sit back down"
            }
        }
    }
    
    private func hasRequiredJoints(_ landmarks: [Landmark]) -> Bool {
        switch exerciseType {
        case .kneeFlexion:
            // More lenient: allow temporary occlusion during movement
            let keyJoints = [11, 13, 15] // left hip, knee, ankle (primary side)
            let visibleCount = keyJoints.compactMap { idx in
                idx < landmarks.count && landmarks[idx].confidence > 0.3 ? 1 : nil
            }.count
            return visibleCount >= 2 // At least 2 of 3 key joints
        case .shoulderFlexion:
            // Allow temporary occlusion of wrist during movement
            let keyJoints = [5, 7, 9, 11] // left shoulder, elbow, wrist, hip
            let visibleCount = keyJoints.compactMap { idx in
                idx < landmarks.count && landmarks[idx].confidence > 0.3 ? 1 : nil
            }.count
            return visibleCount >= 3 // At least 3 of 4 key joints
        case .sitToStand:
            // Allow temporary occlusion during transition
            let keyJoints = [11, 12, 13, 14] // hips and knees (core for sit-to-stand)
            let visibleCount = keyJoints.compactMap { idx in
                idx < landmarks.count && landmarks[idx].confidence > 0.3 ? 1 : nil
            }.count
            return visibleCount >= 3 // At least 3 of 4 key joints
        }
    }
}
