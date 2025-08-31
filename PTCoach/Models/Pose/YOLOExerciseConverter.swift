import Foundation

/// Convert YOLO dataset exercises to PTCoach format
class YOLOExerciseConverter {
    
    // COCO-17 landmark indices for joint calculations
    static let jointAngles: [String: (Int, Int, Int)] = [
        "elbow_left": (5, 7, 9),      // left_shoulder -> left_elbow -> left_wrist
        "elbow_right": (6, 8, 10),    // right_shoulder -> right_elbow -> right_wrist
        "shoulder_left": (11, 5, 7),   // left_hip -> left_shoulder -> left_elbow
        "shoulder_right": (12, 6, 8),  // right_hip -> right_shoulder -> right_elbow
        "knee_left": (11, 13, 15),     // left_hip -> left_knee -> left_ankle
        "knee_right": (12, 14, 16),    // right_hip -> right_knee -> right_ankle
        "hip_left": (5, 11, 13),       // left_shoulder -> left_hip -> left_knee
        "hip_right": (6, 12, 14)       // right_shoulder -> right_hip -> right_knee
    ]
    
    struct YOLOExercise: Codable {
        let exerciseId: String
        let name: String
        let category: [String]
        let difficulty: String
        let bodyOrientation: String
        let cameraAngle: String
        let phases: [YOLOPhase]
        let repDetectionKeypoints: [String]
        let safetyConstraints: [String]
        let formCheckpoints: [String]
        
        enum CodingKeys: String, CodingKey {
            case exerciseId = "exercise_id"
            case name
            case category
            case difficulty
            case bodyOrientation = "body_orientation"
            case cameraAngle = "camera_angle"
            case phases
            case repDetectionKeypoints = "rep_detection_keypoints"
            case safetyConstraints = "safety_constraints"
            case formCheckpoints = "form_checkpoints"
        }
    }
    
    struct YOLOPhase: Codable {
        let name: String
        let targetJointAngles: [String: [Double]]
        let durationRangeMs: [Int]
        let criticalLandmarks: [String]
        let formTolerances: FormTolerances
        
        enum CodingKeys: String, CodingKey {
            case name
            case targetJointAngles = "target_joint_angles"
            case durationRangeMs = "duration_range_ms"
            case criticalLandmarks = "critical_landmarks"
            case formTolerances = "form_tolerances"
        }
    }
    
    struct FormTolerances: Codable {
        let angleTolerance: Double
        let positionTolerance: Double
        let timingTolerance: Double
        
        enum CodingKeys: String, CodingKey {
            case angleTolerance = "angle_tolerance"
            case positionTolerance = "position_tolerance"
            case timingTolerance = "timing_tolerance"
        }
    }
    
    /// Convert YOLO exercise to ExerciseInfo format
    static func convertYOLOExercise(_ yoloExercise: YOLOExercise) -> ExerciseInfo {
        
        // Determine primary joint type
        let jointType = determineJointType(yoloExercise)
        
        // Calculate thresholds from phases
        let (flexThreshold, extendThreshold) = calculateThresholds(yoloExercise.phases, jointType: jointType)
        
        // Generate human-readable description
        let description = generateDescription(yoloExercise)
        
        return ExerciseInfo(
            id: yoloExercise.exerciseId,
            name: yoloExercise.name,
            description: description,
            category: yoloExercise.category.first ?? "strength",
            difficulty: yoloExercise.difficulty,
            flexThreshold: flexThreshold,
            extendThreshold: extendThreshold,
            jointType: jointType
        )
    }
    
    /// Load and convert exercises from YOLO dataset JSON
    static func loadExercisesFromYOLODataset(jsonData: Data) -> [ExerciseInfo] {
        do {
            let decoder = JSONDecoder()
            
            // Parse the root JSON structure
            if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
               let exercisesArray = json["exercises"] as? [[String: Any]] {
                
                var convertedExercises: [ExerciseInfo] = []
                
                for exerciseDict in exercisesArray {
                    // Convert dictionary to Data and then decode
                    let exerciseData = try JSONSerialization.data(withJSONObject: exerciseDict)
                    let yoloExercise = try decoder.decode(YOLOExercise.self, from: exerciseData)
                    
                    // Only convert standing exercises for now
                    if yoloExercise.bodyOrientation.lowercased() == "standing" {
                        let convertedExercise = convertYOLOExercise(yoloExercise)
                        convertedExercises.append(convertedExercise)
                    }
                }
                
                return convertedExercises
            }
        } catch {
            print("❌ Error parsing YOLO dataset: \(error)")
        }
        
        return []
    }
    
    /// Determine primary joint type from YOLO exercise data
    private static func determineJointType(_ yoloExercise: YOLOExercise) -> String {
        var jointCounts: [String: Int] = [:]
        
        // Analyze target joint angles across all phases
        for phase in yoloExercise.phases {
            for joint in phase.targetJointAngles.keys {
                let jointLower = joint.lowercased()
                
                if jointLower.contains("elbow") {
                    jointCounts["elbow"] = (jointCounts["elbow"] ?? 0) + 1
                } else if jointLower.contains("shoulder") {
                    jointCounts["shoulder"] = (jointCounts["shoulder"] ?? 0) + 1
                } else if jointLower.contains("knee") {
                    jointCounts["knee"] = (jointCounts["knee"] ?? 0) + 1
                } else if jointLower.contains("hip") {
                    jointCounts["hip"] = (jointCounts["hip"] ?? 0) + 1
                } else if jointLower.contains("ankle") {
                    jointCounts["ankle"] = (jointCounts["ankle"] ?? 0) + 1
                }
            }
        }
        
        // Return most frequently mentioned joint
        if let mostCommon = jointCounts.max(by: { $0.value < $1.value }) {
            return mostCommon.key
        }
        
        // Fallback analysis based on exercise name
        let nameLower = yoloExercise.name.lowercased()
        if nameLower.contains("curl") || nameLower.contains("elbow") {
            return "elbow"
        } else if nameLower.contains("shoulder") || nameLower.contains("raise") {
            return "shoulder"
        } else if nameLower.contains("squat") || nameLower.contains("knee") {
            return "knee"
        } else if nameLower.contains("neck") {
            return "neck"
        }
        
        return "elbow" // Default fallback
    }
    
    /// Calculate flex and extend thresholds from phase data
    private static func calculateThresholds(_ phases: [YOLOPhase], jointType: String) -> (CGFloat, CGFloat) {
        var allAngles: [Double] = []
        
        for phase in phases {
            for (joint, angles) in phase.targetJointAngles {
                let jointLower = joint.lowercased()
                
                // Only use angles for the primary joint type
                if jointLower.contains(jointType) {
                    allAngles.append(contentsOf: angles)
                }
            }
        }
        
        if !allAngles.isEmpty {
            let minAngle = allAngles.min() ?? 30.0
            let maxAngle = allAngles.max() ?? 90.0
            
            // Add some buffer to thresholds
            let flexThreshold = CGFloat(maxAngle - 10)
            let extendThreshold = CGFloat(minAngle + 10)
            
            return (flexThreshold, extendThreshold)
        }
        
        // Default thresholds based on joint type
        switch jointType {
        case "elbow":
            return (90.0, 40.0)
        case "shoulder":
            return (120.0, 20.0)
        case "knee":
            return (120.0, 30.0)
        case "hip":
            return (90.0, 20.0)
        case "ankle":
            return (45.0, 10.0)
        case "neck":
            return (30.0, 5.0)
        default:
            return (90.0, 40.0)
        }
    }
    
    /// Generate human-readable description from YOLO exercise
    private static func generateDescription(_ yoloExercise: YOLOExercise) -> String {
        let jointType = determineJointType(yoloExercise)
        let exerciseName = yoloExercise.name.lowercased()
        
        // Generate description based on joint type and exercise characteristics
        if jointType == "elbow" && exerciseName.contains("curl") {
            return "Start with arms at sides, curl both arms up to 90°, return to sides."
        } else if jointType == "shoulder" && exerciseName.contains("raise") {
            return "Start with arms at sides, raise both arms out to shoulder height, return to sides."
        } else if jointType == "shoulder" && exerciseName.contains("flexion") {
            return "Start with arms at sides, raise both arms forward overhead, return to sides."
        } else if jointType == "knee" && exerciseName.contains("squat") {
            return "From standing, bend knees to squat position, return to standing."
        } else if jointType == "knee" && exerciseName.contains("flexion") {
            return "From standing, slide one foot back to flex knee to 120°, return to standing."
        } else if jointType == "neck" {
            return "From neutral head position, gently move head as directed, return to neutral."
        } else if jointType == "ankle" {
            return "From standing, flex ankle up and down through full range of motion."
        }
        
        // Generic description based on phases
        let phaseNames = yoloExercise.phases.map { $0.name.lowercased() }
        if phaseNames.contains(where: { $0.contains("stretch") }) {
            return "Perform gentle stretching movement, hold position, return to start."
        } else if phaseNames.contains(where: { $0.contains("flex") }) {
            return "Start in neutral position, flex joint through range of motion, return to start."
        }
        
        return "Follow the movement pattern as demonstrated, maintaining good form throughout."
    }
    
    /// Check if exercise is bilateral (uses both sides)
    static func isBilateral(_ yoloExercise: YOLOExercise) -> Bool {
        let nameLower = yoloExercise.name.lowercased()
        
        // Check for bilateral keywords
        let bilateralKeywords = ["both", "bilateral", "double", "two"]
        let unilateralKeywords = ["single", "one", "alternating", "unilateral"]
        
        for keyword in bilateralKeywords {
            if nameLower.contains(keyword) {
                return true
            }
        }
        
        for keyword in unilateralKeywords {
            if nameLower.contains(keyword) {
                return false
            }
        }
        
        // Default to bilateral for safety
        return true
    }
    
    /// Get required landmarks for joint type
    static func getRequiredLandmarks(for jointType: String) -> [String] {
        switch jointType {
        case "elbow":
            return ["left_shoulder", "left_elbow", "left_wrist", "right_shoulder", "right_elbow", "right_wrist"]
        case "shoulder":
            return ["left_hip", "left_shoulder", "left_elbow", "right_hip", "right_shoulder", "right_elbow"]
        case "knee":
            return ["left_hip", "left_knee", "left_ankle", "right_hip", "right_knee", "right_ankle"]
        case "hip":
            return ["left_shoulder", "left_hip", "left_knee", "right_shoulder", "right_hip", "right_knee"]
        case "ankle":
            return ["left_knee", "left_ankle", "right_knee", "right_ankle"]
        case "neck":
            return ["nose", "left_shoulder", "right_shoulder"]
        default:
            return ["left_shoulder", "left_elbow", "left_wrist"]
        }
    }
}
