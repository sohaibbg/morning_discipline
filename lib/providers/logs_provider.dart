import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discipline_log.dart';
import '../services/storage_service.dart';
import '../dependency_injection.dart';

final logsProvider = StateNotifierProvider<LogsNotifier, List<DisciplineLog>>(
  (ref) => LogsNotifier(getIt<StorageService>()),
);

class LogsNotifier extends StateNotifier<List<DisciplineLog>> {
  final StorageService _storageService;

  LogsNotifier(this._storageService) : super([]) {
    _loadLogs();
  }

  void _loadLogs() {
    state = _storageService.getAllLogs();
  }

  List<DisciplineLog> getLogsByDateRange(DateTime start, DateTime end) {
    return _storageService.getLogsByDateRange(start, end);
  }

  Future<void> clearAllLogs() async {
    await _storageService.clearAllLogs();
    state = [];
  }

  void refresh() {
    _loadLogs();
  }
}
