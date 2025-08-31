import Foundation
import CoreGraphics
import simd

/// Robust angle calculation with noise filtering and validation
class RobustAngleCalculator {
    private var angleHistory: [String: [CGFloat]] = [:]
    private let historySize: Int = 5
    private let confidenceThreshold: Float = 0.5
    
    init(historySize: Int = 5) {
        self.historySize = historySize
    }
    
    /// Calculate 3D angle at p2 between vectors p2->p1 and p2->p3
    func calculateAngle3D(p1: simd_float3, p2: simd_float3, p3: simd_float3) -> CGFloat {
        // Vectors from p2 to p1 and p3
        let v1 = p1 - p2
        let v2 = p3 - p2
        
        // Handle zero vectors
        let v1Length = length(v1)
        let v2Length = length(v2)
        
        if v1Length == 0 || v2Length == 0 {
            return 0
        }
        
        // Normalize vectors
        let v1Norm = v1 / v1Length
        let v2Norm = v2 / v2Length
        
        // Calculate angle using dot product
        let dotProduct = dot(v1Norm, v2Norm)
        let clampedDot = max(-1.0, min(1.0, dotProduct))
        let angleRad = acos(clampedDot)
        let angleDeg = angleRad * 180.0 / Float.pi
        
        return CGFloat(angleDeg)
    }
    
    /// Calculate joint angle with temporal smoothing
    func calculateJointAngle(landmarks: [Landmark], 
                           jointIndices: (Int, Int, Int),
                           jointName: String) -> CGFloat? {
        let (idx1, idx2, idx3) = jointIndices
        
        // Validate indices
        guard idx1 < landmarks.count, 
              idx2 < landmarks.count, 
              idx3 < landmarks.count else {
            return nil
        }
        
        let l1 = landmarks[idx1]
        let l2 = landmarks[idx2]
        let l3 = landmarks[idx3]
        
        // Check confidence
        guard l1.confidence > confidenceThreshold,
              l2.confidence > confidenceThreshold,
              l3.confidence > confidenceThreshold else {
            return nil
        }
        
        // Extract 3D coordinates
        let p1 = simd_float3(Float(l1.cgPoint.x), Float(l1.cgPoint.y), 0)
        let p2 = simd_float3(Float(l2.cgPoint.x), Float(l2.cgPoint.y), 0)
        let p3 = simd_float3(Float(l3.cgPoint.x), Float(l3.cgPoint.y), 0)
        
        // Calculate raw angle
        let rawAngle = calculateAngle3D(p1: p1, p2: p2, p3: p3)
        
        // Apply temporal smoothing
        let smoothedAngle = applyTemporalSmoothing(jointName: jointName, angle: rawAngle)
        
        return smoothedAngle
    }
    
    /// Apply temporal smoothing to reduce noise
    private func applyTemporalSmoothing(jointName: String, angle: CGFloat) -> CGFloat {
        // Initialize history if needed
        if angleHistory[jointName] == nil {
            angleHistory[jointName] = []
        }
        
        var history = angleHistory[jointName]!
        history.append(angle)
        
        // Keep only recent history
        if history.count > historySize {
            history.removeFirst()
        }
        angleHistory[jointName] = history
        
        // Need at least 3 samples for filtering
        if history.count < 3 {
            return angle
        }
        
        // Use median filter for outlier rejection
        let sortedHistory = history.sorted()
        let medianAngle = sortedHistory[sortedHistory.count / 2]
        
        // If current angle is too far from median, use median instead
        if abs(angle - medianAngle) > 30 {
            return medianAngle
        }
        
        // Apply weighted moving average (more weight to recent values)
        var weightedSum: CGFloat = 0
        var totalWeight: CGFloat = 0
        
        for (index, historyAngle) in history.enumerated() {
            let weight = CGFloat(index + 1) // Linear weighting
            weightedSum += historyAngle * weight
            totalWeight += weight
        }
        
        return weightedSum / totalWeight
    }
    
    /// Get specific joint angle calculations
    func calculateElbowAngle(landmarks: [Landmark], side: LandmarkSide = .left) -> CGFloat? {
        let indices: (Int, Int, Int)
        switch side {
        case .left:
            indices = (5, 7, 9)  // left_shoulder -> left_elbow -> left_wrist
        case .right:
            indices = (6, 8, 10) // right_shoulder -> right_elbow -> right_wrist
        }
        
        return calculateJointAngle(landmarks: landmarks, 
                                 jointIndices: indices, 
                                 jointName: "elbow_\(side.rawValue)")
    }
    
    func calculateShoulderFlexion(landmarks: [Landmark], side: LandmarkSide = .left) -> CGFloat? {
        let indices: (Int, Int, Int)
        switch side {
        case .left:
            indices = (11, 5, 7)  // left_hip -> left_shoulder -> left_elbow
        case .right:
            indices = (12, 6, 8)  // right_hip -> right_shoulder -> right_elbow
        }
        
        return calculateJointAngle(landmarks: landmarks, 
                                 jointIndices: indices, 
                                 jointName: "shoulder_\(side.rawValue)")
    }
    
    func calculateKneeFlexion(landmarks: [Landmark], side: LandmarkSide = .left) -> CGFloat? {
        let indices: (Int, Int, Int)
        switch side {
        case .left:
            indices = (11, 13, 15)  // left_hip -> left_knee -> left_ankle
        case .right:
            indices = (12, 14, 16)  // right_hip -> right_knee -> right_ankle
        }
        
        return calculateJointAngle(landmarks: landmarks, 
                                 jointIndices: indices, 
                                 jointName: "knee_\(side.rawValue)")
    }
    
    func calculateHipFlexion(landmarks: [Landmark], side: LandmarkSide = .left) -> CGFloat? {
        let indices: (Int, Int, Int)
        switch side {
        case .left:
            indices = (5, 11, 13)   // left_shoulder -> left_hip -> left_knee
        case .right:
            indices = (6, 12, 14)   // right_shoulder -> right_hip -> right_knee
        }
        
        return calculateJointAngle(landmarks: landmarks, 
                                 jointIndices: indices, 
                                 jointName: "hip_\(side.rawValue)")
    }
    
    func calculateAnkleFlexion(landmarks: [Landmark], side: LandmarkSide = .left) -> CGFloat? {
        // Note: COCO-17 doesn't have foot_index, so we'll use a simplified calculation
        let indices: (Int, Int, Int)
        switch side {
        case .left:
            indices = (13, 15, 13)  // left_knee -> left_ankle -> left_knee (simplified)
        case .right:
            indices = (14, 16, 14)  // right_knee -> right_ankle -> right_knee (simplified)
        }
        
        // This is a simplified calculation - in a real implementation,
        // you'd need additional foot landmarks or use a different approach
        return calculateJointAngle(landmarks: landmarks, 
                                 jointIndices: indices, 
                                 jointName: "ankle_\(side.rawValue)")
    }
    
    func calculateNeckFlexion(landmarks: [Landmark]) -> CGFloat? {
        // Calculate neck flexion using nose and shoulders
        guard landmarks.count > 6 else { return nil }
        
        let nose = landmarks[0]
        let leftShoulder = landmarks[5]
        let rightShoulder = landmarks[6]
        
        // Check confidence
        guard nose.confidence > confidenceThreshold,
              leftShoulder.confidence > confidenceThreshold,
              rightShoulder.confidence > confidenceThreshold else {
            return nil
        }
        
        // Calculate shoulder midpoint
        let shoulderMidX = (leftShoulder.cgPoint.x + rightShoulder.cgPoint.x) / 2
        let shoulderMidY = (leftShoulder.cgPoint.y + rightShoulder.cgPoint.y) / 2
        let shoulderMid = CGPoint(x: shoulderMidX, y: shoulderMidY)
        
        // Calculate angle from vertical
        let deltaY = nose.cgPoint.y - shoulderMid.y
        let deltaX = nose.cgPoint.x - shoulderMid.x
        
        let angleRad = atan2(deltaX, deltaY)
        let angleDeg = angleRad * 180.0 / CGFloat.pi
        
        return applyTemporalSmoothing(jointName: "neck", angle: abs(angleDeg))
    }
    
    /// Reset angle history (useful when switching exercises)
    func resetHistory() {
        angleHistory.removeAll()
    }
}

enum LandmarkSide: String {
    case left = "left"
    case right = "right"
}
