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
  }) = _DisciplineRule;

  factory DisciplineRule.fromJson(Map<String, dynamic> json) =>
      _$DisciplineRuleFromJson(json);
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

