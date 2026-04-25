import 'package:flutter/material.dart';
import '../services/app_monitoring_service.dart';
import '../dependency_injection.dart';

class PermissionPromptWidget extends StatefulWidget {
  final ValueChanged<bool> onPermissionChanged;

  const PermissionPromptWidget({
    super.key,
    required this.onPermissionChanged,
  });

  @override
  State<PermissionPromptWidget> createState() => _PermissionPromptWidgetState();
}

class _PermissionPromptWidgetState extends State<PermissionPromptWidget> {
  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final appMonitor = getIt<AppMonitoringService>();
    final hasPermission = await appMonitor.hasUsageStatsPermission();
    widget.onPermissionChanged(hasPermission);
  }

  Future<void> _requestPermission() async {
    final appMonitor = getIt<AppMonitoringService>();
    await appMonitor.requestPermissions();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grant Usage Access'),
        content: const Text(
          'To track app usage, you need to grant Usage Access permission:\n\n'
          '1. Find "Morning Discipline" in the list\n'
          '2. Toggle the permission ON\n'
          '3. Return to the app\n\n'
          'This permission allows the app to monitor which apps you use '
          'and for how long, so it can trigger alarms when thresholds are exceeded.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _checkPermission();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      color: Colors.orange.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Permission Required',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'To monitor app usage and trigger alarms, this app needs '
              'access to Usage Stats. This permission allows the app to see '
              'which apps you use and for how long.',
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _checkPermission,
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _requestPermission,
                  child: const Text('Grant Permission'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
