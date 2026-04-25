import 'package:flutter/services.dart';

class CountdownOverlayService {
  static const platform = MethodChannel('com.example.morning_discipline/overlay');

  Future<bool> hasOverlayPermission() async {
    try {
      final result = await platform.invokeMethod<bool>('hasOverlayPermission');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    try {
      await platform.invokeMethod('requestOverlayPermission');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> showCountdownOverlay({
    required int remainingSeconds,
    required String appName,
  }) async {
    try {
      final hasPermission = await hasOverlayPermission();
      if (!hasPermission) return;

      await platform.invokeMethod('showCountdownOverlay', {
        'remainingSeconds': remainingSeconds,
        'appName': appName,
      });
    } catch (e) {
      // Silently fail if overlay can't be shown
    }
  }

  Future<void> updateCountdown(int remainingSeconds) async {
    try {
      await platform.invokeMethod('updateCountdown', {
        'remainingSeconds': remainingSeconds,
      });
    } catch (e) {
      rethrow;
    }
  }

  Future<void> hideCountdownOverlay() async {
    try {
      await platform.invokeMethod('hideCountdownOverlay');
    } catch (e) {
      rethrow;
    }
  }
}
