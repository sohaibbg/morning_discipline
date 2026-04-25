import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class AlarmService {
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static const platform = MethodChannel('com.example.morning_discipline/alarm');

  Future<void> initialize() async {
    const initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notifications.initialize(initializationSettings);
  }

  Future<bool> requestPermissions() async {
    if (await Permission.notification.isDenied) {
      final status = await Permission.notification.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> playAlarm(String soundUri) async {
    await requestPermissions();

    // Show notification
    const androidDetails = AndroidNotificationDetails(
      'discipline_alarm',
      'Discipline Alarm',
      channelDescription: 'Alarm for discipline monitoring',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(
      0,
      'Discipline Alert',
      'Time to move! Complete your activity to stop the alarm.',
      notificationDetails,
    );

    // Play alarm sound via native Android
    try {
      await platform.invokeMethod('playAlarm', {'uri': soundUri});
    } catch (e) {
      print('Error playing alarm: $e');
    }
  }

  Future<void> stopAlarm() async {
    try {
      await platform.invokeMethod('stopAlarm');
    } catch (e) {
      print('Error stopping alarm: $e');
    }
    await _notifications.cancel(0);
  }

  void dispose() {
    stopAlarm();
  }
}
