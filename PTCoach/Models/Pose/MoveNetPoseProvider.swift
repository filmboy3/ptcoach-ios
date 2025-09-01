import Foundation
import CoreML
import Vision
import AVFoundation
import CoreGraphics

/// MoveNet pose detection provider using Core ML
/// Provides an alternative to YOLO with potentially better accuracy and mobile optimization
class MoveNetPoseProvider: PoseProvider {
    private var model: VNCoreMLModel?
    private let confidenceThreshold: Float = 0.3
    
    // MoveNet keypoint mapping to our joint types
    private let moveNetKeypoints: [JointType] = [
        .nose,           // 0
        .leftEye,        // 1
        .rightEye,       // 2
        .leftEar,        // 3
        .rightEar,       // 4
        .leftShoulder,   // 5
        .rightShoulder,  // 6
        .leftElbow,      // 7
        .rightElbow,     // 8
        .leftWrist,      // 9
        .rightWrist,     // 10
        .leftHip,        // 11
        .rightHip,       // 12
        .leftKnee,       // 13
        .rightKnee,      // 14
        .leftAnkle,      // 15
        .rightAnkle      // 16
    ]
    
    init() {
        loadModel()
    }
    
    private func loadModel() {
        // Try to load MoveNet model from bundle
        guard let modelURL = Bundle.main.url(forResource: "movenet", withExtension: "mlmodel") else {
            print("⚠️ MoveNet model not found in bundle. Using fallback to MockPoseProvider.")
            return
        }
        
        do {
            let mlModel = try MLModel(contentsOf: modelURL)
            model = try VNCoreMLModel(for: mlModel)
            print("✅ MoveNet model loaded successfully")
        } catch {
            print("❌ Failed to load MoveNet model: \(error)")
        }
    }
    
    func detectPose(pixelBuffer: CVPixelBuffer) async -> [Landmark] {
        guard let model = model else {
            // Fallback to mock data if model not available
            return generateMockLandmarks()
        }
        
        return await withCheckedContinuation { continuation in
            let request = VNCoreMLRequest(model: model) { request, error in
                if let error = error {
                    print("❌ MoveNet inference error: \(error)")
                    continuation.resume(returning: [])
                    return
                }
                
                let landmarks = self.processResults(request.results)
                continuation.resume(returning: landmarks)
            }
            
            // Configure request for optimal performance
            request.imageCropAndScaleOption = .scaleFill
            
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                print("❌ MoveNet request failed: \(error)")
                continuation.resume(returning: [])
            }
        }
    }
    
    private func processResults(_ results: [VNObservation]?) -> [Landmark] {
        guard let results = results,
              let multiArray = results.first as? VNCoreMLFeatureValueObservation,
              let outputArray = multiArray.featureValue.multiArrayValue else {
            return []
        }
        
        var landmarks: [Landmark] = []
        
        // MoveNet outputs shape [1, 1, 17, 3] where:
        // - 17 is the number of keypoints
        // - 3 is [y, x, confidence]
        let keypointCount = 17
        
        for i in 0..<keypointCount {
            let yIndex = i * 3
            let xIndex = i * 3 + 1
            let confIndex = i * 3 + 2
            
            guard yIndex < outputArray.count,
                  xIndex < outputArray.count,
                  confIndex < outputArray.count else {
                continue
            }
            
            let y = outputArray[yIndex].floatValue
            let x = outputArray[xIndex].floatValue
            let confidence = outputArray[confIndex].floatValue
            
            // Only include landmarks above confidence threshold
            if confidence > confidenceThreshold {
                let jointType = moveNetKeypoints[i]
                let landmark = Landmark(
                    x: Double(x),
                    y: Double(y),
                    confidence: Double(confidence),
                    jointType: jointType
                )
                landmarks.append(landmark)
            }
        }
        
        return landmarks
    }
    
    /// Generate mock landmarks for testing when model is not available
    private func generateMockLandmarks() -> [Landmark] {
        // Generate realistic mock pose data for testing
        let mockData: [(JointType, Double, Double, Double)] = [
            (.nose, 0.5, 0.2, 0.9),
            (.leftShoulder, 0.4, 0.35, 0.8),
            (.rightShoulder, 0.6, 0.35, 0.8),
            (.leftElbow, 0.35, 0.5, 0.7),
            (.rightElbow, 0.65, 0.5, 0.7),
            (.leftWrist, 0.3, 0.65, 0.6),
            (.rightWrist, 0.7, 0.65, 0.6),
            (.leftHip, 0.45, 0.7, 0.8),
            (.rightHip, 0.55, 0.7, 0.8),
            (.leftKnee, 0.43, 0.85, 0.7),
            (.rightKnee, 0.57, 0.85, 0.7),
            (.leftAnkle, 0.41, 1.0, 0.6),
            (.rightAnkle, 0.59, 1.0, 0.6)
        ]
        
        return mockData.map { jointType, x, y, confidence in
            Landmark(x: x, y: y, confidence: confidence, jointType: jointType)
        }
    }
}

// MARK: - MoveNet Model Configuration
extension MoveNetPoseProvider {
    /// Download and setup MoveNet model
    /// This would typically be called during app initialization
    static func setupModel() {
        // In a real implementation, you would:
        // 1. Download the MoveNet Core ML model from TensorFlow Hub
        // 2. Convert it to Core ML format if needed
        // 3. Bundle it with the app or download on first launch
        
        print("📝 MoveNet setup instructions:")
        print("1. Download MoveNet model from TensorFlow Hub")
        print("2. Convert to Core ML format using coremltools")
        print("3. Add movenet.mlmodel to app bundle")
        print("4. Model will be automatically loaded on initialization")
    }
}
