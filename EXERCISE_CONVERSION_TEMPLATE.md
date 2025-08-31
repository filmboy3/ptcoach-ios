# PTCoach Exercise Conversion Template

## Overview
This document provides the exact format and methodology for converting exercises from the YOLO dataset (`complete_yolo_dataset_robust.json`) into the PTCoach iOS app format.

## Current Issues with Implemented Exercises

### Working Exercises
- ✅ **Bicep Curl** - Uses elbow angle calculation with both arms
- ✅ **Shoulder Flexion** - Uses shoulder angle calculation

### Fixed Issues (Previously Broken)
- ✅ **Swift Compiler Warnings** - Fixed unused variables and @Sendable capture issues
- ✅ **Interface Orientations** - Added support for all orientations in project.yml
- ✅ **Xcode Project** - Regenerated with xcodegen to include all fixes

### Still Broken Exercises (Need Fixing)
- ❌ **Knee Flexion** - Missing proper knee angle calculation
- ❌ **Ankle Flexion** - No ankle joint tracking implemented
- ❌ **Neck Flexion** - No neck joint tracking implemented
- ❌ **Lateral Arm Raise** - Needs lateral shoulder angle, not flexion

## Exercise Conversion Format

### 1. YOLO Dataset Analysis
For each exercise in `complete_yolo_dataset_robust.json`, extract:

```json
{
  "exercise_id": "shoulder_mobility_exercise",
  "name": "Shoulder Mobility Exercise",
  "category": ["flexibility"],
  "difficulty": "beginner",
  "body_orientation": "standing",
  "camera_angle": "side_view",
  "phases": [
    {
      "name": "Wall Standing Position",
      "target_joint_angles": {
        "elbow": [0.0, 90.0]
      }
    }
  ]
}
```

### 2. PTCoach ExerciseInfo Format

```swift
ExerciseInfo(
    id: "shoulder_mobility_exercise",
    name: "Shoulder Mobility Exercise", 
    description: "Stand facing wall, slide fingers up wall as high as comfortable, return to start.",
    category: "flexibility",
    difficulty: "beginner",
    flexThreshold: 90.0,        // From target_joint_angles max
    extendThreshold: 10.0,      // From target_joint_angles min  
    jointType: "shoulder"       // Primary joint being tracked
)
```

### 3. Required Angle Calculation Methods

Each `jointType` must have a corresponding calculation method in `DynamicAngleEngine.swift`:

#### Elbow Angles (Working)
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
```

#### Shoulder Flexion (Working)
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

#### Missing Implementations Needed

**Knee Flexion** (Currently Broken)
```swift
public func calculateKneeFlexion(landmarks: [Landmark]) -> CGFloat {
    guard let leftHip = landmarks.first(where: { $0.jointType?.name == "left_hip" }),
          let leftKnee = landmarks.first(where: { $0.jointType?.name == "left_knee" }),
          let leftAnkle = landmarks.first(where: { $0.jointType?.name == "left_ankle" }),
          leftHip.confidence > 0.5, leftKnee.confidence > 0.5, leftAnkle.confidence > 0.5 else {
        return 0
    }
    
    return Geometry.angle(leftHip.cgPoint, leftKnee.cgPoint, leftAnkle.cgPoint)
}
```

**Shoulder Lateral Raise** (Missing)
```swift
public func calculateShoulderAbduction(landmarks: [Landmark]) -> CGFloat {
    guard let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
          let leftElbow = landmarks.first(where: { $0.jointType?.name == "left_elbow" }),
          let leftHip = landmarks.first(where: { $0.jointType?.name == "left_hip" }),
          leftShoulder.confidence > 0.5, leftElbow.confidence > 0.5, leftHip.confidence > 0.5 else {
        return 0
    }
    
    // Calculate angle from vertical (hip-shoulder line) to shoulder-elbow line
    let verticalAngle = atan2(leftShoulder.cgPoint.y - leftHip.cgPoint.y, 
                             leftShoulder.cgPoint.x - leftHip.cgPoint.x)
    let armAngle = atan2(leftElbow.cgPoint.y - leftShoulder.cgPoint.y,
                        leftElbow.cgPoint.x - leftShoulder.cgPoint.x)
    
    return abs(armAngle - verticalAngle) * 180 / .pi
}
```

**Neck Flexion** (Missing)
```swift
public func calculateNeckFlexion(landmarks: [Landmark]) -> CGFloat {
    guard let nose = landmarks.first(where: { $0.jointType?.name == "nose" }),
          let leftShoulder = landmarks.first(where: { $0.jointType?.name == "left_shoulder" }),
          let rightShoulder = landmarks.first(where: { $0.jointType?.name == "right_shoulder" }),
          nose.confidence > 0.5, leftShoulder.confidence > 0.5, rightShoulder.confidence > 0.5 else {
        return 0
    }
    
    // Calculate midpoint between shoulders
    let shoulderMidpoint = CGPoint(
        x: (leftShoulder.cgPoint.x + rightShoulder.cgPoint.x) / 2,
        y: (leftShoulder.cgPoint.y + rightShoulder.cgPoint.y) / 2
    )
    
    // Calculate angle from vertical to head position
    let verticalAngle = atan2(1, 0) // Straight down
    let headAngle = atan2(nose.cgPoint.y - shoulderMidpoint.y,
                         nose.cgPoint.x - shoulderMidpoint.x)
    
    return abs(headAngle - verticalAngle) * 180 / .pi
}
```

**Ankle Flexion** (Missing)
```swift
public func calculateAnkleFlexion(landmarks: [Landmark]) -> CGFloat {
    guard let leftKnee = landmarks.first(where: { $0.jointType?.name == "left_knee" }),
          let leftAnkle = landmarks.first(where: { $0.jointType?.name == "left_ankle" }),
          let leftFootIndex = landmarks.first(where: { $0.jointType?.name == "left_foot_index" }),
          leftKnee.confidence > 0.5, leftAnkle.confidence > 0.5, leftFootIndex.confidence > 0.5 else {
        return 0
    }
    
    return Geometry.angle(leftKnee.cgPoint, leftAnkle.cgPoint, leftFootIndex.cgPoint)
}
```

### 4. ContentView Integration Pattern

Each new joint type must be added to the switch statement in `ContentView.swift`:

```swift
switch exercise.jointType {
case "elbow":
    isFlexed = leftElbowAngle > flexThreshold && rightElbowAngle > flexThreshold
    isExtended = leftElbowAngle < extendThreshold && rightElbowAngle < extendThreshold
case "shoulder":
    let leftShoulderAngle = DynamicAngleEngine.shared.calculateShoulderFlexion(landmarks: detectedLandmarks)
    isFlexed = leftShoulderAngle > flexThreshold
    isExtended = leftShoulderAngle < extendThreshold
case "shoulder_lateral":
    let shoulderAbductionAngle = DynamicAngleEngine.shared.calculateShoulderAbduction(landmarks: detectedLandmarks)
    isFlexed = shoulderAbductionAngle > flexThreshold
    isExtended = shoulderAbductionAngle < extendThreshold
case "knee":
    let kneeAngle = DynamicAngleEngine.shared.calculateKneeFlexion(landmarks: detectedLandmarks)
    isFlexed = kneeAngle > flexThreshold
    isExtended = kneeAngle < extendThreshold
case "neck":
    let neckAngle = DynamicAngleEngine.shared.calculateNeckFlexion(landmarks: detectedLandmarks)
    isFlexed = neckAngle > flexThreshold
    isExtended = neckAngle < extendThreshold
case "ankle":
    let ankleAngle = DynamicAngleEngine.shared.calculateAnkleFlexion(landmarks: detectedLandmarks)
    isFlexed = ankleAngle > flexThreshold
    isExtended = ankleAngle < extendThreshold
default:
    // Fallback to elbow
    isFlexed = leftElbowAngle > flexThreshold && rightElbowAngle > flexThreshold
    isExtended = leftElbowAngle < extendThreshold && rightElbowAngle < extendThreshold
}
```

## Exercise Conversion Workflow

### Step 1: Extract from YOLO Dataset
1. Find exercise in `complete_yolo_dataset_robust.json`
2. Note `body_orientation` (must be "standing" for current app)
3. Extract `target_joint_angles` for thresholds
4. Identify primary joint being moved

### Step 2: Create Human-Readable Description
Convert technical movement into clear instructions:
- **Bad**: "Flex elbow joint from 0° to 90°"
- **Good**: "Start with arms at sides, curl both arms up to 90°, return to sides"

### Step 3: Determine Joint Type and Thresholds
- Map primary joint to existing or new `jointType`
- Set `flexThreshold` to maximum target angle
- Set `extendThreshold` to minimum target angle + 10° buffer

### Step 4: Implement Missing Angle Calculations
- Add calculation method to `DynamicAngleEngine.swift`
- Use appropriate COCO-17 keypoints
- Ensure confidence checking (> 0.5)
- Return 0 if landmarks missing

### Step 5: Test and Validate
- Add exercise to `ExerciseLibrary.swift`
- Test rep counting with actual movement
- Verify thresholds work for intended range of motion
- Adjust thresholds based on testing

## Priority Exercises to Convert

Based on YOLO dataset analysis, prioritize these standing exercises:

1. **Shoulder Mobility Exercises** (multiple variants)
2. **Neck Mobility Exercises** (rotation, flexion)
3. **Hip Mobility Exercises** (standing variants)
4. **Ankle/Foot Mobility Exercises**
5. **Spinal Mobility Exercises** (standing)
6. **Arm/Wrist Exercises**

## Common Pitfalls

1. **Wrong Joint Type**: Using "shoulder" for lateral raises (should be "shoulder_lateral")
2. **Missing Angle Calculations**: Adding exercises without implementing the calculation method
3. **Incorrect Thresholds**: Not accounting for natural variation in movement
4. **Poor Descriptions**: Technical jargon instead of clear movement instructions
5. **Confidence Issues**: Not checking landmark confidence scores
6. **Single vs Bilateral**: Some exercises need both arms, others just one

This template ensures consistent, working exercise implementations that properly track movement and count reps.
