import 'dart:async';
import 'package:flutter/material.dart';
import '../models/discipline_rule.dart';
import 'monitoring_orchestrator.dart';
import 'storage_service.dart';
import 'app_monitoring_service.dart';

class MonitoringManager {
  final MonitoringOrchestrator _orchestrator;
  final StorageService _storageService;
  final AppMonitoringService _appMonitor;
  Timer? _checkTimer;
  String? _activeRuleId;

  MonitoringManager({
    required MonitoringOrchestrator orchestrator,
    required StorageService storageService,
    required AppMonitoringService appMonitor,
  })  : _orchestrator = orchestrator,
        _storageService = storageService,
        _appMonitor = appMonitor;

  Future<void> initialize() async {
    await _checkAndStartMonitoring();
    _checkTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkAndStartMonitoring(),
    );
  }

  Future<void> _checkAndStartMonitoring() async {
    final rules = _storageService.getAllRules();
    final now = DateTime.now();

    bool shouldMonitor = false;
    for (final rule in rules) {
      if (!rule.isEnabled) continue;
      if (_activeRuleId == rule.id) continue;
      if (!_isInMonitoringWindow(rule, now)) continue;

      await _orchestrator.startMonitoring(rule);
      _activeRuleId = rule.id;
      shouldMonitor = true;
      break;
    }

    // Start/stop foreground service based on whether we need to monitor
    if (shouldMonitor) {
      await _appMonitor.startMonitoringService();
    } else if (_activeRuleId == null) {
      await _appMonitor.stopMonitoringService();
    }
  }

  bool _isInMonitoringWindow(DisciplineRule rule, DateTime now) {
    final startTime = rule.monitoringWindow.startTime;
    final endTime = rule.monitoringWindow.endTime;

    final nowTime = TimeOfDay.fromDateTime(now);
    final start = TimeOfDay(hour: startTime.hour, minute: startTime.minute);
    final end = TimeOfDay(hour: endTime.hour, minute: endTime.minute);

    final nowMinutes = nowTime.hour * 60 + nowTime.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    if (startMinutes <= endMinutes) {
      return nowMinutes >= startMinutes && nowMinutes <= endMinutes;
    }
    return nowMinutes >= startMinutes || nowMinutes <= endMinutes;
  }

  void dispose() {
    _checkTimer?.cancel();
    _orchestrator.dispose();
  }
}
