import 'package:freezed_annotation/freezed_annotation.dart';

part 'discipline_rule.freezed.dart';
part 'discipline_rule.g.dart';

@freezed
class DisciplineRule with _$DisciplineRule {
  const factory DisciplineRule({
    required String id,
    required String label,
    required List<String> monitoredApps,
    required TimeWindow monitoringWindow,
    required Duration thresholdDuration,
    required Duration maxAlarmDuration,
    required String alarmSound,
    String? alarmSoundTitle,
    required TerminationMechanism terminationMechanism,
    @Default(true) bool isEnabled,
    RuleExecutionStatus? lastExecutionStatus,
  }) = _DisciplineRule;

  factory DisciplineRule.fromJson(Map<String, dynamic> json) =>
      _$DisciplineRuleFromJson(json);
}

@freezed
class RuleExecutionStatus with _$RuleExecutionStatus {
  const factory RuleExecutionStatus({
    required DateTime date,
    required ExecutionOutcome outcome,
    DateTime? thresholdCrossedAt,
    DateTime? alarmTriggeredAt,
    DateTime? alarmStoppedAt,
    String? failureReason,
  }) = _RuleExecutionStatus;

  factory RuleExecutionStatus.fromJson(Map<String, dynamic> json) =>
      _$RuleExecutionStatusFromJson(json);
}

enum ExecutionOutcome {
  success,              // Threshold not crossed
  alarmTerminated,      // Threshold crossed, alarm rang and was terminated
  alarmTimedOut,        // Threshold crossed, alarm ran full duration
  alarmFailedToTrigger, // Threshold crossed but alarm didn't trigger
  alarmTooLate,         // Threshold crossed but > 2 min passed before detection
}

@freezed
class TimeWindow with _$TimeWindow {
  const factory TimeWindow({
    required DateTime startTime,
    required DateTime endTime,
  }) = _TimeWindow;

  factory TimeWindow.fromJson(Map<String, dynamic> json) =>
      _$TimeWindowFromJson(json);
}

@freezed
class TerminationMechanism with _$TerminationMechanism {
  const factory TerminationMechanism.steps({
    required int requiredSteps,
  }) = StepsTermination;

  const factory TerminationMechanism.movement({
    required double requiredMovement,
  }) = MovementTermination;

  factory TerminationMechanism.fromJson(Map<String, dynamic> json) =>
      _$TerminationMechanismFromJson(json);
}

