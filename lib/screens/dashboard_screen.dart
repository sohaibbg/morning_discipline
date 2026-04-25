import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/discipline_log.dart';
import '../providers/logs_provider.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  DateTime _selectedStartDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _selectedEndDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final allLogs = ref.watch(logsProvider);
    final filteredLogs = allLogs.where((log) {
      return log.timestamp.isAfter(_selectedStartDate) &&
          log.timestamp.isBefore(_selectedEndDate.add(const Duration(days: 1)));
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(logsProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildDateRangeSelector(),
          const SizedBox(height: 16),
          _buildStatisticsCards(filteredLogs),
          const SizedBox(height: 16),
          _buildSuccessRateChart(filteredLogs),
          const SizedBox(height: 16),
          _buildStatusDistributionChart(filteredLogs),
          const SizedBox(height: 16),
          _buildLogsList(filteredLogs),
        ],
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Date Range',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectDate(context, true),
                    child: Text(
                      'From: ${DateFormat('MMM dd, yyyy').format(_selectedStartDate)}',
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => _selectDate(context, false),
                    child: Text(
                      'To: ${DateFormat('MMM dd, yyyy').format(_selectedEndDate)}',
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStartDate =
                          DateTime.now().subtract(const Duration(days: 7));
                      _selectedEndDate = DateTime.now();
                    });
                  },
                  child: const Text('7 Days'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStartDate =
                          DateTime.now().subtract(const Duration(days: 30));
                      _selectedEndDate = DateTime.now();
                    });
                  },
                  child: const Text('30 Days'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedStartDate =
                          DateTime.now().subtract(const Duration(days: 90));
                      _selectedEndDate = DateTime.now();
                    });
                  },
                  child: const Text('90 Days'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStart ? _selectedStartDate : _selectedEndDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _selectedStartDate = date;
        } else {
          _selectedEndDate = date;
        }
      });
    }
  }

  Widget _buildStatisticsCards(List<DisciplineLog> logs) {
    final totalLogs = logs.length;
    final alarmsTriggered = logs.where((log) => log.alarmTriggered).length;
    final terminationCompleted =
        logs.where((log) => log.terminationCompleted).length;
    final successRate =
        alarmsTriggered > 0 ? (terminationCompleted / alarmsTriggered * 100) : 0;

    return Row(
      children: [
        Expanded(
          child: Card(
            color: Colors.blue.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    totalLogs.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const Text('Total Records'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.orange.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    alarmsTriggered.toString(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const Text('Alarms'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Card(
            color: Colors.green.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    '${successRate.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  const Text('Success Rate'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessRateChart(List<DisciplineLog> logs) {
    if (logs.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: Text('No data available'),
          ),
        ),
      );
    }

    // Group logs by date
    final Map<DateTime, List<DisciplineLog>> logsByDate = {};
    for (final log in logs) {
      final date = DateTime(
        log.timestamp.year,
        log.timestamp.month,
        log.timestamp.day,
      );
      logsByDate.putIfAbsent(date, () => []).add(log);
    }

    final sortedDates = logsByDate.keys.toList()..sort();
    final spots = <FlSpot>[];

    for (var i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      final dateLogs = logsByDate[date]!;
      final alarmsTriggered = dateLogs.where((log) => log.alarmTriggered).length;
      final terminationCompleted =
          dateLogs.where((log) => log.terminationCompleted).length;
      final successRate =
          alarmsTriggered > 0 ? (terminationCompleted / alarmsTriggered * 100) : 0.0;
      spots.add(FlSpot(i.toDouble(), successRate.toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Success Rate Over Time',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text('${value.toInt()}%');
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < sortedDates.length) {
                            final date = sortedDates[value.toInt()];
                            return Text(DateFormat('MM/dd').format(date));
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: true),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.green,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDistributionChart(List<DisciplineLog> logs) {
    if (logs.isEmpty) {
      return const SizedBox.shrink();
    }

    final statusCounts = <LogStatus, int>{};
    for (final log in logs) {
      statusCounts[log.status] = (statusCounts[log.status] ?? 0) + 1;
    }

    final sections = statusCounts.entries.map((entry) {
      final color = _getStatusColor(entry.key);
      final percentage = (entry.value / logs.length * 100);
      return PieChartSectionData(
        value: entry.value.toDouble(),
        title: '${percentage.toStringAsFixed(0)}%',
        color: color,
        radius: 100,
        titleStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Status Distribution',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: statusCounts.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      color: _getStatusColor(entry.key),
                    ),
                    const SizedBox(width: 4),
                    Text(_getStatusLabel(entry.key)),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogsList(List<DisciplineLog> logs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Logs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (logs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No logs in selected period'),
                ),
              )
            else
              ...logs.take(20).map((log) => _buildLogItem(log)),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(DisciplineLog log) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getStatusColor(log.status),
          child: Icon(
            _getStatusIcon(log.status),
            color: Colors.white,
          ),
        ),
        title: Text(log.ruleLabel),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('MMM dd, yyyy HH:mm').format(log.timestamp)),
            Text('Usage: ${_formatDuration(log.totalAppUsage)}'),
            if (log.alarmTriggered)
              Text('Alarm: ${_formatDuration(log.alarmDuration)}'),
          ],
        ),
        trailing: Text(_getStatusLabel(log.status)),
      ),
    );
  }

  Color _getStatusColor(LogStatus status) {
    switch (status) {
      case LogStatus.noAppUsage:
        return Colors.grey;
      case LogStatus.belowThreshold:
        return Colors.blue;
      case LogStatus.alarmTriggered:
        return Colors.orange;
      case LogStatus.terminationCompleted:
        return Colors.green;
      case LogStatus.alarmTimedOut:
        return Colors.red;
    }
  }

  IconData _getStatusIcon(LogStatus status) {
    switch (status) {
      case LogStatus.noAppUsage:
        return Icons.check_circle;
      case LogStatus.belowThreshold:
        return Icons.check;
      case LogStatus.alarmTriggered:
        return Icons.alarm;
      case LogStatus.terminationCompleted:
        return Icons.done_all;
      case LogStatus.alarmTimedOut:
        return Icons.alarm_off;
    }
  }

  String _getStatusLabel(LogStatus status) {
    switch (status) {
      case LogStatus.noAppUsage:
        return 'No Usage';
      case LogStatus.belowThreshold:
        return 'Below Threshold';
      case LogStatus.alarmTriggered:
        return 'Alarm';
      case LogStatus.terminationCompleted:
        return 'Completed';
      case LogStatus.alarmTimedOut:
        return 'Timeout';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }
}
