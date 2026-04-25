import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/monitoring_orchestrator.dart';
import '../dependency_injection.dart';

final monitoringProvider = StateNotifierProvider<MonitoringNotifier, MonitoringState>(
  (ref) => MonitoringNotifier(getIt<MonitoringOrchestrator>()),
);

class MonitoringNotifier extends StateNotifier<MonitoringState> {
  final MonitoringOrchestrator _orchestrator;

  MonitoringNotifier(this._orchestrator) : super(MonitoringState.idle);

  MonitoringState get currentState => _orchestrator.state;
  Duration get currentAppUsage => _orchestrator.currentAppUsage;

  void updateState() {
    state = _orchestrator.state;
  }
}
