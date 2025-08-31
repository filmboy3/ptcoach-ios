import Foundation
import CoreML
@preconcurrency import Vision
import AVFoundation
@preconcurrency import CoreVideo
import CoreGraphics

/// Core ML implementation of PoseProvider for real-time pose detection
class CoreMLPoseProvider: PoseProvider, ObservableObject {
    
    // MARK: - Properties
    private let modelQueue = DispatchQueue(label: "pose.model.queue", qos: .userInitiated)
    private var isProcessing = false
    
    // Temporal smoothing
    private var previousLandmarks: [Landmark] = []
    private let smoothingAlpha: Float = 0.6
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - PoseProvider Protocol
    
    func detectPose(pixelBuffer: CVPixelBuffer?) async -> [Landmark] {
        guard let pixelBuffer = pixelBuffer else { return [] }
        guard !isProcessing else { return [] }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let request = VNDetectHumanBodyPoseRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
            let observations = request.results
            let landmarks = CoreMLPoseProvider.processVisionResults(observations)
            let smoothed = applySmoothingFilter(landmarks)
            return smoothed
        } catch {
            print("Vision request failed: \(error)")
            return []
        }
    }
    
    // MARK: - Static Methods
    
    static func processVisionResults(_ results: [VNHumanBodyPoseObservation]?) -> [Landmark] {
        guard let results = results else { return [] }
        
        // Prepare 17-slot array in COCO order to align with JointType raw values
        var ordered = Array(repeating: Landmark(x: 0, y: 0, confidence: 0, jointType: nil), count: JointType.allCases.count)
        
        for observation in results {
            if let points = try? observation.recognizedPoints(.all) {
                for (name, point) in points {
                    guard point.confidence > 0.3 else { continue }
                    if let jt = mapJointNameToJointType(name) {
                        let lm = Landmark(
                            x: Float(point.location.x),
                            y: Float(1.0 - point.location.y),
                            confidence: Float(point.confidence),
                            jointType: jt
                        )
                        ordered[jt.rawValue] = lm
                    }
                }
            }
        }
        return ordered
    }

    private static func mapJointNameToJointType(_ name: VNHumanBodyPoseObservation.JointName) -> JointType? {
        if name == VNHumanBodyPoseObservation.JointName.nose { return .nose }
        if name == VNHumanBodyPoseObservation.JointName.leftEye { return .leftEye }
        if name == VNHumanBodyPoseObservation.JointName.rightEye { return .rightEye }
        if name == VNHumanBodyPoseObservation.JointName.leftEar { return .leftEar }
        if name == VNHumanBodyPoseObservation.JointName.rightEar { return .rightEar }
        if name == VNHumanBodyPoseObservation.JointName.leftShoulder { return .leftShoulder }
        if name == VNHumanBodyPoseObservation.JointName.rightShoulder { return .rightShoulder }
        if name == VNHumanBodyPoseObservation.JointName.leftElbow { return .leftElbow }
        if name == VNHumanBodyPoseObservation.JointName.rightElbow { return .rightElbow }
        if name == VNHumanBodyPoseObservation.JointName.leftWrist { return .leftWrist }
        if name == VNHumanBodyPoseObservation.JointName.rightWrist { return .rightWrist }
        if name == VNHumanBodyPoseObservation.JointName.leftHip { return .leftHip }
        if name == VNHumanBodyPoseObservation.JointName.rightHip { return .rightHip }
        if name == VNHumanBodyPoseObservation.JointName.leftKnee { return .leftKnee }
        if name == VNHumanBodyPoseObservation.JointName.rightKnee { return .rightKnee }
        if name == VNHumanBodyPoseObservation.JointName.leftAnkle { return .leftAnkle }
        if name == VNHumanBodyPoseObservation.JointName.rightAnkle { return .rightAnkle }
        return nil
    }
    
    // MARK: - Private Methods
    
    // No model loading required when using Vision's built-in body pose detector
    
    private func processResults(_ results: [VNObservation]?) -> [Landmark] {
        guard let results = results else { return [] }
        
        var landmarks: [Landmark] = []
        
        // TODO: Adapt this based on your specific model's output format
        // This is a generic example - you'll need to customize for your model
        
        for result in results {
            if let coreMLResult = result as? VNCoreMLFeatureValueObservation {
                // Extract keypoints from model output
                // Format depends on your specific model (MoveNet, BlazePose, etc.)
                landmarks.append(contentsOf: extractLandmarks(from: coreMLResult))
            }
        }
        
        return landmarks
    }
    
    private func extractLandmarks(from result: VNCoreMLFeatureValueObservation) -> [Landmark] {
        // TODO: Implement based on your model's output format
        // Example for a typical pose model that outputs [x, y, confidence] triplets
        
        guard let multiArray = result.featureValue.multiArrayValue else {
            return []
        }
        
        var landmarks: [Landmark] = []
        let keypointCount = 17 // Typical for COCO pose format
        
        // Extract keypoints (this is model-specific)
        for i in 0..<keypointCount {
            let baseIndex = i * 3 // Assuming [x, y, confidence] format
            
            guard baseIndex + 2 < multiArray.count else { continue }
            
            let x = Float(multiArray[baseIndex].doubleValue)
            let y = Float(multiArray[baseIndex + 1].doubleValue)
            let confidence = Float(multiArray[baseIndex + 2].doubleValue)
            
            // Normalize coordinates to 0..1 range if needed
            let normalizedX = clamp(x, 0.0, 1.0)
            let normalizedY = clamp(y, 0.0, 1.0)
            
            let landmark = Landmark(
                x: normalizedX,
                y: normalizedY,
                confidence: confidence,
                jointType: JointType.fromIndex(i) // You'll need to define this mapping
            )
            
            landmarks.append(landmark)
        }
        
        return landmarks
    }
    
    private func applySmoothingFilter(_ currentLandmarks: [Landmark]) -> [Landmark] {
        guard !previousLandmarks.isEmpty,
              currentLandmarks.count == previousLandmarks.count else {
            previousLandmarks = currentLandmarks
            return currentLandmarks
        }
        
        var smoothedLandmarks: [Landmark] = []
        
        for (current, previous) in zip(currentLandmarks, previousLandmarks) {
            // Only smooth if confidence is reasonable
            if current.confidence > 0.3 && previous.confidence > 0.3 {
                let smoothedX = smoothingAlpha * current.x + (1 - smoothingAlpha) * previous.x
                let smoothedY = smoothingAlpha * current.y + (1 - smoothingAlpha) * previous.y
                let smoothedConfidence = smoothingAlpha * current.confidence + (1 - smoothingAlpha) * previous.confidence
                
                let smoothedLandmark = Landmark(
                    x: smoothedX,
                    y: smoothedY,
                    confidence: smoothedConfidence,
                    jointType: current.jointType
                )
                smoothedLandmarks.append(smoothedLandmark)
            } else {
                smoothedLandmarks.append(current)
            }
        }
        
        previousLandmarks = smoothedLandmarks
        return smoothedLandmarks
    }
    
    private func clamp(_ value: Float, _ min: Float, _ max: Float) -> Float {
        return Swift.max(min, Swift.min(max, value))
    }
}

