import 'dart:io';
import 'package:flutter/services.dart';

class Application {
  final String appName;
  final String packageName;

  Application({required this.appName, required this.packageName});

  factory Application.fromMap(Map<dynamic, dynamic> map) {
    return Application(
      appName: map['appName'] as String,
      packageName: map['packageName'] as String,
    );
  }
}

class AppMonitoringService {
  static const platform = MethodChannel('com.example.morning_discipline/usage');

  Future<bool> hasUsageStatsPermission() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool result = await platform.invokeMethod(
        'hasUsageStatsPermission',
      );
      return result;
    } catch (e) {
      print('Error checking usage stats permission: $e');
      return false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      // Check if permission is already granted
      if (await hasUsageStatsPermission()) {
        return true;
      }

      // Open settings for user to grant permission
      await platform.invokeMethod('openUsageStatsSettings');

      // Note: User needs to manually grant permission in settings
      // Return false as permission is not immediately granted
      return false;
    } catch (e) {
      print('Error requesting permissions: $e');
      return false;
    }
  }

  Future<List<Application>> getInstalledApps() async {
    if (!Platform.isAndroid) {
      return [];
    }

    try {
      final List<dynamic> result = await platform.invokeMethod(
        'getInstalledApps',
      );
      return result
          .map((app) => Application.fromMap(app as Map<dynamic, dynamic>))
          .toList();
    } catch (e) {
      print('Error getting installed apps: $e');
      return [];
    }
  }

  Future<Map<String, Duration>> getAppUsageForWindow(
    List<String> packageNames,
    DateTime start,
    DateTime end,
  ) async {
    if (!Platform.isAndroid) {
      // iOS does not support app usage tracking
      return _createEmptyUsageMap(packageNames);
    }

    try {
      // Check permission first
      if (!await hasUsageStatsPermission()) {
        print('Usage stats permission not granted');
        return _createEmptyUsageMap(packageNames);
      }

      final Map<dynamic, dynamic> result = await platform
          .invokeMethod('getAppUsage', {
            'packageNames': packageNames,
            'startTime': start.millisecondsSinceEpoch,
            'endTime': end.millisecondsSinceEpoch,
          });

      // Convert milliseconds to Duration
      final Map<String, Duration> usageMap = {};
      result.forEach((key, value) {
        usageMap[key as String] = Duration(milliseconds: value as int);
      });

      return usageMap;
    } on PlatformException catch (e) {
      print('Platform exception getting app usage: ${e.message}');
      if (e.code == 'NO_PERMISSION') {
        // Permission not granted, open settings
        await requestPermissions();
      }
      return _createEmptyUsageMap(packageNames);
    } catch (e) {
      print('Error getting app usage: $e');
      return _createEmptyUsageMap(packageNames);
    }
  }

  Future<String?> getForegroundApp() async {
    if (!Platform.isAndroid) {
      return null;
    }

    try {
      final String? result = await platform.invokeMethod('getForegroundApp');
      return result;
    } catch (e) {
      print('Error getting foreground app: $e');
      return null;
    }
  }

  Future<bool> startMonitoringService() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool result = await platform.invokeMethod('startMonitoringService');
      return result;
    } catch (e) {
      print('Error starting monitoring service: $e');
      return false;
    }
  }

  Future<bool> stopMonitoringService() async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool result = await platform.invokeMethod('stopMonitoringService');
      return result;
    } catch (e) {
      print('Error stopping monitoring service: $e');
      return false;
    }
  }

  Future<bool> updateMonitoringNotification({required bool ongoing}) async {
    if (!Platform.isAndroid) {
      return false;
    }

    try {
      final bool result = await platform.invokeMethod('updateMonitoringNotification', {
        'ongoing': ongoing,
      });
      return result;
    } catch (e) {
      print('Error updating monitoring notification: $e');
      return false;
    }
  }

  Map<String, Duration> _createEmptyUsageMap(List<String> packageNames) {
    final Map<String, Duration> usageMap = {};
    for (final packageName in packageNames) {
      usageMap[packageName] = Duration.zero;
    }
    return usageMap;
  }

  Duration calculateTotalUsage(Map<String, Duration> usageMap) {
    return usageMap.values.fold(
      Duration.zero,
      (total, duration) => total + duration,
    );
  }
}
