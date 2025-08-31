# PTCoach iOS - Real-Time Exercise Tracking with Pose Detection

## Project Overview
PTCoach is an iOS app that uses CoreML and Vision framework for real-time pose detection to track exercise form and provide coaching feedback. The app integrates a comprehensive YOLO exercise dataset with live camera analysis.

## Current Status
✅ **Working Features:**
- Live camera preview with pose keypoint overlay
- Real-time pose detection using CoreML
- Exercise angle calculations and rep counting
- YOLO exercise dataset integration (616+ exercises)
- Framework dependencies properly configured

🔧 **In Progress:**
- Form comparison using YOLO exercise metadata
- Exercise-specific coaching feedback

## Architecture

### Core Components

#### 1. Camera & Pose Detection
- **`CameraManager.swift`** - Unified camera session management
- **`CameraPreviewView.swift`** - SwiftUI wrapper for AVCaptureVideoPreviewLayer
- **`CoreMLPoseProvider.swift`** - Vision framework pose detection implementation
- **`PoseOverlayView.swift`** - Real-time keypoint visualization with skeleton overlay

#### 2. Exercise Tracking Engine
- **`DynamicAngleEngine.swift`** - Joint angle calculations, rep counting, audio feedback
- **`AngleEngine.swift`** - Base angle calculation utilities
- **`Geometry.swift`** - Mathematical utilities for pose analysis and quality assessment

#### 3. YOLO Exercise System
- **`YOLOExerciseModels.swift`** - Data models for exercise definitions, phases, safety alerts
- **`YOLOExerciseManager.swift`** - Exercise loading and management from JSON dataset
- **`ExerciseLibraryManager.swift`** - Exercise library interface and search

#### 4. UI Components
- **`ContentView.swift`** - Main tracking interface with camera and pose overlay
- **`ExerciseTrackingView.swift`** - Exercise session management
- **`LiveSessionView.swift`** - Real-time exercise coaching interface
- **`ProgressViewScreen.swift`** - Session history and progress tracking

### Data Resources
- **`complete_yolo_dataset_robust.json`** - 616+ exercise definitions with keypoint sequences, target angles, form tolerances
- **`rag_index.json`** - Exercise search and retrieval index

## Current Focus: Shoulder Mobility Exercise

**Selected Exercise:** `side_finger_walk`
- **Position:** Standing, side view
- **Movement:** Shoulder flexion 0° → 90°
- **Tracking:** Left shoulder, elbow, wrist keypoints
- **Form Checks:** Spine alignment, controlled movement, proper range

## Key Technical Features

### Pose Detection Pipeline
1. **Camera Capture** → `CameraManager` provides CVPixelBuffer frames
2. **Pose Analysis** → `CoreMLPoseProvider` extracts 17 COCO keypoints
3. **Angle Calculation** → `DynamicAngleEngine` computes joint angles
4. **Visual Feedback** → `PoseOverlayView` displays colored keypoints and skeleton
5. **Exercise Logic** → Compare against YOLO target angles and form requirements

### Exercise Tracking Logic
- **Rep Detection:** Angle thresholds with enter/exit ranges
- **Form Analysis:** Target joint angles vs. detected angles
- **Safety Monitoring:** Joint hyperextension and alignment checks
- **Audio Feedback:** SystemSoundID chimes for rep completion

### Debug Information
- Real-time landmark count and visibility
- Pose quality scoring (0.0-1.0)
- Frame processing rate
- Shoulder angle measurements for selected exercise

## Build Configuration
- **Framework Dependencies:** AVFoundation, Vision, CoreML, SwiftUI, UIKit, AudioToolbox
- **Project Generation:** Uses `xcodegen` with `project.yml` configuration
- **Target:** iOS with camera permissions in Info.plist

## Next Development Steps
1. **Form Comparison:** Implement real-time comparison against YOLO target angles
2. **Exercise Coaching:** Add voice/visual cues for form corrections
3. **Rep Counting:** Integrate angle thresholds with YOLO exercise phases
4. **Progress Tracking:** Save session data and exercise history
5. **Exercise Library:** Full UI for browsing and selecting exercises

## Testing
- **Device Required:** Physical iOS device (pose detection doesn't work in simulator)
- **Camera Position:** Side view recommended for shoulder exercises
- **Debug Output:** Console logs show pose detection metrics and angle calculations
