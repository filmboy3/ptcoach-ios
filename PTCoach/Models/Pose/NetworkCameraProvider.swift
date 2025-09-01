import Foundation
import AVFoundation
import UIKit
import Network

/// Network-based camera provider that streams from a nearby phone
@MainActor
class NetworkCameraProvider: ObservableObject, @unchecked Sendable {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession.shared
    private var isConnected = false
    
    // Connection settings
    private let serverURL = "ws://192.168.1.100:8080/camera" // Update with your phone's IP
    
    init() {
        connectToPhoneCamera()
    }
    
    func detectPose(pixelBuffer: CVPixelBuffer?) async -> [Landmark] {
        // This will be called by the mock provider for now
        // Real implementation would process frames from phone
        return []
    }
    
    private func connectToPhoneCamera() {
        guard let url = URL(string: serverURL) else { return }
        
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
        
        print("📱 Attempting to connect to phone camera at \(serverURL)")
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    DispatchQueue.main.async { [weak self] in
                        self?.isConnected = true
                    }
                    self?.processImageData(data)
                case .string(let text):
                    print("📱 Received text: \(text)")
                @unknown default:
                    break
                }
                self?.receiveMessage() // Continue receiving
                
            case .failure(let error):
                print("❌ WebSocket error: \(error)")
            }
        }
    }
    
    private func processImageData(_ data: Data) {
        // Convert received image data to CVPixelBuffer for pose detection
        guard UIImage(data: data) != nil else { return }
        
        // Here you would convert UIImage to CVPixelBuffer and run pose detection
        print("📸 Received image frame: \(data.count) bytes")
    }
    
    deinit {
        webSocketTask?.cancel()
    }
}
