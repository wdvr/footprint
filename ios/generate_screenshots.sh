#!/bin/bash

# Footprint Screenshot Generation Script
# This script automatically generates App Store screenshots for all required devices

set -e  # Exit on any error

echo "📱 Footprint Screenshot Generation"
echo "=================================="

# Check if we're in the right directory
if [ ! -f "Footprint.xcodeproj/project.pbxproj" ]; then
    echo "❌ Error: Run this script from the ios/ directory"
    exit 1
fi

# Check if fastlane is installed
if ! command -v fastlane &> /dev/null; then
    echo "📦 Installing fastlane..."
    gem install fastlane
fi

# Check if bundle is available and install dependencies
if [ -f "fastlane/Gemfile" ]; then
    echo "📦 Installing Ruby dependencies..."
    cd fastlane
    bundle install
    cd ..
fi

# Clean previous screenshots
echo "🧹 Cleaning previous screenshots..."
rm -rf fastlane/screenshots

# Ensure simulators are available
echo "📱 Checking simulators..."
xcrun simctl list devices | grep -E "(iPhone 17|iPad Pro)" || echo "⚠️  Some simulators may not be available"

# Build the project first to catch any build errors
echo "🔨 Building project..."
xcodebuild -scheme Footprint -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Generate screenshots
echo "📸 Generating screenshots..."
fastlane screenshots

# Check results
if [ -d "fastlane/screenshots" ]; then
    screenshot_count=$(find fastlane/screenshots -name "*.png" | wc -l)
    echo "✅ Generated $screenshot_count screenshots"
    echo "📁 Screenshots saved to: $(pwd)/fastlane/screenshots/"

    # List all generated screenshots
    echo ""
    echo "Generated screenshots:"
    find fastlane/screenshots -name "*.png" | sort

    echo ""
    echo "📋 Next steps:"
    echo "1. Review screenshots in fastlane/screenshots/"
    echo "2. Upload to App Store Connect"
    echo "3. Use in App Store listing"
else
    echo "❌ No screenshots were generated"
    exit 1
fi

echo ""
echo "🚀 Screenshot generation complete!"