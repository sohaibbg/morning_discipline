import 'dart:async';
import 'package:pedometer/pedometer.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class MovementService {
  StreamSubscription<StepCount>? _stepSubscription;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  int _initialSteps = 0;
  int _currentSteps = 0;
  double _totalMovement = 0.0;

  Future<bool> requestPermissions() async {
    if (await Permission.activityRecognition.isDenied) {
      final status = await Permission.activityRecognition.request();
      return status.isGranted;
    }
    return true;
  }

  Future<void> startStepTracking(Function(int steps) onStepUpdate) async {
    await requestPermissions();

    _stepSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (_initialSteps == 0) {
          _initialSteps = event.steps;
        }
        _currentSteps = event.steps - _initialSteps;
        onStepUpdate(_currentSteps);
      },
      onError: (error) {
        // Handle error
      },
    );
  }

  void stopStepTracking() {
    _stepSubscription?.cancel();
    _initialSteps = 0;
    _currentSteps = 0;
  }

  int get currentSteps => _currentSteps;

  Future<void> startMovementTracking(
      Function(double movement) onMovementUpdate) async {
    double lastX = 0, lastY = 0, lastZ = 0;

    _accelerometerSubscription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        final deltaX = (event.x - lastX).abs();
        final deltaY = (event.y - lastY).abs();
        final deltaZ = (event.z - lastZ).abs();

        _totalMovement += deltaX + deltaY + deltaZ;

        lastX = event.x;
        lastY = event.y;
        lastZ = event.z;

        onMovementUpdate(_totalMovement);
      },
    );
  }

  void stopMovementTracking() {
    _accelerometerSubscription?.cancel();
    _totalMovement = 0.0;
  }

  double get totalMovement => _totalMovement;

  void dispose() {
    stopStepTracking();
    stopMovementTracking();
  }
}
