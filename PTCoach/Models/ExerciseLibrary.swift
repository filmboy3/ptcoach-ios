import Foundation

struct ExerciseInfo {
    let id: String
    let name: String
    let description: String
    let category: String
    let difficulty: String
    let flexThreshold: CGFloat
    let extendThreshold: CGFloat
    let jointType: String
}

class ExerciseLibrary {
    static let shared = ExerciseLibrary()
    
    private(set) var availableExercises: [ExerciseInfo] = []
    
    init() {
        loadDefaultExercises()
        loadYOLOExercises()
    }
    
    private func loadDefaultExercises() {
        availableExercises = [
        ExerciseInfo(
            id: "bicep_curl",
            name: "Bicep Curl",
            description: "Start with arms at sides, curl both arms up to 90°, return to sides.",
            category: "strength",
            difficulty: "beginner",
            flexThreshold: 90.0,
            extendThreshold: 40.0,
            jointType: "elbow"
        ),
        ExerciseInfo(
            id: "shoulder_flexion",
            name: "Shoulder Flexion",
            description: "Start with arms at sides, raise both arms forward overhead, return to sides.",
            category: "flexibility",
            difficulty: "beginner",
            flexThreshold: 150.0,
            extendThreshold: 30.0,
            jointType: "shoulder"
        ),
        ExerciseInfo(
            id: "knee_flexion",
            name: "Knee Flexion",
            description: "From standing, slide one foot back to flex knee to 120°, return to standing.",
            category: "flexibility",
            difficulty: "beginner",
            flexThreshold: 120.0,
            extendThreshold: 10.0,
            jointType: "knee"
        ),
        ExerciseInfo(
            id: "lateral_arm_raise",
            name: "Lateral Arm Raise",
            description: "Start with arms at sides, raise both arms out to shoulder height, return to sides.",
            category: "strength",
            difficulty: "beginner",
            flexThreshold: 90.0,
            extendThreshold: 20.0,
            jointType: "shoulder_lateral"
        ),
        ExerciseInfo(
            id: "neck_flexion",
            name: "Neck Flexion",
            description: "From neutral head position, gently lower chin toward chest, return to neutral.",
            category: "flexibility",
            difficulty: "beginner",
            flexThreshold: 45.0,
            extendThreshold: 5.0,
            jointType: "neck"
        ),
        ExerciseInfo(
            id: "ankle_flexion",
            name: "Ankle Flexion",
            description: "From standing, lift toes up (dorsiflexion), then point toes down (plantarflexion).",
            category: "flexibility",
            difficulty: "beginner",
            flexThreshold: 20.0,
            extendThreshold: -10.0,
            jointType: "ankle"
        )
        ]
    }
    
    private func loadYOLOExercises() {
        guard let url = Bundle.main.url(forResource: "complete_yolo_dataset_robust", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            print("⚠️ Could not load YOLO dataset from bundle")
            return
        }
        
        let yoloExercises = YOLOExerciseConverter.loadExercisesFromYOLODataset(jsonData: data)
        
        // Add YOLO exercises to available exercises (avoiding duplicates)
        let existingIds = Set(availableExercises.map { $0.id })
        let newExercises = yoloExercises.filter { !existingIds.contains($0.id) }
        
        availableExercises.append(contentsOf: newExercises)
        
        print("✅ Loaded \(yoloExercises.count) exercises from YOLO dataset, \(newExercises.count) new")
    }
    
    func reloadExercises() {
        availableExercises.removeAll()
        loadDefaultExercises()
        loadYOLOExercises()
    }
    
    private init() {}
}
