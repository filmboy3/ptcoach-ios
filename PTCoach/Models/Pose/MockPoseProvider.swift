import Foundation
import CoreGraphics
import AVFoundation

/// Mock pose provider for demo and testing purposes
class MockPoseProvider: PoseProvider {
    private var frameCount = 0
    private var kneeFlexionCycle: Float = 0
    
    func detectPose(pixelBuffer: CVPixelBuffer?) async -> [Landmark] {
        frameCount += 1
        kneeFlexionCycle += 0.02 // Slow knee flexion cycle
        
        let landmarks = createMockLandmarks()
        
        // Debug logging
        print("🎯 POSE DETECTION FRAME \(frameCount)")
        print("📊 Generated \(landmarks.count) landmarks")
        print("🦵 Knee flexion cycle: \(String(format: "%.2f", kneeFlexionCycle))")
        
        return landmarks
    }
    
    private func createMockLandmarks() -> [Landmark] {
        var landmarks: [Landmark] = []
        
        // Create 17 landmarks for COCO pose format
        for i in 0..<17 {
            let jointType = JointType(rawValue: i)
            var landmark: Landmark
            
            // Simulate realistic knee flexion exercise
            let kneeMovement = sin(kneeFlexionCycle) * 0.15 // Larger knee movement
            let baseMovement = sin(Date().timeIntervalSince1970 * 0.3) * 0.02 // Small body sway
            
            switch i {
            case 0: // Nose
                landmark = Landmark(x: 0.5, y: 0.2, confidence: 0.9, jointType: jointType)
            case 5: // Left shoulder
                landmark = Landmark(x: 0.4, y: 0.3, confidence: 0.9, jointType: jointType)
            case 6: // Right shoulder
                landmark = Landmark(x: 0.6, y: 0.3, confidence: 0.9, jointType: jointType)
            case 7: // Left elbow
                landmark = Landmark(x: 0.35, y: 0.45, confidence: 0.8, jointType: jointType)
            case 8: // Right elbow
                landmark = Landmark(x: 0.65, y: 0.45, confidence: 0.8, jointType: jointType)
            case 9: // Left wrist
                landmark = Landmark(x: 0.3 + Float(baseMovement), y: 0.6, confidence: 0.8, jointType: jointType)
            case 10: // Right wrist
                landmark = Landmark(x: 0.7 + Float(baseMovement), y: 0.6, confidence: 0.8, jointType: jointType)
            case 11: // Left hip
                landmark = Landmark(x: 0.4, y: 0.6, confidence: 0.9, jointType: jointType)
            case 12: // Right hip
                landmark = Landmark(x: 0.6, y: 0.6, confidence: 0.9, jointType: jointType)
            case 13: // Left knee - simulate knee flexion
                landmark = Landmark(x: 0.4, y: 0.8 + Float(kneeMovement), confidence: 0.9, jointType: jointType)
            case 14: // Right knee - simulate knee flexion
                landmark = Landmark(x: 0.6, y: 0.8 + Float(kneeMovement), confidence: 0.9, jointType: jointType)
            case 15: // Left ankle
                landmark = Landmark(x: 0.4, y: 0.95, confidence: 0.9, jointType: jointType)
            case 16: // Right ankle
                landmark = Landmark(x: 0.6, y: 0.95, confidence: 0.9, jointType: jointType)
            default:
                landmark = Landmark(x: 0.5, y: 0.5, confidence: 0.7, jointType: jointType)
            }
            
            landmarks.append(landmark)
        }
        
        return landmarks
    }
}
