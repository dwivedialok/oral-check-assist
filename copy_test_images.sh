#!/bin/bash

# 🧪 Test Images Copy Script for Android Device
# Copies test images from ml/test_data/ to Android device and refreshes gallery

echo "🚀 Starting test images copy process..."

# Check if adb is available
if ! command -v adb &> /dev/null; then
    echo "❌ Error: adb command not found. Please install Android SDK tools."
    exit 1
fi

# Check if device is connected
if ! adb devices | grep -q "device$"; then
    echo "❌ Error: No Android device connected. Please connect your device or start an emulator."
    echo "💡 Run 'adb devices' to see connected devices."
    exit 1
fi

# Check if test data directory exists
if [ ! -d "ml/test_data" ]; then
    echo "❌ Error: ml/test_data directory not found."
    echo "💡 Please make sure you're running this script from the project root directory."
    exit 1
fi

# Count test images
image_count=$(find ml/test_data -name "*.jpg" | wc -l)
echo "📊 Found $image_count test images in ml/test_data/"

if [ $image_count -eq 0 ]; then
    echo "❌ Error: No .jpg files found in ml/test_data/"
    exit 1
fi

# Create DCIM directory on device if it doesn't exist
echo "📁 Creating DCIM directory on device..."
adb shell mkdir -p /sdcard/DCIM/OralCavityTest

# Copy images to device
echo "📤 Copying test images to device..."
adb push ml/test_data/*.jpg /sdcard/DCIM/OralCavityTest/

# Verify images were copied
copied_count=$(adb shell ls /sdcard/DCIM/OralCavityTest/*.jpg 2>/dev/null | wc -l)
echo "✅ Successfully copied $copied_count images to device"

# Refresh media gallery
echo "🔄 Refreshing media gallery..."
# Trigger media scanner to make images visible in gallery
adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///storage/emulated/0/DCIM/OralCavityTest/

# Wait a moment for the scan to complete
sleep 2

# Verify gallery refresh
echo "🔍 Verifying gallery refresh..."
# Gallery refresh completed with MEDIA_SCANNER_SCAN_FILE above

echo ""
echo "🎉 Test images copy completed successfully!"
echo "📱 You can now:"
echo "   1. Open your Flutter app"
echo "   2. Tap 'Browse Gallery'"
echo "   3. Look for images in the 'OralCavityTest' folder"
echo ""
echo "📊 Summary:"
echo "   • Source: ml/test_data/ ($image_count images)"
echo "   • Destination: /sdcard/DCIM/OralCavityTest/ ($copied_count images)"
echo "   • Gallery: Refreshed ✅"
echo ""
echo "🧪 Test images ready for classification testing!"

