import XCTest

final class PTCoachUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testBicepCurlBurstScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for camera to initialize and pose detection to start
        sleep(5)
        
        // Capture starting position (arms at sides)
        let startScreenshot = app.screenshot()
        let startAttachment = XCTAttachment(screenshot: startScreenshot)
        startAttachment.name = "bicep-curl-start-position"
        startAttachment.lifetime = .keepAlways
        add(startAttachment)
        
        sleep(2)
        
        // Take burst screenshots during bicep curl exercise sequence
        for i in 1...25 {
            let screenshot = app.screenshot()
            let attachment = XCTAttachment(screenshot: screenshot)
            attachment.name = "bicep-curl-sequence-\(String(format: "%03d", i))"
            attachment.lifetime = .keepAlways
            add(attachment)
            
            // Wait 0.6 seconds between shots for natural movement
            usleep(600000)
        }
        
        // Final position capture
        let endScreenshot = app.screenshot()
        let endAttachment = XCTAttachment(screenshot: endScreenshot)
        endAttachment.name = "bicep-curl-end-position"
        endAttachment.lifetime = .keepAlways
        add(endAttachment)
    }
    
    func testPoseDetectionScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for pose detection to stabilize
        sleep(3)
        
        // Capture pose detection states
        let states = ["start", "flex", "peak", "extend", "complete"]
        
        for (index, state) in states.enumerated() {
            // Wait for user to position for each state
            sleep(2)
            
            let shot = XCUIScreen.main.screenshot()
            let attach = XCTAttachment(screenshot: shot)
            attach.name = "pose-detection-\(state)-\(String(format: "%02d", index + 1))"
            attach.lifetime = .keepAlways
            add(attach)
        }
    }
    
    func testDebugHUDCapture() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Wait for full initialization
        sleep(3)
        
        // Single high-quality debug HUD capture
        let shot = XCUIScreen.main.screenshot()
        let attach = XCTAttachment(screenshot: shot)
        attach.name = "debug-hud-overlay"
        attach.lifetime = .keepAlways
        add(attach)
    }
}
