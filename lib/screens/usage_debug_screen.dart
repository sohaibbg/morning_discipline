import 'package:flutter/material.dart';
import '../services/app_monitoring_service.dart';
import '../services/countdown_overlay_service.dart';
import '../services/monitoring_orchestrator.dart';
import '../services/alarm_service.dart';
import '../dependency_injection.dart';
import 'package:intl/intl.dart';

class UsageDebugWidget extends StatefulWidget {
  const UsageDebugWidget({super.key});

  @override
  State<UsageDebugWidget> createState() => _UsageDebugWidgetState();
}

class _UsageDebugWidgetState extends State<UsageDebugWidget> {
  bool _isLoading = false;
  Map<String, Duration>? _usageData;
  String? _error;
  bool _hasUsagePermission = false;
  bool _hasOverlayPermission = false;
  String? _foregroundApp;
  MonitoringState _monitoringState = MonitoringState.idle;
  bool _alarmPlaying = false;

  @override
  void initState() {
    super.initState();
    _checkAllPermissions();
  }

  Future<void> _checkAllPermissions() async {
    final appMonitor = getIt<AppMonitoringService>();
    final overlayService = getIt<CountdownOverlayService>();
    final orchestrator = getIt<MonitoringOrchestrator>();

    final hasUsage = await appMonitor.hasUsageStatsPermission();
    final hasOverlay = await overlayService.hasOverlayPermission();
    final foreground = await appMonitor.getForegroundApp();

    setState(() {
      _hasUsagePermission = hasUsage;
      _hasOverlayPermission = hasOverlay;
      _foregroundApp = foreground;
      _monitoringState = orchestrator.state;
    });
  }

  Future<void> _fetchUsageData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final appMonitor = getIt<AppMonitoringService>();

      // Get usage for last 24 hours
      final now = DateTime.now();
      final yesterday = now.subtract(const Duration(hours: 24));

      // Get some common apps
      final testPackages = [
        'com.instagram.android',
        'com.twitter.android',
        'com.facebook.katana',
        'com.whatsapp',
        'com.android.chrome',
        'com.google.android.youtube',
      ];

      final usage = await appMonitor.getAppUsageForWindow(
        testPackages,
        yesterday,
        now,
      );

      setState(() {
        _usageData = usage;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usage Debug Tool'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkAllPermissions,
            tooltip: 'Refresh Status',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSystemStatus(),
            const SizedBox(height: 16),
            _buildPermissionsCard(),
            const SizedBox(height: 16),
            _buildMonitoringStatus(),
            const SizedBox(height: 16),
            _buildAlarmTestCard(),
            const SizedBox(height: 16),
            _buildFetchButton(),
            const SizedBox(height: 16),
            if (_isLoading) _buildLoadingIndicator(),
            if (_error != null) _buildError(),
            if (_usageData != null) _buildUsageData(),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.info_outline, size: 20),
                SizedBox(width: 8),
                Text(
                  'System Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildStatusRow(
              'Foreground App',
              _foregroundApp ?? 'Unknown',
              _foregroundApp != null ? Colors.green : Colors.grey,
            ),
            const Divider(),
            _buildStatusRow(
              'Monitoring State',
              _monitoringState.name.toUpperCase(),
              _getMonitoringStateColor(_monitoringState),
            ),
            const Divider(),
            _buildStatusRow(
              'Time',
              DateFormat('HH:mm:ss').format(DateTime.now()),
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, size: 20),
                SizedBox(width: 8),
                Text(
                  'Permissions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildPermissionRow('Usage Stats', _hasUsagePermission, () async {
              final appMonitor = getIt<AppMonitoringService>();
              await appMonitor.requestPermissions();
              _checkAllPermissions();
            }),
            const Divider(),
            _buildPermissionRow(
              'Display Over Apps',
              _hasOverlayPermission,
              () async {
                final overlayService = getIt<CountdownOverlayService>();
                await overlayService.requestOverlayPermission();
                await Future.delayed(const Duration(milliseconds: 500));
                _checkAllPermissions();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoringStatus() {
    final orchestrator = getIt<MonitoringOrchestrator>();
    final currentUsage = orchestrator.currentAppUsage;
    final hasUsage = currentUsage.inSeconds > 0;

    return Card(
      color: _monitoringState == MonitoringState.monitoring
          ? Colors.green.shade50
          : _monitoringState == MonitoringState.alarmActive
          ? Colors.red.shade50
          : Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getMonitoringStateIcon(_monitoringState),
                  size: 20,
                  color: _getMonitoringStateColor(_monitoringState),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Monitoring Status',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'State: ${_monitoringState.name.toUpperCase()}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _getMonitoringStateColor(_monitoringState),
              ),
            ),
            if (hasUsage) ...[
              const SizedBox(height: 8),
              Text(
                'Current Usage: ${_formatDuration(currentUsage)}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionRow(
    String label,
    bool granted,
    VoidCallback onRequest,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.cancel,
            color: granted ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          if (!granted)
            TextButton(onPressed: onRequest, child: const Text('Grant'))
          else
            Text(
              'Granted',
              style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Color _getMonitoringStateColor(MonitoringState state) {
    return switch (state) {
      MonitoringState.idle => Colors.grey,
      MonitoringState.monitoring => Colors.green,
      MonitoringState.alarmActive => Colors.red,
      MonitoringState.completed => Colors.blue,
    };
  }

  IconData _getMonitoringStateIcon(MonitoringState state) {
    return switch (state) {
      MonitoringState.idle => Icons.pause_circle_outline,
      MonitoringState.monitoring => Icons.visibility,
      MonitoringState.alarmActive => Icons.alarm,
      MonitoringState.completed => Icons.check_circle,
    };
  }

  Widget _buildAlarmTestCard() {
    return Card(
      color: _alarmPlaying ? Colors.orange.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _alarmPlaying ? Icons.alarm_on : Icons.alarm,
                  size: 20,
                  color: _alarmPlaying ? Colors.orange : null,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Alarm Test',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _alarmPlaying
                  ? 'Alarm is currently playing'
                  : 'Test the alarm sound',
              style: TextStyle(
                color: _alarmPlaying ? Colors.orange.shade900 : Colors.grey,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _alarmPlaying ? null : _testPlayAlarm,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Play Alarm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _alarmPlaying ? _testStopAlarm : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Alarm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _testPlayAlarm() async {
    try {
      final alarmService = getIt<AlarmService>();
      await alarmService.playAlarm('default');
      setState(() => _alarmPlaying = true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error playing alarm: $e')));
    }
  }

  Future<void> _testStopAlarm() async {
    try {
      final alarmService = getIt<AlarmService>();
      await alarmService.stopAlarm();
      setState(() {
        _alarmPlaying = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error stopping alarm: $e')));
    }
  }

  Widget _buildFetchButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _hasUsagePermission ? _fetchUsageData : null,
        icon: const Icon(Icons.refresh),
        label: const Text('Fetch Last 24h Usage'),
        style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Center(
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Fetching usage data...'),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error, color: Colors.red.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Error',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.red.shade900,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageData() {
    final sortedEntries = _usageData!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Usage Data (Last 24h)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  DateFormat('MMM dd, HH:mm').format(DateTime.now()),
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
            const Divider(),
            ...sortedEntries.map((entry) => _buildUsageItem(entry)),
            const Divider(),
            _buildTotalUsage(),
          ],
        ),
      ),
    );
  }

  Widget _buildUsageItem(MapEntry<String, Duration> entry) {
    final packageName = entry.key;
    final duration = entry.value;
    final appName = _getAppName(packageName);
    final hasUsage = duration.inSeconds > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            hasUsage ? Icons.phone_android : Icons.phone_android_outlined,
            color: hasUsage ? Colors.blue : Colors.grey,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appName,
                  style: TextStyle(
                    fontWeight: hasUsage ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                Text(
                  packageName,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            _formatDuration(duration),
            style: TextStyle(
              fontSize: 16,
              fontWeight: hasUsage ? FontWeight.bold : FontWeight.normal,
              color: hasUsage ? Colors.blue : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalUsage() {
    final total = _usageData!.values.fold(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Total Usage',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text(
            _formatDuration(total),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  String _getAppName(String packageName) {
    final names = {
      'com.instagram.android': 'Instagram',
      'com.twitter.android': 'Twitter',
      'com.facebook.katana': 'Facebook',
      'com.whatsapp': 'WhatsApp',
      'com.android.chrome': 'Chrome',
      'com.google.android.youtube': 'YouTube',
    };
    return names[packageName] ?? packageName.split('.').last;
  }

  String _formatDuration(Duration duration) {
    if (duration.inSeconds == 0) {
      return '0m';
    }

    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
