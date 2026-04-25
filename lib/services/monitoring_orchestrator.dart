import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/discipline_rule.dart';
import '../models/discipline_log.dart';
import 'app_monitoring_service.dart';
import 'movement_service.dart';
import 'alarm_service.dart';
import 'storage_service.dart';
import 'countdown_overlay_service.dart';

enum MonitoringState {
  idle,
  monitoring,
  alarmActive,
  completed,
}

class MonitoringOrchestrator {
  final AppMonitoringService _appMonitor;
  final MovementService _movementService;
  final AlarmService _alarmService;
  final StorageService _storageService;
  final CountdownOverlayService _overlayService;

  Timer? _monitoringTimer;
  Timer? _alarmTimer;
  Timer? _overlayTimer;
  DateTime? _alarmStartTime;
  Duration _currentAppUsage = Duration.zero;
  MonitoringState _state = MonitoringState.idle;

  DisciplineRule? _activeRule;

  MonitoringOrchestrator({
    required AppMonitoringService appMonitor,
    required MovementService movementService,
    required AlarmService alarmService,
    required StorageService storageService,
    required CountdownOverlayService overlayService,
  })  : _appMonitor = appMonitor,
        _movementService = movementService,
        _alarmService = alarmService,
        _storageService = storageService,
        _overlayService = overlayService;

  MonitoringState get state => _state;
  Duration get currentAppUsage => _currentAppUsage;

  Future<void> startMonitoring(DisciplineRule rule) async {
    if (_state != MonitoringState.idle) return;

    _activeRule = rule;
    _state = MonitoringState.monitoring;
    _currentAppUsage = Duration.zero;

    final now = DateTime.now();
    final windowEnd = rule.monitoringWindow.endTime;
    final monitoringDuration = windowEnd.difference(now);

    if (monitoringDuration.isNegative) {
      _resetState();
      return;
    }

    // Start periodic monitoring
    _monitoringTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkAppUsage(),
    );

    // Schedule end of monitoring window
    Timer(monitoringDuration, _onMonitoringWindowEnd);
  }

  Future<void> _checkAppUsage() async {
    if (_activeRule == null || _state != MonitoringState.monitoring) return;

    final now = DateTime.now();
    final windowStart = _activeRule!.monitoringWindow.startTime;

    final usageMap = await _appMonitor.getAppUsageForWindow(
      _activeRule!.monitoredApps,
      windowStart,
      now,
    );

    _currentAppUsage = _appMonitor.calculateTotalUsage(usageMap);

    // Check if threshold exceeded
    final remainingDuration = _activeRule!.thresholdDuration - _currentAppUsage;
    if (remainingDuration.isNegative) {
      await _overlayService.hideCountdownOverlay();
      await _triggerAlarm();
      return;
    }

    // Only show overlay if user is in a monitored app
    final foregroundApp = await _appMonitor.getForegroundApp();
    final isInMonitoredApp = foregroundApp != null &&
                              _activeRule!.monitoredApps.contains(foregroundApp);

    if (isInMonitoredApp) {
      final remainingSeconds = remainingDuration.inSeconds;
      await _overlayService.showCountdownOverlay(
        remainingSeconds: remainingSeconds,
        appName: _activeRule!.label,
      );
    } else {
      // Hide overlay if not in monitored app (includes home screen)
      await _overlayService.hideCountdownOverlay();
    }
  }

  Future<void> _onMonitoringWindowEnd() async {
    if (_activeRule == null) return;
    if (_state != MonitoringState.monitoring) return;

    await _checkAppUsage();

    if (_currentAppUsage < _activeRule!.thresholdDuration) {
      await _logResult(
        alarmTriggered: false,
        terminationCompleted: false,
        alarmDuration: Duration.zero,
        status: _currentAppUsage == Duration.zero
            ? LogStatus.noAppUsage
            : LogStatus.belowThreshold,
      );
    }

    _resetState();
  }

  Future<void> _triggerAlarm() async {
    if (_activeRule == null || _state != MonitoringState.monitoring) return;

    _state = MonitoringState.alarmActive;
    _alarmStartTime = DateTime.now();

    await _alarmService.playAlarm(_activeRule!.alarmSound);

    // Start movement tracking based on termination mechanism
    _activeRule!.terminationMechanism.when(
      steps: (requiredSteps) {
        _movementService.startStepTracking((steps) {
          if (steps < requiredSteps) return;
          _onTerminationCompleted();
        });
      },
      movement: (requiredMovement) {
        _movementService.startMovementTracking((movement) {
          if (movement < requiredMovement) return;
          _onTerminationCompleted();
        });
      },
    );

    // Set timeout for alarm
    _alarmTimer = Timer(_activeRule!.maxAlarmDuration, _onAlarmTimeout);
  }

  Future<void> _onTerminationCompleted() async {
    if (_state != MonitoringState.alarmActive) return;
    if (_activeRule == null) return;

    final alarmDuration = _alarmStartTime != null
        ? DateTime.now().difference(_alarmStartTime!)
        : Duration.zero;

    await _alarmService.stopAlarm();
    _movementService.dispose();
    _alarmTimer?.cancel();

    await _logResult(
      alarmTriggered: true,
      terminationCompleted: true,
      alarmDuration: alarmDuration,
      status: LogStatus.terminationCompleted,
    );

    _resetState();
  }

  Future<void> _onAlarmTimeout() async {
    if (_state != MonitoringState.alarmActive) return;
    if (_activeRule == null) return;

    await _alarmService.stopAlarm();
    _movementService.dispose();

    await _logResult(
      alarmTriggered: true,
      terminationCompleted: false,
      alarmDuration: _activeRule!.maxAlarmDuration,
      status: LogStatus.alarmTimedOut,
    );

    _resetState();
  }

  Future<void> _logResult({
    required bool alarmTriggered,
    required bool terminationCompleted,
    required Duration alarmDuration,
    required LogStatus status,
  }) async {
    if (_activeRule == null) return;

    final log = DisciplineLog(
      id: const Uuid().v4(),
      ruleId: _activeRule!.id,
      ruleLabel: _activeRule!.label,
      timestamp: DateTime.now(),
      totalAppUsage: _currentAppUsage,
      thresholdDuration: _activeRule!.thresholdDuration,
      alarmTriggered: alarmTriggered,
      terminationCompleted: terminationCompleted,
      alarmDuration: alarmDuration,
      status: status,
    );

    await _storageService.saveLog(log);
  }

  void _resetState() {
    _monitoringTimer?.cancel();
    _alarmTimer?.cancel();
    _overlayTimer?.cancel();
    _movementService.dispose();
    _overlayService.hideCountdownOverlay();
    _state = MonitoringState.idle;
    _activeRule = null;
    _currentAppUsage = Duration.zero;
    _alarmStartTime = null;
  }

  void dispose() {
    _resetState();
    _alarmService.dispose();
  }
}
