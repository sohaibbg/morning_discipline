#!/bin/bash

echo "🚀 Testing Android Implementation"
echo "=================================="
echo ""

# Check if device is connected
echo "1. Checking for connected devices..."
DEVICE_COUNT=$(flutter devices | grep -c "android")

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No Android device found!"
    echo "   Please connect a device or start an emulator"
    exit 1
else
    echo "✅ Android device found"
fi

echo ""
echo "2. Building and installing app..."
flutter run --release -d android &
FLUTTER_PID=$!

echo ""
echo "3. Waiting for app to launch..."
sleep 10

echo ""
echo "=================================="
echo "📱 MANUAL TESTING STEPS"
echo "=================================="
echo ""
echo "Step 1: Grant Usage Access Permission"
echo "   - When the app opens, you should see an orange warning card"
echo "   - Tap 'Grant Permission' button"
echo "   - In Android Settings, find 'Morning Discipline'"
echo "   - Toggle the permission ON"
echo "   - Return to the app"
echo "   - Tap 'Refresh' button"
echo "   - Warning should disappear"
echo ""
echo "Step 2: Create a Test Rule"
echo "   - Tap the + button"
echo "   - Label: 'Test Social Media Limit'"
echo "   - Select apps: Instagram, TikTok, or any social media"
echo "   - Start time: Current time (e.g., $(date +%H:%M))"
echo "   - End time: 2 hours from now (e.g., $(date -v+2H +%H:%M))"
echo "   - Threshold: 5 minutes"
echo "   - Max alarm: 2 minutes"
echo "   - Steps required: 20"
echo "   - Save and ensure it's toggled ON"
echo ""
echo "Step 3: Test Usage Tracking"
echo "   - Open Instagram/TikTok and use for 6+ minutes"
echo "   - App should detect usage and trigger alarm"
echo "   - Walk 20 steps to dismiss"
echo ""
echo "Step 4: Verify Dashboard"
echo "   - Tap the analytics icon"
echo "   - Check that the log shows actual usage time"
echo "   - Verify charts display correctly"
echo ""
echo "=================================="
echo "🐛 DEBUGGING TIPS"
echo "=================================="
echo ""
echo "View logs in real-time:"
echo "   adb logcat | grep -i 'flutter\|MainActivity\|UsageStats'"
echo ""
echo "Check permission status:"
echo "   adb shell dumpsys usagestats"
echo ""
echo "Force stop app:"
echo "   adb shell am force-stop com.example.morning_discipline"
echo ""
echo "Reinstall:"
echo "   flutter clean && flutter run"
echo ""
echo "Press Ctrl+C to stop the app"
echo ""

# Wait for Flutter process
wait $FLUTTER_PID
