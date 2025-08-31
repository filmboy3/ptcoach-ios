import Foundation
import CoreGraphics
import simd

/// Geometry utilities for pose analysis and angle calculations
struct Geometry {
    
    // MARK: - Angle Calculations
    
    /// Calculate angle between three points (vertex at point b)
    /// - Parameters:
    ///   - a: First point
    ///   - b: Vertex point (angle measured here)
    ///   - c: Third point
    /// - Returns: Angle in degrees (0-180)
    static func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat {
        let v1 = normalize(CGPoint(x: a.x - b.x, y: a.y - b.y))
        let v2 = normalize(CGPoint(x: c.x - b.x, y: c.y - b.y))
        
        let dot = clamp(v1.x * v2.x + v1.y * v2.y, -1.0, 1.0)
        let angleRadians = acos(dot)
        
        return angleRadians * 180.0 / .pi
    }
    
    /// Calculate angle between three landmarks
    static func angle(_ a: Landmark, _ b: Landmark, _ c: Landmark) -> CGFloat {
        return angle(a.cgPoint, b.cgPoint, c.cgPoint)
    }
    
    /// Calculate knee flexion angle (hip-knee-ankle)
    static func kneeFlexionAngle(hip: Landmark, knee: Landmark, ankle: Landmark) -> CGFloat? {
        guard hip.isVisible && knee.isVisible && ankle.isVisible else { return nil }
        return angle(hip, knee, ankle)
    }
    
    /// Calculate shoulder flexion angle relative to trunk
    static func shoulderFlexionAngle(hip: Landmark, shoulder: Landmark, wrist: Landmark) -> CGFloat? {
        guard hip.isVisible && shoulder.isVisible && wrist.isVisible else { return nil }
        
        // Create vertical reference line from shoulder
        let verticalRef = CGPoint(x: CGFloat(shoulder.x), y: CGFloat(shoulder.y) - 0.1)
        return angle(verticalRef, shoulder.cgPoint, wrist.cgPoint)
    }
    
    /// Calculate shoulder abduction angle
    static func shoulderAbductionAngle(shoulder: Landmark, elbow: Landmark, oppositeHip: Landmark) -> CGFloat? {
        guard shoulder.isVisible && elbow.isVisible && oppositeHip.isVisible else { return nil }
        
        // Use opposite hip to establish body midline reference
        let horizontalRef = CGPoint(x: CGFloat(shoulder.x) + 0.1, y: CGFloat(shoulder.y))
        return angle(horizontalRef, shoulder.cgPoint, elbow.cgPoint)
    }
    
    // MARK: - Distance and Movement
    
    /// Calculate Euclidean distance between two points
    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
    
    /// Calculate distance between two landmarks
    static func distance(_ a: Landmark, _ b: Landmark) -> CGFloat {
        return distance(a.cgPoint, b.cgPoint)
    }
    
    /// Calculate vertical displacement (useful for sit-to-stand detection)
    static func verticalDisplacement(_ a: Landmark, _ b: Landmark) -> CGFloat {
        return CGFloat(abs(a.y - b.y))
    }
    
    // MARK: - Body Pose Analysis
    
    /// Detect if person is in sitting position based on hip and knee angles
    static func isSittingPosition(leftHip: Landmark, leftKnee: Landmark, leftAnkle: Landmark,
                                 rightHip: Landmark, rightKnee: Landmark, rightAnkle: Landmark) -> Bool {
        guard let leftKneeAngle = kneeFlexionAngle(hip: leftHip, knee: leftKnee, ankle: leftAnkle),
              let rightKneeAngle = kneeFlexionAngle(hip: rightHip, knee: rightKnee, ankle: rightAnkle) else {
            return false
        }
        
        // Sitting typically has knee angles < 120 degrees
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2
        return avgKneeAngle < 120
    }
    
    /// Detect if person is in standing position
    static func isStandingPosition(leftHip: Landmark, leftKnee: Landmark, leftAnkle: Landmark,
                                  rightHip: Landmark, rightKnee: Landmark, rightAnkle: Landmark) -> Bool {
        guard let leftKneeAngle = kneeFlexionAngle(hip: leftHip, knee: leftKnee, ankle: leftAnkle),
              let rightKneeAngle = kneeFlexionAngle(hip: rightHip, knee: rightKnee, ankle: rightAnkle) else {
            return false
        }
        
        // Standing typically has knee angles > 160 degrees
        let avgKneeAngle = (leftKneeAngle + rightKneeAngle) / 2
        return avgKneeAngle > 160
    }
    
    /// Calculate body center of mass approximation
    static func bodyCenterOfMass(leftHip: Landmark, rightHip: Landmark) -> CGPoint? {
        guard leftHip.isVisible && rightHip.isVisible else { return nil }
        
        return CGPoint(
            x: CGFloat(leftHip.x + rightHip.x) / 2,
            y: CGFloat(leftHip.y + rightHip.y) / 2
        )
    }
    
    // MARK: - Quality Assessment
    
    /// Assess pose quality based on landmark confidence
    static func poseQuality(landmarks: [Landmark]) -> Float {
        guard !landmarks.isEmpty else { return 0.0 }
        
        let totalConfidence = landmarks.reduce(0) { $0 + $1.confidence }
        return totalConfidence / Float(landmarks.count)
    }
    
    /// Check if key joints are visible for a specific exercise
    static func hasRequiredJointsForKneeFlexion(landmarks: [Landmark]) -> Bool {
        // Assuming COCO format indices
        let requiredIndices = [11, 12, 13, 14, 15, 16] // hips, knees, ankles
        
        for index in requiredIndices {
            guard index < landmarks.count else { return false }
            if !landmarks[index].isVisible { return false }
        }
        
        return true
    }
    
    /// Check if key joints are visible for shoulder exercises
    static func hasRequiredJointsForShoulder(landmarks: [Landmark]) -> Bool {
        // Assuming COCO format indices
        let requiredIndices = [5, 6, 7, 8, 9, 10, 11, 12] // shoulders, elbows, wrists, hips
        
        for index in requiredIndices {
            guard index < landmarks.count else { return false }
            if !landmarks[index].isVisible { return false }
        }
        
        return true
    }
    
    // MARK: - Utility Functions
    
    /// Normalize a vector
    private static func normalize(_ point: CGPoint) -> CGPoint {
        let magnitude = sqrt(point.x * point.x + point.y * point.y)
        guard magnitude > 0 else { return CGPoint.zero }
        
        return CGPoint(x: point.x / magnitude, y: point.y / magnitude)
    }
    
    /// Clamp a value between min and max
    private static func clamp(_ value: CGFloat, _ min: CGFloat, _ max: CGFloat) -> CGFloat {
        return Swift.max(min, Swift.min(max, value))
    }
    
    /// Convert degrees to radians
    static func degreesToRadians(_ degrees: CGFloat) -> CGFloat {
        return degrees * .pi / 180.0
    }
    
    /// Convert radians to degrees
    static func radiansToDegrees(_ radians: CGFloat) -> CGFloat {
        return radians * 180.0 / .pi
    }
    
    /// Apply low-pass filter to smooth angle values
    static func smoothAngle(current: CGFloat, previous: CGFloat, alpha: CGFloat = 0.6) -> CGFloat {
        return alpha * current + (1 - alpha) * previous
    }
    
    /// Check if angle is within a target range (for form assessment)
    static func isAngleInRange(_ angle: CGFloat, target: CGFloat, tolerance: CGFloat = 10.0) -> Bool {
        return abs(angle - target) <= tolerance
    }
}

// MARK: - Exercise-Specific Helpers

extension Geometry {
    
    /// Knee flexion exercise analysis
    struct KneeFlexion {
        static let minFlexionAngle: CGFloat = 90
        static let maxFlexionAngle: CGFloat = 140
        static let standingThreshold: CGFloat = 160
        
        static func isGoodForm(angle: CGFloat) -> Bool {
            return angle >= minFlexionAngle && angle <= maxFlexionAngle
        }
        
        static func getFormFeedback(angle: CGFloat) -> String {
            if angle < minFlexionAngle {
                return "Bend your knee more - aim for 90-140°"
            } else if angle > maxFlexionAngle {
                return "Great range of motion!"
            } else {
                return "Good form - keep it up!"
            }
        }
    }
    
    /// Shoulder flexion exercise analysis
    struct ShoulderFlexion {
        static let minFlexionAngle: CGFloat = 90
        static let maxFlexionAngle: CGFloat = 160
        
        static func isGoodForm(angle: CGFloat) -> Bool {
            return angle >= minFlexionAngle && angle <= maxFlexionAngle
        }
        
        static func getFormFeedback(angle: CGFloat) -> String {
            if angle < minFlexionAngle {
                return "Raise your arm higher if comfortable"
            } else if angle > maxFlexionAngle {
                return "Excellent range of motion!"
            } else {
                return "Good form - maintain control"
            }
        }
    }
    
    /// Sit-to-stand exercise analysis
    struct SitToStand {
        static let sittingKneeAngle: CGFloat = 90
        static let standingKneeAngle: CGFloat = 170
        static let transitionThreshold: CGFloat = 130
        
        static func detectPhase(kneeAngle: CGFloat) -> ExercisePhase {
            if kneeAngle < transitionThreshold {
                return .sitting
            } else if kneeAngle > standingKneeAngle {
                return .standing
            } else {
                return .transition
            }
        }
    }
}

/// Exercise phases for sit-to-stand
enum ExercisePhase {
    case sitting
    case transition
    case standing
}
