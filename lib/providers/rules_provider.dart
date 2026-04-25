import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discipline_rule.dart';
import '../services/storage_service.dart';
import '../dependency_injection.dart';

final rulesProvider = StateNotifierProvider<RulesNotifier, List<DisciplineRule>>(
  (ref) => RulesNotifier(getIt<StorageService>()),
);

class RulesNotifier extends StateNotifier<List<DisciplineRule>> {
  final StorageService _storageService;

  RulesNotifier(this._storageService) : super([]) {
    _loadRules();
  }

  void _loadRules() {
    state = _storageService.getAllRules();
  }

  Future<void> addRule(DisciplineRule rule) async {
    await _storageService.saveRule(rule);
    state = [...state, rule];
  }

  Future<void> updateRule(DisciplineRule rule) async {
    await _storageService.saveRule(rule);
    state = [
      for (final r in state)
        if (r.id == rule.id) rule else r
    ];
  }

  Future<void> deleteRule(String id) async {
    await _storageService.deleteRule(id);
    state = state.where((r) => r.id != id).toList();
  }

  Future<void> toggleRule(String id) async {
    final rule = state.firstWhere((r) => r.id == id);
    final updatedRule = rule.copyWith(isEnabled: !rule.isEnabled);
    await updateRule(updatedRule);
  }
}
