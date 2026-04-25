import 'package:get_it/get_it.dart';
import 'services/storage_service.dart';
import 'services/app_monitoring_service.dart';
import 'services/movement_service.dart';
import 'services/alarm_service.dart';
import 'services/monitoring_orchestrator.dart';
import 'services/countdown_overlay_service.dart';
import 'services/monitoring_manager.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  // Storage
  final storageService = StorageService();
  await storageService.initialize();
  getIt.registerSingleton<StorageService>(storageService);

  // Services
  getIt.registerSingleton<AppMonitoringService>(AppMonitoringService());
  getIt.registerSingleton<MovementService>(MovementService());
  getIt.registerSingleton<CountdownOverlayService>(CountdownOverlayService());

  final alarmService = AlarmService();
  await alarmService.initialize();
  getIt.registerSingleton<AlarmService>(alarmService);

  // Orchestrator
  getIt.registerSingleton<MonitoringOrchestrator>(
    MonitoringOrchestrator(
      appMonitor: getIt<AppMonitoringService>(),
      movementService: getIt<MovementService>(),
      alarmService: getIt<AlarmService>(),
      storageService: getIt<StorageService>(),
      overlayService: getIt<CountdownOverlayService>(),
    ),
  );

  // Monitoring Manager
  final monitoringManager = MonitoringManager(
    orchestrator: getIt<MonitoringOrchestrator>(),
    storageService: getIt<StorageService>(),
    appMonitor: getIt<AppMonitoringService>(),
  );
  await monitoringManager.initialize();
  getIt.registerSingleton<MonitoringManager>(monitoringManager);
}
