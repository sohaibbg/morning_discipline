# Quick Start Guide

## Prerequisites

- Flutter SDK 3.11.4 or higher
- Android Studio / Xcode for platform-specific development
- A physical device recommended (some sensors don't work on emulators)

## Installation

1. **Clone and Navigate**
   ```bash
   cd morning_discipline
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate Code**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Run the App**
   ```bash
   # For Android
   flutter run

   # For iOS (macOS only)
   flutter run -d iPhone

   # For desktop
   flutter run -d macos  # or linux, windows
   ```

## First Time Setup

### Android Users

1. **Grant Permissions**: The app will request:
   - Activity Recognition (for step counting)
   - Notifications (for alarms)

2. **Package Usage Stats** (Manual):
   - Go to: Settings → Apps → Special app access → Usage access
   - Find "Morning Discipline"
   - Toggle ON

### iOS Users

Note: iOS has significant limitations due to platform restrictions:
- App usage tracking is NOT available
- Step counting works via HealthKit
- Limited background monitoring

## Creating Your First Rule

1. **Tap the + Button** on the home screen

2. **Fill in the Details**:
   - **Label**: e.g., "Morning Social Media Limit"
   - **Monitored Apps**: Select apps like Instagram, TikTok, etc.
   - **Monitoring Window**: e.g., 6:00 AM to 12:00 PM
   - **Threshold Duration**: e.g., 30 minutes (total usage allowed)
   - **Max Alarm Duration**: e.g., 10 minutes (how long alarm rings)
   - **Termination Mechanism**: 
     - Steps: e.g., 100 steps to dismiss alarm
     - Movement: e.g., 50 units of movement

3. **Save** and ensure the rule is toggled **ON**

## Testing the App

Since full app usage tracking requires platform-specific implementation:

1. **Test with Short Durations**:
   - Set threshold to 1-2 minutes
   - Set alarm duration to 1-2 minutes
   - Set low step requirement (e.g., 10 steps)

2. **Simulate Usage**:
   - Currently, app usage tracking is a placeholder
   - The monitoring logic is in place but returns zero usage

3. **Test Alarm & Dismissal**:
   - You can manually trigger alarms by modifying the orchestrator
   - Walk around to test step counting
   - Shake device to test movement detection

## Viewing Analytics

1. **Tap the Analytics Icon** (top-right on home screen)

2. **Select Date Range**:
   - Quick filters: 7, 30, 90 days
   - Or select custom dates

3. **View Metrics**:
   - Total records
   - Alarms triggered
   - Success rate (alarms dismissed vs timeout)
   - Charts showing trends over time

## Troubleshooting

### No Apps Showing in Selection
- Check if permission granted for query all packages
- On Android 11+, may need to declare queries in manifest

### Pedometer Not Working
- Ensure device has step counter hardware
- Grant Activity Recognition permission
- Test on physical device (emulators often lack sensors)

### Alarm Not Playing
- Check notification permissions
- Ensure device not in Do Not Disturb mode
- Check volume settings

### App Usage Always Zero
- This is expected - the current implementation is a placeholder
- Full implementation requires platform channels to access:
  - Android: UsageStatsManager
  - iOS: Not available (restricted by Apple)

## Next Steps for Development

To implement real app usage tracking:

### Android (UsageStatsManager)

1. **Create Platform Channel** (`android/app/src/main/kotlin/MainActivity.kt`):
```kotlin
class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.morning_discipline/usage"
    
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getAppUsage") {
                    val packageNames = call.argument<List<String>>("packageNames")
                    val startTime = call.argument<Long>("startTime")
                    val endTime = call.argument<Long>("endTime")
                    // Use UsageStatsManager here
                    result.success(usageMap)
                }
            }
    }
}
```

2. **Update app_monitoring_service.dart** to call platform channel

### iOS

Unfortunately, iOS does not provide an API for app usage tracking. The Screen Time API is restricted to:
- Parental controls apps with special entitlements
- Not available for third-party apps

Consider alternative approaches:
- Focus on Android platform
- Or pivot to screen time tracking instead of per-app usage

## Project Structure

```
lib/
├── models/              # Freezed data models
├── services/            # Business logic
├── providers/           # Riverpod state
├── screens/             # UI
├── dependency_injection.dart
└── main.dart
```

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Freezed Package](https://pub.dev/packages/freezed)
- [Riverpod Documentation](https://riverpod.dev)
- [Android UsageStatsManager](https://developer.android.com/reference/android/app/usage/UsageStatsManager)

## Support

For issues or questions:
1. Check the IMPLEMENTATION.md for detailed architecture
2. Review the README.md for feature overview
3. Consult inline code comments
