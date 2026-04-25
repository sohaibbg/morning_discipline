import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import '../models/discipline_rule.dart';
import '../providers/rules_provider.dart';
import '../services/app_monitoring_service.dart';
import '../services/monitoring_orchestrator.dart';
import '../dependency_injection.dart';

class RuleCard extends ConsumerStatefulWidget {
  final DisciplineRule rule;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const RuleCard({
    super.key,
    required this.rule,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  ConsumerState<RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends ConsumerState<RuleCard>
    with WidgetsBindingObserver {
  final _appMonitor = getIt<AppMonitoringService>();
  Duration _currentUsage = Duration.zero;
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startMonitoring();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateUsage();
    }
  }

  void _startMonitoring() {
    const frequency = Duration(milliseconds: 100);
    _updateTimer = Timer.periodic(frequency, (_) {
      _updateUsage();
      // Also trigger rebuild to update alarm status
      if (mounted) {
        setState(() {});
      }
    });
    _updateUsage();
  }

  Future<void> _updateUsage() async {
    if (!widget.rule.isEnabled) return;
    if (!_isInMonitoringWindow()) return;

    final now = DateTime.now();
    final windowStart = affixTodaysDateToTime(
      widget.rule.monitoringWindow.startTime,
    );
    final usageMap = await _appMonitor.getAppUsageForWindow(
      widget.rule.monitoredApps,
      windowStart,
      now,
    );

    final totalUsage = _appMonitor.calculateTotalUsage(usageMap);
    if (!mounted) return;
    setState(() => _currentUsage = totalUsage);
  }

  bool _isInMonitoringWindow() {
    final now = DateTime.now();
    final startTime = widget.rule.monitoringWindow.startTime;
    final endTime = widget.rule.monitoringWindow.endTime;

    final nowTime = TimeOfDay.fromDateTime(now);
    final start = TimeOfDay(hour: startTime.hour, minute: startTime.minute);
    final end = TimeOfDay(hour: endTime.hour, minute: endTime.minute);

    final nowMinutes = nowTime.hour * 60 + nowTime.minute;
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;

    final isAfterStart = nowMinutes >= startMinutes;
    final isBeforeEnd = nowMinutes <= endMinutes;
    if (startMinutes <= endMinutes) {
      return isAfterStart && isBeforeEnd;
    }
    return isAfterStart || isBeforeEnd;
  }

  DateTime affixTodaysDateToTime(DateTime startTime) {
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      startTime.hour,
      startTime.minute,
    );
  }

  @override
  Widget build(BuildContext context) {
    final orchestrator = getIt<MonitoringOrchestrator>();
    final isMonitoring = widget.rule.isEnabled && _isInMonitoringWindow();
    final isActiveRule = orchestrator.activeRule?.id == widget.rule.id;
    final isAlarmActive = isActiveRule && orchestrator.state == MonitoringState.alarmActive;

    final ruleActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Switch(
          value: widget.rule.isEnabled,
          onChanged: (_) async {
            // If alarm is active for this rule, stop it
            if (isAlarmActive) {
              await orchestrator.stopCurrentMonitoring();
            }
            ref.read(rulesProvider.notifier).toggleRule(widget.rule.id);
          },
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'edit':
                widget.onEdit();
              case 'duplicate':
                widget.onDuplicate();
              case 'delete':
                widget.onDelete();
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20),
                  SizedBox(width: 12),
                  Text('Edit'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'duplicate',
              child: Row(
                children: [
                  Icon(Icons.content_copy, size: 20),
                  SizedBox(width: 12),
                  Text('Duplicate'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.rule.label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                ruleActions,
              ],
            ),
            if (isMonitoring) buildMonitoringStatus(),
            if (isAlarmActive) buildAlarmStatus(),
            if (!isMonitoring && !isAlarmActive) buildExecutionStatus(),
          ],
        ),
      ),
    );
  }

  Widget buildExecutionStatus() {
    final status = widget.rule.lastExecutionStatus;
    if (status == null) return const SizedBox.shrink();

    // Only show status for last 7 days
    final daysSince = DateTime.now().difference(status.date).inDays;
    if (daysSince > 7) return const SizedBox.shrink();

    final statusInfo = _getStatusInfo(status.outcome);
    final isToday = daysSince == 0;
    final dateText = isToday ? 'Today' : '$daysSince day${daysSince == 1 ? '' : 's'} ago';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusInfo.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusInfo.color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(statusInfo.icon, color: statusInfo.color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  statusInfo.message,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusInfo.color,
                  ),
                ),
                Text(
                  dateText,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
                if (status.failureReason != null)
                  Text(
                    status.failureReason!,
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusInfo _getStatusInfo(ExecutionOutcome outcome) {
    return switch (outcome) {
      ExecutionOutcome.success => _StatusInfo(
        icon: Icons.check_circle,
        color: Colors.green,
        message: 'Success - threshold not crossed',
      ),
      ExecutionOutcome.alarmTerminated => _StatusInfo(
        icon: Icons.task_alt,
        color: Colors.orange,
        message: 'Alarm rang and was terminated',
      ),
      ExecutionOutcome.alarmTimedOut => _StatusInfo(
        icon: Icons.alarm_off,
        color: Colors.red,
        message: 'Alarm rang until timeout',
      ),
      ExecutionOutcome.alarmFailedToTrigger => _StatusInfo(
        icon: Icons.error,
        color: Colors.red,
        message: 'Alarm failed to trigger',
      ),
      ExecutionOutcome.alarmTooLate => _StatusInfo(
        icon: Icons.schedule,
        color: Colors.orange,
        message: 'Detection delayed - alarm not triggered',
      ),
    };
  }

  Widget buildAlarmStatus() {
    final orchestrator = getIt<MonitoringOrchestrator>();
    final progress = orchestrator.terminationProgress;
    final rule = widget.rule;

    final progressText = rule.terminationMechanism.when(
      steps: (requiredSteps) {
        final currentSteps = (progress * requiredSteps).toInt();
        return '$currentSteps / $requiredSteps steps';
      },
      movement: (requiredMovement) {
        final currentMovement = (progress * requiredMovement).toInt();
        return '$currentMovement / ${requiredMovement.toInt()} units';
      },
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.alarm, color: Colors.red.shade700, size: 20),
              const SizedBox(width: 8),
              Text(
                'ALARM ACTIVE',
                style: TextStyle(
                  color: Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            progressText,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  AnimatedContainer buildMonitoringStatus() {
    final fraction =
        _currentUsage.inMilliseconds /
        widget.rule.thresholdDuration.inMilliseconds;
    final blinkingMonitorIndicator = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, child) {
        return Opacity(
          opacity: 0.3 + (value * 0.7),
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
    final progressBar = TweenAnimationBuilder<double>(
      tween: Tween(
        begin: 0.0,
        end:
            _currentUsage.inMilliseconds /
            widget.rule.thresholdDuration.inMilliseconds,
      ),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return LinearProgressIndicator(
          borderRadius: BorderRadius.circular(4),
          value: value,
          minHeight: 6,
          backgroundColor: Colors.grey.shade300,
          valueColor: AlwaysStoppedAnimation<Color>(
            fraction >= 1.0 ? Colors.red : Colors.blue,
          ),
        );
      },
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              blinkingMonitorIndicator,
              const SizedBox(width: 8),
              Text(
                'Monitoring live',
                style: TextStyle(
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              progressBar,
              const SizedBox(height: 4),
              Text(
                '${_formatDuration(_currentUsage)} / ${_formatDuration(widget.rule.thresholdDuration)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);

    if (duration.inMinutes < 0) return '${seconds}s';
    if (duration.inMinutes < 3) {
      if (seconds == 0) return '${minutes}m';
      return '${minutes}m ${seconds}s';
    }
    return '${minutes}m';
  }
}

class _StatusInfo {
  final IconData icon;
  final Color color;
  final String message;

  _StatusInfo({
    required this.icon,
    required this.color,
    required this.message,
  });
}
