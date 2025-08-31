import XCTest

final class PTCoachUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testBicepCurlBurstScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Track tab
        app.tabBars.buttons["Track"].tap()
        
        // Start camera
        app.buttons["Start Camera"].tap()
        
        // Wait for camera to initialize
        sleep(2)
        
        // Burst capture during bicep curl testing
        for i in 1...30 {
            let shot = XCUIScreen.main.screenshot()
            let attach = XCTAttachment(screenshot: shot)
            attach.name = String(format: "bicep-curl-burst-%03d", i)
            attach.lifetime = .keepAlways
            add(attach)
            
            // 0.5 second intervals for good motion capture
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
    }
    
    func testPoseDetectionScreenshots() throws {
        let app = XCUIApplication()
        app.launch()
        
        // Navigate to Track tab
        app.tabBars.buttons["Track"].tap()
        
        // Start camera
        app.buttons["Start Camera"].tap()
        
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
        
        // Navigate to Track tab
        app.tabBars.buttons["Track"].tap()
        
        // Start camera
        app.buttons["Start Camera"].tap()
        
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
