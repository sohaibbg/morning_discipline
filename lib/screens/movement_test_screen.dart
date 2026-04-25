import 'package:flutter/material.dart';
import 'dart:async';
import '../services/movement_service.dart';
import '../dependency_injection.dart';

class MovementTestScreen extends StatefulWidget {
  const MovementTestScreen({super.key});

  @override
  State<MovementTestScreen> createState() => _MovementTestScreenState();
}

class _MovementTestScreenState extends State<MovementTestScreen> {
  final _movementService = getIt<MovementService>();

  int _stepCount = 0;
  double _movementAmount = 0.0;
  bool _isTracking = false;
  String _status = 'Not tracking';

  @override
  void dispose() {
    _stopTracking();
    super.dispose();
  }

  Future<void> _startTracking() async {
    setState(() {
      _isTracking = true;
      _status = 'Tracking...';
      _stepCount = 0;
      _movementAmount = 0.0;
    });

    try {
      // Start step tracking
      await _movementService.startStepTracking((steps) {
        if (mounted) {
          setState(() {
            _stepCount = steps;
          });
        }
      });

      // Start movement tracking
      await _movementService.startMovementTracking((movement) {
        if (mounted) {
          setState(() {
            _movementAmount = movement;
          });
        }
      });

      setState(() {
        _status = 'Tracking active';
      });
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isTracking = false;
      });
    }
  }

  void _stopTracking() {
    _movementService.dispose();
    setState(() {
      _isTracking = false;
      _status = 'Stopped';
    });
  }

  void _reset() {
    _stopTracking();
    setState(() {
      _stepCount = 0;
      _movementAmount = 0.0;
      _status = 'Reset';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Movement Detection'),
        actions: [
          if (_isTracking)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _reset,
              tooltip: 'Reset',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildInstructionsCard(),
            const SizedBox(height: 24),
            _buildStatusIndicator(),
            const SizedBox(height: 24),
            _buildMetricCard(
              title: 'Walking Steps',
              icon: Icons.directions_walk,
              value: _stepCount.toString(),
              unit: 'steps',
              color: Colors.blue,
              isActive: _isTracking,
            ),
            const SizedBox(height: 16),
            _buildMetricCard(
              title: 'Movement Detected',
              icon: Icons.motion_photos_on,
              value: _movementAmount.toStringAsFixed(1),
              unit: 'units',
              color: Colors.purple,
              isActive: _isTracking,
            ),
            const SizedBox(height: 24),
            if (_isTracking) ...[
              const Divider(),
              const SizedBox(height: 16),
              _buildThresholdExamples(),
            ],
            const SizedBox(height: 100),
          ],
        ),
      ),
      floatingActionButton: _isTracking
          ? FloatingActionButton.extended(
              onPressed: _stopTracking,
              icon: const Icon(Icons.stop),
              label: const Text('Stop Tracking'),
              backgroundColor: Colors.red,
            )
          : FloatingActionButton.extended(
              onPressed: _startTracking,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start Tracking'),
            ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Text(
                  'How to Test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '1. Tap "Start Tracking" below\n'
              '2. For steps: Walk around with your phone\n'
              '3. For movement: Shake or move your device\n'
              '4. Watch the counters update in real-time',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isTracking ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isTracking ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _isTracking ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            _status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _isTracking ? Colors.green.shade900 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required IconData icon,
    required String value,
    required String unit,
    required Color color,
    required bool isActive,
  }) {
    return Card(
      elevation: isActive ? 4 : 1,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [color.withOpacity(0.1), Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isActive ? 'Detecting...' : 'Not tracking',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  unit,
                  style: TextStyle(fontSize: 20, color: Colors.grey.shade600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThresholdExamples() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Example Thresholds',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        _buildThresholdRow(
          '50 steps',
          _stepCount >= 50,
          'Short walk around the room',
        ),
        _buildThresholdRow(
          '100 steps',
          _stepCount >= 100,
          'Walk to another room',
        ),
        _buildThresholdRow(
          '200 steps',
          _stepCount >= 200,
          'Short walk outside',
        ),
        const SizedBox(height: 8),
        _buildThresholdRow(
          '50 movement units',
          _movementAmount >= 50,
          'Shake device moderately',
        ),
        _buildThresholdRow(
          '100 movement units',
          _movementAmount >= 100,
          'Shake device vigorously',
        ),
      ],
    );
  }

  Widget _buildThresholdRow(String label, bool achieved, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            achieved ? Icons.check_circle : Icons.radio_button_unchecked,
            color: achieved ? Colors.green : Colors.grey.shade400,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: achieved ? FontWeight.bold : FontWeight.normal,
                    color: achieved ? Colors.green.shade900 : null,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
