import 'package:hive_flutter/hive_flutter.dart';
import 'dart:convert';
import '../models/discipline_rule.dart';
import '../models/discipline_log.dart';

class StorageService {
  static const String _rulesBoxName = 'discipline_rules';
  static const String _logsBoxName = 'discipline_logs';

  Future<void> initialize() async {
    await Hive.initFlutter();

    // Open boxes (storing as JSON strings)
    await Hive.openBox<String>(_rulesBoxName);
    await Hive.openBox<String>(_logsBoxName);
  }

  Box<String> get _rulesBox => Hive.box<String>(_rulesBoxName);
  Box<String> get _logsBox => Hive.box<String>(_logsBoxName);

  // Rules operations
  Future<void> saveRule(DisciplineRule rule) async {
    final jsonString = jsonEncode(rule.toJson());
    await _rulesBox.put(rule.id, jsonString);
  }

  Future<void> deleteRule(String id) async {
    await _rulesBox.delete(id);
  }

  List<DisciplineRule> getAllRules() {
    return _rulesBox.values.map((jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DisciplineRule.fromJson(json);
    }).toList();
  }

  DisciplineRule? getRule(String id) {
    final jsonString = _rulesBox.get(id);
    if (jsonString == null) return null;
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return DisciplineRule.fromJson(json);
  }

  // Logs operations
  Future<void> saveLog(DisciplineLog log) async {
    final jsonString = jsonEncode(log.toJson());
    await _logsBox.put(log.id, jsonString);
  }

  List<DisciplineLog> getAllLogs() {
    return _logsBox.values.map((jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DisciplineLog.fromJson(json);
    }).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  List<DisciplineLog> getLogsByDateRange(DateTime start, DateTime end) {
    return _logsBox.values.map((jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return DisciplineLog.fromJson(json);
    }).where((log) =>
            log.timestamp.isAfter(start) && log.timestamp.isBefore(end))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> clearAllLogs() async {
    await _logsBox.clear();
  }
}

