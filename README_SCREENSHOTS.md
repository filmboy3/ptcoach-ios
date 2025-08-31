# PTCoach Screenshot Capture Guide

## Quick Start Options

### 1. XCUITest Automated Capture (Recommended)
Run automated screenshot tests that capture bicep curl sequences:

```bash
# Run bicep curl burst test (30 screenshots at 0.5s intervals)
xcodebuild test -project PTCoach.xcodeproj -scheme PTCoachUITests -destination 'platform=iOS,name=YOUR_DEVICE_NAME' -only-testing:PTCoachUITests/testBicepCurlBurstScreenshots

# Run pose detection state capture (5 key positions)
xcodebuild test -project PTCoach.xcodeproj -scheme PTCoachUITests -destination 'platform=iOS,name=YOUR_DEVICE_NAME' -only-testing:PTCoachUITests/testPoseDetectionScreenshots
```

Screenshots appear in Xcode Report Navigator → Test Results → Attachments

### 2. CLI Burst Script
```bash
# Device capture (requires libimobiledevice)
./scripts/burst_screenshots.sh device 20 0.5

# Simulator capture
./scripts/burst_screenshots.sh simulator 30 0.3
```

### 3. Manual Device Screenshots
```bash
# Install libimobiledevice
brew install libimobiledevice

# Single screenshot
idevicescreenshot ptcoach-test.png

# Burst capture
UDID=$(idevice_id -l | head -n1)
mkdir -p shots
for i in {1..20}; do
  idevicescreenshot -u "$UDID" "shots/bicep-$(printf %03d $i).png"
  sleep 0.5
done
```

## Test Scenarios

### Bicep Curl Testing
1. **Start position** - both arms extended
2. **Flex phase** - both arms curling up
3. **Peak flexion** - both arms at 90°+ 
4. **Return phase** - both arms extending
5. **Complete rep** - sound plays, counter increments

### Debug HUD Verification
- Rep counter display
- Both elbow angles (left/right)
- Pose quality metrics
- Real-time status updates

## Output Locations
- **XCUITest:** Xcode Report Navigator → Attachments
- **CLI Script:** `screenshots/bicep-curl-TIMESTAMP/`
- **Manual:** Current directory or specified path
