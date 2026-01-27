#!/bin/bash

# App Store Preview Video Recording Script
# This script prepares the simulator for recording the perfect preview video

set -e

echo "🎬 Footprint Preview Video Recording Setup"
echo "==========================================="

# Configuration
DEVICE_NAME="iPhone 17 Pro Max"
APP_BUNDLE_ID="com.footprint.app"
RECORDING_NAME="Footprint_Preview_Video_$(date +%Y%m%d_%H%M%S)"

# Check if Xcode simulators are available
if ! command -v xcrun &> /dev/null; then
    echo "❌ Xcode command line tools not found"
    exit 1
fi

echo "📱 Setting up simulator..."

# Shutdown all simulators to start fresh
xcrun simctl shutdown all

# Boot the target device
echo "🚀 Booting $DEVICE_NAME..."
xcrun simctl boot "$DEVICE_NAME" || {
    echo "❌ Failed to boot simulator. Available devices:"
    xcrun simctl list devices | grep iPhone
    exit 1
}

# Wait for simulator to fully boot
echo "⏳ Waiting for simulator to boot..."
sleep 5

# Reset to clean state (optional)
read -p "🧹 Reset simulator to clean state? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    xcrun simctl erase "$DEVICE_NAME"
    xcrun simctl boot "$DEVICE_NAME"
    sleep 5
fi

# Set up ideal conditions for recording
echo "⚙️  Configuring simulator for recording..."

# Set time to 9:41 (classic iOS demo time)
xcrun simctl status_bar "$DEVICE_NAME" override --time "9:41"

# Set full battery
xcrun simctl status_bar "$DEVICE_NAME" override --batteryState charged --batteryLevel 100

# Remove carrier name for cleaner look
xcrun simctl status_bar "$DEVICE_NAME" override --operatorName ""

# Set full signal strength
xcrun simctl status_bar "$DEVICE_NAME" override --cellularMode active --cellularBars 4

# Launch the app with sample data mode
echo "🚀 Launching Footprint with sample data..."
xcrun simctl launch "$DEVICE_NAME" "$APP_BUNDLE_ID" \
    -SampleDataMode YES \
    -DisableAnimations YES \
    -UITestingMode NO

# Wait for app to fully load
sleep 3

echo "✅ Setup complete!"
echo ""
echo "🎥 Recording Instructions:"
echo "========================"
echo ""
echo "1. 📺 Open QuickTime Player"
echo "   - File → New Screen Recording"
echo "   - Click dropdown next to record button"
echo "   - Select: $DEVICE_NAME"
echo "   - Ensure 'Show Mouse Clicks in Recording' is checked"
echo ""
echo "2. 🎬 Recording Sequence (30 seconds total):"
echo "   ⏰ 0-4s:   Authentication screen → tap 'Continue without account'"
echo "   ⏰ 4-12s:  World map overview → slow pan across continents"
echo "   ⏰ 12-18s: Tap Japan to mark as visited → wait for animation"
echo "   ⏰ 18-24s: Tap Stats tab → let progress bars animate"
echo "   ⏰ 24-28s: Quick Settings → Import Sources → back to Map"
echo "   ⏰ 28-30s: Final map overview with travel footprint"
echo ""
echo "3. 💾 Save Recording:"
echo "   - Save as: ${RECORDING_NAME}.mov"
echo "   - Location: $(pwd)/video_assets/"
echo ""
echo "4. ✨ Post-Production Reminders:"
echo "   - Trim to exactly 30 seconds"
echo "   - Add text overlays (see plan document)"
echo "   - Export as MP4, 1080x1920, 30fps, H.264"
echo ""

# Create video assets directory
mkdir -p video_assets

echo "💡 Pro Tips:"
echo "  • Practice the sequence 2-3 times before recording"
echo "  • Use slow, deliberate movements"
echo "  • Keep finger touches visible but brief"
echo "  • Allow 1-2 second pauses after major actions"
echo "  • If you make a mistake, just re-run this script"
echo ""

# Offer to open QuickTime automatically
read -p "🚀 Open QuickTime Player automatically? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open -a "QuickTime Player"
    echo "📱 QuickTime opened! Set up screen recording and follow the sequence above."
fi

echo ""
echo "🎬 Ready to record! Break a leg! 🌍✈️"

# Keep script running to maintain simulator state
read -p "Press Enter when recording is complete to clean up..."

# Clean up simulator state
echo "🧹 Cleaning up simulator state..."
xcrun simctl status_bar "$DEVICE_NAME" clear

echo "✅ Recording session complete!"
echo "📁 Check video_assets/ folder for your recording"
echo "📝 Next: Edit with text overlays and export for App Store"