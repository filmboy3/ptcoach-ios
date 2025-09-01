import Foundation
import CoreGraphics
import Combine
import AVFoundation

/// Integrated exercise processor that combines MoveNet, enhanced calculations, and advanced state machine
class IntegratedExerciseProcessor: ObservableObject {
    
    // MARK: - Published Properties
    @Published var repCount: Int = 0
    @Published var currentAngle: CGFloat = 0
    @Published var smoothedAngle: CGFloat = 0
    @Published var angleVelocity: CGFloat = 0
    @Published var currentState: String = "Idle"
    @Published var formScore: Float = 1.0
    @Published var feedbackMessage: String = "Select an exercise to begin"
    @Published var isValidMovement: Bool = true
    @Published var poseProvider: String = "YOLO"
    
    // MARK: - Pose Providers
    private var yoloPoseProvider: CoreMLPoseProvider?
    private var moveNetPoseProvider: MoveNetPoseProvider?
    private var mockPoseProvider: MockPoseProvider?
    
    // MARK: - Exercise Components
    private var stateMachine: AdvancedStateMachine?
    private var currentExercise: EnhancedExerciseInfo?
    
    // MARK: - Configuration
    private var useMoveNet: Bool = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupPoseProviders()
    }
    
    // MARK: - Setup
    private func setupPoseProviders() {
        // Initialize all pose providers
        yoloPoseProvider = CoreMLPoseProvider()
        moveNetPoseProvider = MoveNetPoseProvider()
        mockPoseProvider = MockPoseProvider()
        
        print("✅ Integrated Exercise Processor initialized with multiple pose providers")
    }
    
    // MARK: - Exercise Configuration
    func configureExercise(_ exerciseType: ExerciseType) {
        // Map exercise types to enhanced exercise info
        switch exerciseType {
        case .bicepCurl:
            currentExercise = EnhancedExerciseInfo.bicepCurl(side: .left)
        case .kneeFlexion:
            currentExercise = EnhancedExerciseInfo.kneeFlexion(side: .left)
        case .lateralArmRaise:
            currentExercise = EnhancedExerciseInfo.lateralArmRaise(side: .left)
        default:
            // Fallback to bicep curl for unsupported exercises
            currentExercise = EnhancedExerciseInfo.bicepCurl(side: .left)
        }
        
        // Initialize state machine with exercise configuration
        if let exercise = currentExercise {
            stateMachine = AdvancedStateMachine(exerciseInfo: exercise)
            
            // Subscribe to state machine updates
            stateMachine?.$repCount
                .assign(to: \.repCount, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$currentAngle
                .assign(to: \.currentAngle, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$smoothedAngle
                .assign(to: \.smoothedAngle, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$angleVelocity
                .assign(to: \.angleVelocity, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$currentState
                .map { $0.rawValue }
                .assign(to: \.currentState, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$formScore
                .assign(to: \.formScore, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$feedbackMessage
                .assign(to: \.feedbackMessage, on: self)
                .store(in: &cancellables)
            
            stateMachine?.$isValidMovement
                .assign(to: \.isValidMovement, on: self)
                .store(in: &cancellables)
            
            feedbackMessage = "Exercise configured: \(exercise.name)"
        }
    }
    
    // MARK: - Pose Provider Selection
    func switchToPoseProvider(_ provider: PoseProviderType) {
        switch provider {
        case .yolo:
            useMoveNet = false
            poseProvider = "YOLO"
        case .moveNet:
            useMoveNet = true
            poseProvider = "MoveNet"
        case .mock:
            useMoveNet = false
            poseProvider = "Mock"
        }
        
        feedbackMessage = "Switched to \(poseProvider) pose detection"
        print("🔄 Switched to \(poseProvider) pose provider")
    }
    
    // MARK: - Frame Processing
    func processFrame(_ pixelBuffer: CVPixelBuffer) async {
        // Get landmarks from selected pose provider
        let landmarks = await getLandmarks(from: pixelBuffer)
        
        // Process with state machine
        await MainActor.run {
            stateMachine?.processFrame(landmarks: landmarks)
        }
    }
    
    private func getLandmarks(from pixelBuffer: CVPixelBuffer) async -> [Landmark] {
        if useMoveNet {
            return await moveNetPoseProvider?.detectPose(pixelBuffer: pixelBuffer) ?? []
        } else if poseProvider == "Mock" {
            return await mockPoseProvider?.detectPose(pixelBuffer: pixelBuffer) ?? []
        } else {
            return await yoloPoseProvider?.detectPose(pixelBuffer: pixelBuffer) ?? []
        }
    }
    
    // MARK: - Exercise Testing Methods
    func testBicepCurls() {
        configureExercise(.bicepCurl)
        feedbackMessage = "Testing bicep curls with enhanced angle calculation"
    }
    
    func testKneeFlexion() {
        configureExercise(.kneeFlexion)
        feedbackMessage = "Testing knee flexion with corrected angle calculation"
    }
    
    func testLateralArmRaise() {
        configureExercise(.lateralArmRaise)
        feedbackMessage = "Testing lateral arm raise (shoulder abduction)"
    }
    
    func testAllExercises() {
        // Cycle through all exercise types for comprehensive testing
        let exercises: [ExerciseType] = [.bicepCurl, .kneeFlexion, .lateralArmRaise]
        
        for (index, exercise) in exercises.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index * 5)) {
                self.configureExercise(exercise)
                self.feedbackMessage = "Testing \(exercise.rawValue) - \(index + 1)/\(exercises.count)"
            }
        }
    }
    
    // MARK: - Performance Comparison
    func comparePoseProviders() async {
        guard let mockBuffer = createMockPixelBuffer() else { return }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test YOLO
        let yoloStart = CFAbsoluteTimeGetCurrent()
        let yoloLandmarks = await yoloPoseProvider?.detectPose(pixelBuffer: mockBuffer) ?? []
        let yoloTime = (CFAbsoluteTimeGetCurrent() - yoloStart) * 1000
        
        // Test MoveNet
        let moveNetStart = CFAbsoluteTimeGetCurrent()
        let moveNetLandmarks = await moveNetPoseProvider?.detectPose(pixelBuffer: mockBuffer) ?? []
        let moveNetTime = (CFAbsoluteTimeGetCurrent() - moveNetStart) * 1000
        
        let totalTime = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        
        await MainActor.run {
            feedbackMessage = """
            Performance Comparison:
            YOLO: \(String(format: "%.1f", yoloTime))ms (\(yoloLandmarks.count) landmarks)
            MoveNet: \(String(format: "%.1f", moveNetTime))ms (\(moveNetLandmarks.count) landmarks)
            Total: \(String(format: "%.1f", totalTime))ms
            """
        }
        
        print("📊 Pose Provider Performance:")
        print("   YOLO: \(yoloTime)ms, \(yoloLandmarks.count) landmarks")
        print("   MoveNet: \(moveNetTime)ms, \(moveNetLandmarks.count) landmarks")
    }
    
    private func createMockPixelBuffer() -> CVPixelBuffer? {
        let width = 640
        let height = 480
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    // MARK: - Reset and Control
    func reset() {
        stateMachine?.reset()
        feedbackMessage = "Exercise session reset"
    }
    
    func pauseProcessing() {
        feedbackMessage = "Processing paused"
    }
    
    func resumeProcessing() {
        feedbackMessage = "Processing resumed"
    }
}

// MARK: - Pose Provider Type Enum
enum PoseProviderType: String, CaseIterable {
    case yolo = "YOLO"
    case moveNet = "MoveNet"
    case mock = "Mock"
    
    var displayName: String {
        return rawValue
    }
}

// MARK: - Exercise Type Extension
extension ExerciseType {
    var enhancedInfo: EnhancedExerciseInfo {
        switch self {
        case .bicepCurl:
            return EnhancedExerciseInfo.bicepCurl(side: .left)
        case .kneeFlexion:
            return EnhancedExerciseInfo.kneeFlexion(side: .left)
        case .lateralArmRaise:
            return EnhancedExerciseInfo.lateralArmRaise(side: .left)
        default:
            return EnhancedExerciseInfo.bicepCurl(side: .left)
        }
    }
}
