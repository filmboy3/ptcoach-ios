import Foundation
import CoreGraphics
import simd

/// Enhanced exercise calculator with improved angle calculations and exercise-specific logic
class EnhancedExerciseCalculator {
    
    // MARK: - Bicep Curl Implementation
    
    /// Calculate bicep curl angle with proper 3-point angle calculation
    /// Uses shoulder-elbow-wrist angle for accurate bicep curl tracking
    public static func calculateBicepCurl(landmarks: [Landmark], side: ExerciseSide = .left) -> CGFloat {
        let shoulderKey = side == .left ? "left_shoulder" : "right_shoulder"
        let elbowKey = side == .left ? "left_elbow" : "right_elbow"
        let wristKey = side == .left ? "left_wrist" : "right_wrist"
        
        guard let shoulder = landmarks.first(where: { $0.jointType?.name == shoulderKey }),
              let elbow = landmarks.first(where: { $0.jointType?.name == elbowKey }),
              let wrist = landmarks.first(where: { $0.jointType?.name == wristKey }),
              shoulder.confidence > 0.5, elbow.confidence > 0.5, wrist.confidence > 0.5 else {
            return 0
        }
        
        // Calculate angle at elbow joint (shoulder-elbow-wrist)
        let angle = Geometry.angle(shoulder.cgPoint, elbow.cgPoint, wrist.cgPoint)
        
        // Bicep curl specific validation
        if !isValidBicepCurlPosition(shoulder: shoulder.cgPoint, elbow: elbow.cgPoint, wrist: wrist.cgPoint) {
            return 0
        }
        
        return angle
    }
    
    /// Validate bicep curl form - elbow should stay relatively stationary
    private static func isValidBicepCurlPosition(shoulder: CGPoint, elbow: CGPoint, wrist: CGPoint) -> Bool {
        // Check that elbow is positioned correctly relative to shoulder
        let shoulderToElbow = CGPoint(x: elbow.x - shoulder.x, y: elbow.y - shoulder.y)
        let elbowDistance = sqrt(shoulderToElbow.x * shoulderToElbow.x + shoulderToElbow.y * shoulderToElbow.y)
        
        // Elbow should be roughly at shoulder level or slightly below
        let verticalOffset = abs(elbow.y - shoulder.y)
        
        // Basic form validation - elbow shouldn't drift too far from body
        return elbowDistance > 0.1 && verticalOffset < 0.3
    }
    
    // MARK: - Knee Flexion Implementation
    
    /// Calculate knee flexion angle with corrected 3-point calculation
    /// Uses hip-knee-ankle angle for accurate knee flexion tracking
    public static func calculateKneeFlexion(landmarks: [Landmark], side: ExerciseSide = .left) -> CGFloat {
        let hipKey = side == .left ? "left_hip" : "right_hip"
        let kneeKey = side == .left ? "left_knee" : "right_knee"
        let ankleKey = side == .left ? "left_ankle" : "right_ankle"
        
        guard let hip = landmarks.first(where: { $0.jointType?.name == hipKey }),
              let knee = landmarks.first(where: { $0.jointType?.name == kneeKey }),
              let ankle = landmarks.first(where: { $0.jointType?.name == ankleKey }),
              hip.confidence > 0.5, knee.confidence > 0.5, ankle.confidence > 0.5 else {
            return 0
        }
        
        // Calculate angle at knee joint (hip-knee-ankle)
        return Geometry.angle(hip.cgPoint, knee.cgPoint, ankle.cgPoint)
    }
    
    // MARK: - Ankle Flexion Implementation
    
    /// Calculate ankle flexion angle
    /// Note: Standard pose models don't include foot keypoints, so this uses knee-ankle vector
    public static func calculateAnkleFlexion(landmarks: [Landmark], side: ExerciseSide = .left) -> CGFloat {
        let kneeKey = side == .left ? "left_knee" : "right_knee"
        let ankleKey = side == .left ? "left_ankle" : "right_ankle"
        
        guard let knee = landmarks.first(where: { $0.jointType?.name == kneeKey }),
              let ankle = landmarks.first(where: { $0.jointType?.name == ankleKey }),
              knee.confidence > 0.5, ankle.confidence > 0.5 else {
            return 0
        }
        
        // Since we don't have foot keypoints, estimate ankle flexion from knee-ankle vector
        // Create a reference point below the ankle to simulate foot position
        let footEstimate = CGPoint(x: ankle.cgPoint.x, y: ankle.cgPoint.y + 0.1)
        
        return Geometry.angle(knee.cgPoint, ankle.cgPoint, footEstimate)
    }
    
    // MARK: - Neck Flexion Implementation
    
    /// Calculate neck flexion angle using nose and shoulder midpoint
    public static func calculateNeckFlexion(landmarks: [Landmark]) -> CGFloat {
        guard let nose = landmarks.first(where: { $0.jointType?.name == "nose" }),
              let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
              let rightShoulder = landmarks.first(where: { $0.jointType?.name == "right_shoulder" }),
              nose.confidence > 0.5, leftShoulder.confidence > 0.5, rightShoulder.confidence > 0.5 else {
            return 0
        }
        
        // Calculate shoulder midpoint
        let shoulderMidpoint = CGPoint(
            x: (leftShoulder.cgPoint.x + rightShoulder.cgPoint.x) / 2,
            y: (leftShoulder.cgPoint.y + rightShoulder.cgPoint.y) / 2
        )
        
        // Create a reference point for neutral head position (straight up from shoulders)
        let neutralHeadPosition = CGPoint(x: shoulderMidpoint.x, y: shoulderMidpoint.y - 0.15)
        
        // Calculate angle between neutral position, shoulder midpoint, and actual nose position
        return Geometry.angle(neutralHeadPosition, shoulderMidpoint, nose.cgPoint)
    }
    
    // MARK: - Lateral Arm Raise (Shoulder Abduction) Implementation
    
    /// Calculate shoulder abduction angle for lateral arm raises
    /// Measures angle in frontal plane (arm away from body)
    public static func calculateShoulderAbduction(landmarks: [Landmark], side: ExerciseSide = .left) -> CGFloat {
        let shoulderKey = side == .left ? "left_shoulder" : "right_shoulder"
        let elbowKey = side == .left ? "left_elbow" : "right_elbow"
        let hipKey = side == .left ? "left_hip" : "right_hip"
        
        guard let shoulder = landmarks.first(where: { $0.jointType?.name == shoulderKey }),
              let elbow = landmarks.first(where: { $0.jointType?.name == elbowKey }),
              let hip = landmarks.first(where: { $0.jointType?.name == hipKey }),
              shoulder.confidence > 0.5, elbow.confidence > 0.5, hip.confidence > 0.5 else {
            return 0
        }
        
        // Create a reference point straight down from shoulder (represents body's vertical line)
        let downDirection = CGPoint(x: shoulder.cgPoint.x, y: shoulder.cgPoint.y + 0.2)
        
        // Calculate angle between downward direction, shoulder, and elbow
        return Geometry.angle(downDirection, shoulder.cgPoint, elbow.cgPoint)
    }
    
    // MARK: - Hip Flexion Implementation
    
    /// Calculate hip flexion angle for exercises like leg raises
    public static func calculateHipFlexion(landmarks: [Landmark], side: ExerciseSide = .left) -> CGFloat {
        let shoulderKey = side == .left ? "left_shoulder" : "right_shoulder"
        let hipKey = side == .left ? "left_hip" : "right_hip"
        let kneeKey = side == .left ? "left_knee" : "right_knee"
        
        guard let shoulder = landmarks.first(where: { $0.jointType?.name == shoulderKey }),
              let hip = landmarks.first(where: { $0.jointType?.name == hipKey }),
              let knee = landmarks.first(where: { $0.jointType?.name == kneeKey }),
              shoulder.confidence > 0.5, hip.confidence > 0.5, knee.confidence > 0.5 else {
            return 0
        }
        
        // Calculate angle at hip joint (shoulder-hip-knee)
        return Geometry.angle(shoulder.cgPoint, hip.cgPoint, knee.cgPoint)
    }
}

// MARK: - Exercise Side Enum
enum ExerciseSide {
    case left
    case right
    case both
}

// MARK: - Enhanced Exercise Info
struct EnhancedExerciseInfo {
    let name: String
    let primaryJoint: JointType
    let side: ExerciseSide
    let enterThreshold: CGFloat
    let exitThreshold: CGFloat
    let calculator: (([Landmark]) -> CGFloat)
    let validator: (([Landmark]) -> Bool)?
    
    /// Bicep curl exercise configuration
    static func bicepCurl(side: ExerciseSide = .left) -> EnhancedExerciseInfo {
        return EnhancedExerciseInfo(
            name: "Bicep Curl",
            primaryJoint: side == .left ? .leftElbow : .rightElbow,
            side: side,
            enterThreshold: 45,  // Arm extended
            exitThreshold: 120,  // Arm flexed
            calculator: { landmarks in
                EnhancedExerciseCalculator.calculateBicepCurl(landmarks: landmarks, side: side)
            },
            validator: { landmarks in
                // Ensure required joints are visible
                let requiredJoints = side == .left ? 
                    ["left_shoulder", "left_elbow", "left_wrist"] :
                    ["right_shoulder", "right_elbow", "right_wrist"]
                
                return requiredJoints.allSatisfy { jointName in
                    landmarks.contains { $0.jointType?.name == jointName && $0.confidence > 0.5 }
                }
            }
        )
    }
    
    /// Knee flexion exercise configuration
    static func kneeFlexion(side: ExerciseSide = .left) -> EnhancedExerciseInfo {
        return EnhancedExerciseInfo(
            name: "Knee Flexion",
            primaryJoint: side == .left ? .leftKnee : .rightKnee,
            side: side,
            enterThreshold: 160,  // Leg extended
            exitThreshold: 90,    // Leg flexed
            calculator: { landmarks in
                EnhancedExerciseCalculator.calculateKneeFlexion(landmarks: landmarks, side: side)
            },
            validator: { landmarks in
                let requiredJoints = side == .left ?
                    ["left_hip", "left_knee", "left_ankle"] :
                    ["right_hip", "right_knee", "right_ankle"]
                
                return requiredJoints.allSatisfy { jointName in
                    landmarks.contains { $0.jointType?.name == jointName && $0.confidence > 0.5 }
                }
            }
        )
    }
    
    /// Lateral arm raise exercise configuration
    static func lateralArmRaise(side: ExerciseSide = .left) -> EnhancedExerciseInfo {
        return EnhancedExerciseInfo(
            name: "Lateral Arm Raise",
            primaryJoint: side == .left ? .leftShoulder : .rightShoulder,
            side: side,
            enterThreshold: 15,   // Arm at side
            exitThreshold: 85,    // Arm raised laterally
            calculator: { landmarks in
                EnhancedExerciseCalculator.calculateShoulderAbduction(landmarks: landmarks, side: side)
            },
            validator: { landmarks in
                let requiredJoints = side == .left ?
                    ["left_shoulder", "left_elbow", "left_hip"] :
                    ["right_shoulder", "right_elbow", "right_hip"]
                
                return requiredJoints.allSatisfy { jointName in
                    landmarks.contains { $0.jointType?.name == jointName && $0.confidence > 0.5 }
                }
            }
        )
    }
}
