import SwiftUI

struct PoseOverlayView: View {
    let landmarks: [Landmark]
    private let dotSize: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<landmarks.count, id: \.self) { index in
                    let landmark = landmarks[index]
                    if landmark.isVisible {
                        Circle()
                            .fill(colorForJoint(landmark.jointType))
                            .frame(width: 8, height: 8)
                            .position(
                                CGPoint(
                                    x: CGFloat(landmark.y) * geometry.size.width,
                                    y: CGFloat(landmark.x) * geometry.size.height
                                )
                            )
                            .overlay(
                                Text("\(index)")
                                    .font(.system(size: 6))
                                    .foregroundColor(.white)
                                    .position(
                                        x: CGFloat(landmark.y) * geometry.size.width,
                                        y: CGFloat(landmark.x) * geometry.size.height
                                    )
                            )
                    }
                }
                
                // Draw skeleton connections for better visualization
                drawSkeleton(in: geometry.size)
            }
            // No mirroring - keep natural orientation
            .scaleEffect(x: 1, y: 1, anchor: .center)
        }
        .allowsHitTesting(false)
    }
    
    private func colorForJoint(_ jointType: JointType?) -> Color {
        guard let jointType = jointType else { return .white }
        
        switch jointType {
        case .nose, .leftEye, .rightEye, .leftEar, .rightEar:
            return .yellow // Head
        case .leftShoulder, .rightShoulder, .leftElbow, .rightElbow, .leftWrist, .rightWrist:
            return .blue // Arms
        case .leftHip, .rightHip:
            return .green // Hips
        case .leftKnee, .rightKnee, .leftAnkle, .rightAnkle:
            return .red // Legs
        }
    }
    
    private func drawSkeleton(in size: CGSize) -> some View {
        Path { path in
            // Head connections
            drawConnection(from: .nose, to: .leftEye, in: &path, size: size)
            drawConnection(from: .nose, to: .rightEye, in: &path, size: size)
            drawConnection(from: .leftEye, to: .leftEar, in: &path, size: size)
            drawConnection(from: .rightEye, to: .rightEar, in: &path, size: size)
            
            // Torso
            drawConnection(from: .leftShoulder, to: .rightShoulder, in: &path, size: size)
            drawConnection(from: .leftShoulder, to: .leftHip, in: &path, size: size)
            drawConnection(from: .rightShoulder, to: .rightHip, in: &path, size: size)
            drawConnection(from: .leftHip, to: .rightHip, in: &path, size: size)
            
            // Left arm
            drawConnection(from: .leftShoulder, to: .leftElbow, in: &path, size: size)
            drawConnection(from: .leftElbow, to: .leftWrist, in: &path, size: size)
            
            // Right arm
            drawConnection(from: .rightShoulder, to: .rightElbow, in: &path, size: size)
            drawConnection(from: .rightElbow, to: .rightWrist, in: &path, size: size)
            
            // Left leg
            drawConnection(from: .leftHip, to: .leftKnee, in: &path, size: size)
            drawConnection(from: .leftKnee, to: .leftAnkle, in: &path, size: size)
            
            // Right leg
            drawConnection(from: .rightHip, to: .rightKnee, in: &path, size: size)
            drawConnection(from: .rightKnee, to: .rightAnkle, in: &path, size: size)
        }
        .stroke(Color.white.opacity(0.6), lineWidth: 2)
    }
    
    private func drawConnection(from: JointType, to: JointType, in path: inout Path, size: CGSize) {
        guard from.rawValue < landmarks.count,
              to.rawValue < landmarks.count else { return }
        
        let fromLandmark = landmarks[from.rawValue]
        let toLandmark = landmarks[to.rawValue]
        
        // Only draw if both landmarks are visible
        guard fromLandmark.isVisible && toLandmark.isVisible else { return }
        
        let fromPoint = CGPoint(
            x: CGFloat(fromLandmark.y) * size.width,
            y: CGFloat(fromLandmark.x) * size.height
        )
        let toPoint = CGPoint(
            x: CGFloat(toLandmark.y) * size.width,
            y: CGFloat(toLandmark.x) * size.height
        )
        
        path.move(to: fromPoint)
        path.addLine(to: toPoint)
    }
}

#Preview {
    PoseOverlayView(landmarks: [])
        .frame(width: 300, height: 400)
        .background(Color.black)
}
