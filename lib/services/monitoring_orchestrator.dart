import 'dart:async';
import '../models/discipline_rule.dart';
import 'app_monitoring_service.dart';
import 'movement_service.dart';
import 'alarm_service.dart';
import 'storage_service.dart';
import 'countdown_overlay_service.dart';

enum MonitoringState { idle, monitoring, alarmActive, completed }

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
  DateTime? _thresholdCrossedAt;
  Duration _currentAppUsage = Duration.zero;
  MonitoringState _state = MonitoringState.idle;
  double _currentTerminationProgress = 0.0;

  DisciplineRule? _activeRule;

  MonitoringOrchestrator({
    required AppMonitoringService appMonitor,
    required MovementService movementService,
    required AlarmService alarmService,
    required StorageService storageService,
    required CountdownOverlayService overlayService,
  }) : _appMonitor = appMonitor,
       _movementService = movementService,
       _alarmService = alarmService,
       _storageService = storageService,
       _overlayService = overlayService;

  MonitoringState get state => _state;
  Duration get currentAppUsage => _currentAppUsage;
  DisciplineRule? get activeRule => _activeRule;
  double get terminationProgress => _currentTerminationProgress;

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
    final windowEnd = _activeRule!.monitoringWindow.endTime;

    // Check if we're within 5 minutes of window end
    final timeUntilEnd = windowEnd.difference(now);
    if (timeUntilEnd.inMinutes <= 5 && timeUntilEnd.inMinutes >= 0) {
      // Make notification undismissable
      await _appMonitor.updateMonitoringNotification(ongoing: true);
    }

    final usageMap = await _appMonitor.getAppUsageForWindow(
      _activeRule!.monitoredApps,
      windowStart,
      now,
    );

    _currentAppUsage = _appMonitor.calculateTotalUsage(usageMap);

    // Check if threshold exceeded
    final remainingDuration = _activeRule!.thresholdDuration - _currentAppUsage;
    if (remainingDuration.isNegative) {
      // Record when threshold was crossed
      _thresholdCrossedAt ??= now;

      // Check if more than 2 minutes have passed since threshold crossed
      final timeSinceCrossed = now.difference(_thresholdCrossedAt!);
      if (timeSinceCrossed.inMinutes >= 2) {
        // Too late to trigger alarm
        await _overlayService.hideCountdownOverlay();
        await _recordExecutionStatus(
          ExecutionOutcome.alarmTooLate,
          failureReason:
              'Alarm detection delayed by ${timeSinceCrossed.inMinutes} minutes',
        );
        _resetState();
        return;
      }

      await _overlayService.hideCountdownOverlay();
      await _triggerAlarm();
      return;
    }

    // Only show overlay if user is in a monitored app
    try {
      final foregroundApp = await _appMonitor.getForegroundApp();
      final isInMonitoredApp =
          foregroundApp != null &&
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
    } catch (e) {
      print('Error checking foreground app: $e');
      // Continue monitoring even if foreground detection fails
    }
  }

  Future<void> _onMonitoringWindowEnd() async {
    if (_activeRule == null) return;
    if (_state != MonitoringState.monitoring) return;

    await _checkAppUsage();

    if (_currentAppUsage < _activeRule!.thresholdDuration) {
      // Success - threshold not crossed
      await _recordExecutionStatus(ExecutionOutcome.success);
    }

    _resetState();
  }

  Future<void> _triggerAlarm() async {
    if (_activeRule == null || _state != MonitoringState.monitoring) return;

    _state = MonitoringState.alarmActive;
    _alarmStartTime = DateTime.now();
    _currentTerminationProgress = 0.0;

    // Make notification dismissable after alarm triggers
    await _appMonitor.updateMonitoringNotification(ongoing: false);

    try {
      await _alarmService.playAlarm(_activeRule!.alarmSound);
    } catch (e) {
      print('Failed to trigger alarm: $e');
      await _recordExecutionStatus(
        ExecutionOutcome.alarmFailedToTrigger,
        failureReason: 'Error playing alarm: $e',
      );
      _resetState();
      return;
    }

    // Start movement tracking based on termination mechanism
    _activeRule!.terminationMechanism.when(
      steps: (requiredSteps) {
        _movementService.startStepTracking((steps) {
          _currentTerminationProgress = steps / requiredSteps;
          if (steps < requiredSteps) return;
          _onTerminationCompleted();
        });
      },
      movement: (requiredMovement) {
        _movementService.startMovementTracking((movement) {
          _currentTerminationProgress = movement / requiredMovement;
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

    await _alarmService.stopAlarm();
    _movementService.dispose();
    _alarmTimer?.cancel();

    await _recordExecutionStatus(ExecutionOutcome.alarmTerminated);

    _resetState();
  }

  Future<void> _onAlarmTimeout() async {
    if (_state != MonitoringState.alarmActive) return;
    if (_activeRule == null) return;

    await _alarmService.stopAlarm();
    _movementService.dispose();

    await _recordExecutionStatus(ExecutionOutcome.alarmTimedOut);

    _resetState();
  }

  Future<void> _recordExecutionStatus(
    ExecutionOutcome outcome, {
    String? failureReason,
  }) async {
    if (_activeRule == null) return;

    final status = RuleExecutionStatus(
      date: DateTime.now(),
      outcome: outcome,
      thresholdCrossedAt: _thresholdCrossedAt,
      alarmTriggeredAt: _alarmStartTime,
      alarmStoppedAt:
          outcome == ExecutionOutcome.alarmTerminated ||
              outcome == ExecutionOutcome.alarmTimedOut
          ? DateTime.now()
          : null,
      failureReason: failureReason,
    );

    final updatedRule = _activeRule!.copyWith(lastExecutionStatus: status);
    await _storageService.saveRule(updatedRule);
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
    _thresholdCrossedAt = null;
    _currentTerminationProgress = 0.0;
  }

  Future<void> stopCurrentMonitoring() async {
    if (_state == MonitoringState.alarmActive) {
      await _alarmService.stopAlarm();
    }
    _resetState();
  }

  void dispose() {
    _resetState();
    _alarmService.dispose();
  }
}
