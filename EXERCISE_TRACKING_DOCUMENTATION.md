# PTCoach Exercise Tracking Logic Documentation

## Core Architecture Overview

The PTCoach app uses a 3-layer system for exercise tracking:

1. **Pose Detection Layer** - CoreML Vision framework detects 17 COCO keypoints
2. **Angle Calculation Layer** - DynamicAngleEngine calculates joint angles from keypoints  
3. **Rep Counting Layer** - State machine tracks movement cycles and counts reps

## Critical Code Components

### 1. Pose Detection Pipeline (ContentView.swift)

```swift
// Connect pose detection to camera frames
cameraManager.setFrameHandler { pixelBuffer in
    Task {
        let detectedLandmarks = await poseProvider.detectPose(pixelBuffer: pixelBuffer)
        await MainActor.run {
            self.landmarks = detectedLandmarks
            self.frameCount += 1
            self.poseQuality = Geometry.poseQuality(landmarks: detectedLandmarks)
            
            // Calculate joint angles for selected exercise
            let leftElbowAngle = DynamicAngleEngine.shared.calculateElbowAngle(landmarks: detectedLandmarks)
            let rightElbowAngle = DynamicAngleEngine.shared.calculateRightElbowAngle(landmarks: detectedLandmarks)
            
            // Dynamic exercise rep counting based on selected exercise
            let exercise = self.selectedExercise
            let flexThreshold = exercise.flexThreshold
            let extendThreshold = exercise.extendThreshold
            
            var isFlexed = false
            var isExtended = false
            
            // Joint-specific angle calculations
            switch exercise.jointType {
            case "elbow":
                isFlexed = leftElbowAngle > flexThreshold && rightElbowAngle > flexThreshold
                isExtended = leftElbowAngle < extendThreshold && rightElbowAngle < extendThreshold
            case "shoulder":
                let leftShoulderAngle = DynamicAngleEngine.shared.calculateShoulderFlexion(landmarks: detectedLandmarks)
                isFlexed = leftShoulderAngle > flexThreshold
                isExtended = leftShoulderAngle < extendThreshold
            case "knee":
                let kneeAngle = DynamicAngleEngine.shared.calculateKneeFlexion(landmarks: detectedLandmarks)
                isFlexed = kneeAngle > flexThreshold
                isExtended = kneeAngle < extendThreshold
            default:
                isFlexed = leftElbowAngle > flexThreshold && rightElbowAngle > flexThreshold
                isExtended = leftElbowAngle < extendThreshold && rightElbowAngle < extendThreshold
            }
            
            // Simple 3-state rep counting: EXTENDED → FLEXED → EXTENDED = 1 rep
            if isExtended && !self.bothArmsExtended {
                // Just reached extended position
                self.bothArmsExtended = true
                if self.leftArmFlexed {
                    // Completed a full rep cycle
                    self.repCount += 1
                    DynamicAngleEngine.shared.playRepSound()
                    print("✅ REP COMPLETED! Total: \(self.repCount)")
                }
                self.leftArmFlexed = false
            } else if isFlexed && self.bothArmsExtended {
                // Just reached flexed position from extended
                self.leftArmFlexed = true
                self.bothArmsExtended = false
                print("💪 FLEXED POSITION REACHED")
            }
        }
    }
}
```

### 2. Angle Calculation Engine (DynamicAngleEngine.swift)

#### Working Elbow Angle Calculation
```swift
public func calculateElbowAngle(landmarks: [Landmark]) -> CGFloat {
    guard let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
          let leftElbow = landmarks.first(where: { $0.jointType?.name == "left_elbow" }),
          let leftWrist = landmarks.first(where: { $0.jointType?.name == "left_wrist" }),
          leftShoulder.confidence > 0.5, leftElbow.confidence > 0.5, leftWrist.confidence > 0.5 else {
        return 0
    }
    
    return Geometry.angle(leftShoulder.cgPoint, leftElbow.cgPoint, leftWrist.cgPoint)
}

public func calculateRightElbowAngle(landmarks: [Landmark]) -> CGFloat {
    guard let rightShoulder = landmarks.first(where: { $0.jointType?.name == "right_shoulder" }),
          let rightElbow = landmarks.first(where: { $0.jointType?.name == "right_elbow" }),
          let rightWrist = landmarks.first(where: { $0.jointType?.name == "right_wrist" }),
          rightShoulder.confidence > 0.5, rightElbow.confidence > 0.5, rightWrist.confidence > 0.5 else {
        return 0
    }
    
    return Geometry.angle(rightShoulder.cgPoint, rightElbow.cgPoint, rightWrist.cgPoint)
}
```

#### Working Shoulder Flexion Calculation
```swift
public func calculateShoulderFlexion(landmarks: [Landmark]) -> CGFloat {
    guard let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
          let leftElbow = landmarks.first(where: { $0.jointType?.name == "left_elbow" }),
          let leftHip = landmarks.first(where: { $0.jointType?.name == "left_hip" }),
          leftShoulder.confidence > 0.5, leftElbow.confidence > 0.5, leftHip.confidence > 0.5 else {
        return 0
    }
    
    return Geometry.angle(leftHip.cgPoint, leftShoulder.cgPoint, leftElbow.cgPoint)
}
```

#### Broken Knee Flexion (Needs Fix)
```swift
public func calculateKneeFlexion(landmarks: [Landmark]) -> CGFloat {
    guard let leftHip = landmarks.first(where: { $0.jointType?.name == "left_hip" }),
          let leftKnee = landmarks.first(where: { $0.jointType?.name == "left_knee" }),
          let leftAnkle = landmarks.first(where: { $0.jointType?.name == "left_ankle" }),
          leftHip.confidence > 0.5, leftKnee.confidence > 0.5, leftAnkle.confidence > 0.5 else {
        return 0
    }
    
    // ISSUE: This line is broken - Geometry.angle expects 3 CGPoints
    return Geometry.angle(leftHip.cgPoint, leftKnee.cgPoint, leftAnkle.cgPoint)
}
```

### 3. Rep Counting State Machine

The app uses a simple 2-state machine:

```swift
// State Variables
@State private var leftArmFlexed = false      // Has the movement reached flex position?
@State private var bothArmsExtended = true    // Are we in the extended/starting position?

// State Transitions
if isExtended && !self.bothArmsExtended {
    // TRANSITION: Moving → Extended (potential rep completion)
    self.bothArmsExtended = true
    if self.leftArmFlexed {
        // COMPLETE REP: We went Extended → Flexed → Extended
        self.repCount += 1
        DynamicAngleEngine.shared.playRepSound()
    }
    self.leftArmFlexed = false
} else if isFlexed && self.bothArmsExtended {
    // TRANSITION: Extended → Flexed (start of movement)
    self.leftArmFlexed = true
    self.bothArmsExtended = false
}
```

### 4. Exercise Definition System (ExerciseLibrary.swift)

```swift
struct ExerciseInfo {
    let id: String
    let name: String
    let description: String        // Human-readable movement instructions
    let category: String          // "strength" or "flexibility"
    let difficulty: String        // "beginner", "intermediate", "advanced"
    let flexThreshold: CGFloat    // Angle considered "flexed" position
    let extendThreshold: CGFloat  // Angle considered "extended" position  
    let jointType: String         // Which calculation method to use
}

// Example working exercise
ExerciseInfo(
    id: "bicep_curl",
    name: "Bicep Curl",
    description: "Start with arms at sides, curl both arms up to 90°, return to sides.",
    category: "strength",
    difficulty: "beginner",
    flexThreshold: 90.0,    // Both elbows > 90° = flexed
    extendThreshold: 40.0,  // Both elbows < 40° = extended
    jointType: "elbow"      // Use calculateElbowAngle()
)
```

## Critical Issues Identified & Fixed

### 1. Swift Compiler Issues (FIXED ✅)
- **Fixed unused variable warnings** - Replaced with `_` assignments
- **Fixed @Sendable capture warnings** - Added `[weak self]` to async closures
- **Fixed interface orientations** - Added all orientations to project.yml
- **Regenerated Xcode project** - All warnings resolved

### 2. Missing Angle Calculations (STILL BROKEN ❌)
Several exercises reference joint types without corresponding calculation methods:

- `"ankle"` → No `calculateAnkleFlexion()` method
- `"neck"` → No `calculateNeckFlexion()` method  
- `"shoulder_lateral"` → No `calculateShoulderAbduction()` method

### 3. Incorrect Geometry Usage (STILL BROKEN ❌)
The broken knee flexion tries to use `Geometry.angle()` but may need different calculation:

```swift
// Current (broken)
return Geometry.angle(leftHip.cgPoint, leftKnee.cgPoint, leftAnkle.cgPoint)

// Should be (if Geometry.angle works with 3 points)
return Geometry.angle(leftHip.cgPoint, leftKnee.cgPoint, leftAnkle.cgPoint)

// Or might need custom calculation
let hipKneeVector = CGVector(dx: leftKnee.cgPoint.x - leftHip.cgPoint.x, 
                            dy: leftKnee.cgPoint.y - leftHip.cgPoint.y)
let kneeAnkleVector = CGVector(dx: leftAnkle.cgPoint.x - leftKnee.cgPoint.x,
                              dy: leftAnkle.cgPoint.y - leftKnee.cgPoint.y)
return angleBetweenVectors(hipKneeVector, kneeAnkleVector)
```

### 4. State Machine Logic Issues (PARTIALLY FIXED ✅)
The current state machine uses `leftArmFlexed` for all exercises but now works generically:

```swift
// Current implementation (works but confusing naming)
@State private var leftArmFlexed = false      // Actually tracks any joint flexion
@State private var bothArmsExtended = true    // Actually tracks any joint extension

// Ideal implementation (clearer naming)
@State private var isInFlexedPosition = false
@State private var isInExtendedPosition = true
```

### 5. Bilateral vs Unilateral Movement Handling (PARTIALLY FIXED ✅)
Current logic assumes bilateral movement (both arms) but some exercises are unilateral:

```swift
// Current (assumes both arms)
case "elbow":
    isFlexed = leftElbowAngle > flexThreshold && rightElbowAngle > flexThreshold
    isExtended = leftElbowAngle < extendThreshold && rightElbowAngle < extendThreshold

// Should handle unilateral exercises
case "elbow":
    if exercise.isBilateral {
        isFlexed = leftElbowAngle > flexThreshold && rightElbowAngle > flexThreshold
        isExtended = leftElbowAngle < extendThreshold && rightElbowAngle < extendThreshold

func playRepSound() {
    do {
        // Configure audio session to play even when phone is on silent
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try session.setActive(true, options: [])
        
        // Play AlyssaRep.m4a sound using AVAudioPlayer
        guard let soundURL = Bundle.main.url(forResource: "AlyssaRep", withExtension: "m4a") else {
            print("❌ Could not find AlyssaRep.m4a file in bundle")
            AudioServicesPlaySystemSound(1057) // Fallback
            return
        }
        
        audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
        audioPlayer?.numberOfLoops = 0
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
        
    } catch {
        print("❌ Audio error: \(error)")
        AudioServicesPlaySystemSound(1057) // Fallback
    }
    
    // Add haptic feedback
    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
    impactFeedback.impactOccurred()
}
```

## Recommended Fixes

### 1. Implement Missing Angle Calculations
Add proper calculation methods for ankle, neck, and lateral shoulder movements.

### 2. Fix Knee Flexion Calculation
Verify `Geometry.angle()` works with 3 points or implement custom vector-based calculation.

### 3. Add Exercise Metadata
Extend `ExerciseInfo` to include:
```swift
let isBilateral: Bool           // Does exercise use both arms/legs?
let primarySide: String?        // "left", "right", or nil for bilateral
let requiredLandmarks: [String] // Which keypoints must be visible
```

### 4. Improve State Machine
Make state variables generic and add validation for required landmarks.

### 5. Add Debugging Tools
```swift
// Add to ContentView for debugging
let debugInfo = """
Exercise: \(exercise.name)
Joint Type: \(exercise.jointType)
Angle: \(currentAngle)°
Flex Threshold: \(exercise.flexThreshold)°
Extend Threshold: \(exercise.extendThreshold)°
State: \(isFlexed ? "FLEXED" : isExtended ? "EXTENDED" : "TRANSITIONING")
"""
print(debugInfo)
```

This documentation reveals the core tracking logic is sound but several exercises are broken due to missing or incorrect angle calculations.
