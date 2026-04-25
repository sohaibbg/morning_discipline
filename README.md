# Morning Discipline

A Flutter application for monitoring app usage and encouraging physical activity through smart alarms.

## Features

- **Discipline Rules**: Create custom rules with:
  - Label/title for easy identification
  - Set of monitored apps
  - Time window for monitoring
  - Usage threshold duration
  - Alarm duration limit
  - Custom alarm sounds
  - Termination mechanism (steps or movement)

- **Smart Monitoring**: 
  - Tracks app usage during specified time windows
  - Triggers alarms when usage exceeds thresholds
  - Requires physical activity (steps or movement) to dismiss alarms

- **Analytics Dashboard**:
  - View historical logs
  - Success rate tracking
  - Status distribution charts
  - Date range filtering
  - Detailed log records

## Architecture

This app uses:
- **Flutter** - Cross-platform UI framework
- **Freezed** - Immutable data classes
- **Riverpod** - State management
- **GetIt** - Dependency injection
- **Hive** - Local storage

## Setup

1. Install dependencies:
```bash
flutter pub get
```

2. Generate code:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

3. Run the app:
```bash
flutter run
```

## Permissions

The app requires the following permissions:
- **Activity Recognition** - For step counting
- **Package Usage Stats** - For monitoring app usage
- **Notifications** - For alarm notifications
- **Wake Lock** - To keep alarm active

### Android Setup

For Android 11+ (API 30+), you need to grant package usage stats permission manually:
1. Go to Settings > Apps > Special app access > Usage access
2. Enable permission for Morning Discipline

## Project Structure

```
lib/
├── models/              # Data models (Freezed classes)
│   ├── discipline_rule.dart
│   └── discipline_log.dart
├── services/            # Business logic services
│   ├── storage_service.dart
│   ├── app_monitoring_service.dart
│   ├── movement_service.dart
│   ├── alarm_service.dart
│   └── monitoring_orchestrator.dart
├── providers/           # Riverpod state providers
│   ├── rules_provider.dart
│   ├── logs_provider.dart
│   └── monitoring_provider.dart
├── screens/             # UI screens
│   ├── rules_list_screen.dart
│   ├── rule_edit_screen.dart
│   └── dashboard_screen.dart
├── dependency_injection.dart
└── main.dart
```

## How It Works

1. **Create a Rule**: Define which apps to monitor, time window, and thresholds
2. **Enable the Rule**: Toggle it on from the rules list
3. **Automatic Monitoring**: During the time window, the app tracks usage
4. **Alarm Trigger**: If usage exceeds threshold, alarm rings
5. **Physical Activity**: Walk steps or move to dismiss the alarm
6. **Logging**: All events are logged for analytics

## Notes

- App usage monitoring works best on Android
- iOS has restrictions on app usage tracking
- Pedometer requires device with step counter hardware
- Movement detection uses device accelerometer

## Future Enhancements

- Background service for continuous monitoring
- Custom alarm sounds upload
- Weekly/monthly reports
- Export logs to CSV
- Rule templates
- Integration with health apps
