import 'package:freezed_annotation/freezed_annotation.dart';

part 'discipline_log.freezed.dart';
part 'discipline_log.g.dart';

@freezed
class DisciplineLog with _$DisciplineLog {
  const factory DisciplineLog({
    required String id,
    required String ruleId,
    required String ruleLabel,
    required DateTime timestamp,
    required Duration totalAppUsage,
    required Duration thresholdDuration,
    required bool alarmTriggered,
    required bool terminationCompleted,
    required Duration alarmDuration,
    required LogStatus status,
  }) = _DisciplineLog;

  factory DisciplineLog.fromJson(Map<String, dynamic> json) =>
      _$DisciplineLogFromJson(json);
}

enum LogStatus {
  noAppUsage,
  belowThreshold,
  alarmTriggered,
  terminationCompleted,
  alarmTimedOut,
}

