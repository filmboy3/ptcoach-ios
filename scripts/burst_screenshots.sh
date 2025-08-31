#!/bin/bash

# PTCoach Burst Screenshot Script
# Usage: ./scripts/burst_screenshots.sh [device|simulator] [count] [interval]

DEVICE_TYPE=${1:-device}
SHOT_COUNT=${2:-20}
INTERVAL=${3:-0.5}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT_DIR="screenshots/bicep-curl-$TIMESTAMP"

mkdir -p "$OUTPUT_DIR"

echo "🔍 PTCoach Burst Screenshots"
echo "📱 Target: $DEVICE_TYPE"
echo "📸 Count: $SHOT_COUNT shots"
echo "⏱️  Interval: ${INTERVAL}s"
echo "📁 Output: $OUTPUT_DIR"
echo ""

if [ "$DEVICE_TYPE" = "simulator" ]; then
    echo "📱 Using iOS Simulator..."
    for i in $(seq 1 $SHOT_COUNT); do
        shot_name=$(printf "bicep-curl-%03d.png" $i)
        xcrun simctl io booted screenshot "$OUTPUT_DIR/$shot_name"
        echo "📸 Captured: $shot_name"
        sleep $INTERVAL
    done
    
elif [ "$DEVICE_TYPE" = "device" ]; then
    echo "📱 Using Physical Device (requires libimobiledevice)..."
    
    # Check if libimobiledevice is installed
    if ! command -v idevicescreenshot &> /dev/null; then
        echo "❌ libimobiledevice not found. Install with:"
        echo "   brew install libimobiledevice"
        exit 1
    fi
    
    # Get device UDID
    UDID=$(idevice_id -l | head -n1)
    if [ -z "$UDID" ]; then
        echo "❌ No device found. Make sure device is connected and trusted."
        exit 1
    fi
    
    echo "📱 Device UDID: $UDID"
    
    for i in $(seq 1 $SHOT_COUNT); do
        shot_name=$(printf "bicep-curl-%03d.png" $i)
        idevicescreenshot -u "$UDID" "$OUTPUT_DIR/$shot_name"
        echo "📸 Captured: $shot_name"
        sleep $INTERVAL
    done
    
else
    echo "❌ Invalid device type. Use 'device' or 'simulator'"
    exit 1
fi

echo ""
echo "✅ Burst capture complete!"
echo "📁 Screenshots saved to: $OUTPUT_DIR"
echo "🔍 View files: open $OUTPUT_DIR"
