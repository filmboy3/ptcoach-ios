import Foundation
import CoreGraphics
import AVFoundation

/// Protocol for pose detection providers
protocol PoseProvider {
    func detectPose(pixelBuffer: CVPixelBuffer?) async -> [Landmark]
}

/// Pose landmark with normalized coordinates
struct Landmark {
    let x: Float          // Normalized 0..1
    let y: Float          // Normalized 0..1
    let confidence: Float // 0..1
    let jointType: JointType?
    
    var cgPoint: CGPoint {
        return CGPoint(x: CGFloat(x), y: CGFloat(y))
    }
    
    var isVisible: Bool {
        return confidence > 0.5
    }
}

/// Joint types for pose landmarks (COCO format)
enum JointType: Int, CaseIterable {
    case nose = 0
    case leftEye = 1
    case rightEye = 2
    case leftEar = 3
    case rightEar = 4
    case leftShoulder = 5
    case rightShoulder = 6
    case leftElbow = 7
    case rightElbow = 8
    case leftWrist = 9
    case rightWrist = 10
    case leftHip = 11
    case rightHip = 12
    case leftKnee = 13
    case rightKnee = 14
    case leftAnkle = 15
    case rightAnkle = 16
    
    static func fromIndex(_ index: Int) -> JointType? {
        return JointType(rawValue: index)
    }
    
    var name: String {
        switch self {
        case .nose: return "nose"
        case .leftEye: return "left_eye"
        case .rightEye: return "right_eye"
        case .leftEar: return "left_ear"
        case .rightEar: return "right_ear"
        case .leftShoulder: return "left_shoulder"
        case .rightShoulder: return "right_shoulder"
        case .leftElbow: return "left_elbow"
        case .rightElbow: return "right_elbow"
        case .leftWrist: return "left_wrist"
        case .rightWrist: return "right_wrist"
        case .leftHip: return "left_hip"
        case .rightHip: return "right_hip"
        case .leftKnee: return "left_knee"
        case .rightKnee: return "right_knee"
        case .leftAnkle: return "left_ankle"
        case .rightAnkle: return "right_ankle"
        }
    }
}
