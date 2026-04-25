import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import '../models/discipline_rule.dart';
import '../providers/rules_provider.dart';
import '../services/app_monitoring_service.dart';
import '../dependency_injection.dart';
import 'app_selection_screen.dart';
import 'movement_test_screen.dart';

class RuleEditScreen extends ConsumerStatefulWidget {
  final DisciplineRule? rule;

  const RuleEditScreen({super.key, this.rule});

  @override
  ConsumerState<RuleEditScreen> createState() => _RuleEditScreenState();
}

class _RuleEditScreenState extends ConsumerState<RuleEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _labelController;
  late TextEditingController _thresholdController;
  late TextEditingController _maxAlarmController;
  late TextEditingController _stepsController;
  late TextEditingController _movementController;

  // Focus nodes for sequential navigation
  final _labelFocusNode = FocusNode();
  final _thresholdFocusNode = FocusNode();
  final _maxAlarmFocusNode = FocusNode();
  final _stepsFocusNode = FocusNode();
  final _movementFocusNode = FocusNode();

  late List<String> _selectedApps;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late int _thresholdMinutes;
  late int _maxAlarmMinutes;
  String? _alarmSoundUri;
  String? _alarmSoundTitle;
  late TerminationType _terminationType;
  late int _requiredSteps;
  late double _requiredMovement;

  Map<String, String> _appNamesCache = {};
  bool _loadingAppNames = false;

  static const platform = MethodChannel('com.example.morning_discipline/usage');

  @override
  void initState() {
    super.initState();
    _initializeFields();
    // Defer app name loading to avoid blocking UI
    if (_selectedApps.isNotEmpty) {
      Future.microtask(() {
        if (mounted) {
          _loadAppNames();
        }
      });
    }
  }

  void _initializeFields() {
    final rule = widget.rule;
    _labelController = TextEditingController(text: rule?.label ?? '');
    _selectedApps = rule?.monitoredApps ?? [];
    _startTime = rule != null
        ? TimeOfDay.fromDateTime(rule.monitoringWindow.startTime)
        : const TimeOfDay(hour: 6, minute: 0);
    _endTime = rule != null
        ? TimeOfDay.fromDateTime(rule.monitoringWindow.endTime)
        : const TimeOfDay(hour: 12, minute: 0);
    _thresholdMinutes = rule?.thresholdDuration.inMinutes ?? 30;
    _maxAlarmMinutes = rule?.maxAlarmDuration.inMinutes ?? 10;

    // Initialize text controllers with values
    _thresholdController = TextEditingController(
      text: _thresholdMinutes.toString(),
    );
    _maxAlarmController = TextEditingController(
      text: _maxAlarmMinutes.toString(),
    );
    _requiredSteps =
        rule?.terminationMechanism.maybeWhen(
          steps: (steps) => steps,
          orElse: () => 100,
        ) ??
        100;
    _requiredMovement =
        rule?.terminationMechanism.maybeWhen(
          movement: (movement) => movement,
          orElse: () => 500.0,
        ) ??
        500.0;
    _stepsController = TextEditingController(text: _requiredSteps.toString());
    _movementController = TextEditingController(
      text: _requiredMovement.toString(),
    );

    _alarmSoundUri = rule?.alarmSound;
    _alarmSoundTitle = rule?.alarmSoundTitle;
    if (_alarmSoundUri != null && _alarmSoundUri != 'default' && _alarmSoundTitle == null) {
      _alarmSoundTitle = 'Custom Sound';
    }
    _terminationType =
        rule?.terminationMechanism.maybeWhen(
          steps: (_) => TerminationType.steps,
          orElse: () => TerminationType.movement,
        ) ??
        TerminationType.steps;
  }

  Future<void> _loadAppNames() async {
    if (_selectedApps.isEmpty) return;

    setState(() => _loadingAppNames = true);

    try {
      final appMonitor = getIt<AppMonitoringService>();
      final allApps = await appMonitor.getInstalledApps();

      final names = <String, String>{};
      final selectedSet = _selectedApps.toSet();

      for (final app in allApps) {
        if (!selectedSet.contains(app.packageName)) continue;
        names[app.packageName] = app.appName;

        // Early exit if we found all selected apps
        if (names.length == _selectedApps.length) break;
      }

      if (!mounted) return;

      setState(() {
        _appNamesCache = names;
        _loadingAppNames = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAppNames = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.rule == null ? 'New Rule' : 'Edit Rule'),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveRule),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Label
            TextFormField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Rule Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a rule name';
                }
                return null;
              },
            ),

            const SizedBox(height: 24),

            // Time Window
            _buildTimeWindowCard(),

            const SizedBox(height: 16),

            // Durations
            _buildDurationsCard(),

            const SizedBox(height: 16),

            // Alarm Sound
            _buildAlarmSoundCard(),

            const SizedBox(height: 16),

            // Termination Mechanism
            _buildTerminationCard(),

            const SizedBox(height: 16),

            // Monitored Apps Section (at bottom)
            _buildMonitoredAppsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildMonitoredAppsCard() {
    final cardHeader = Row(
      children: [
        const Icon(Icons.apps, size: 20),
        const SizedBox(width: 8),
        const Text(
          'Monitored Apps',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );

    final emptyState = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey.shade600),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'No apps selected. Tap the button below to choose apps to monitor.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );

    final selectedAppsDisplay = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blue,
                radius: 12,
                child: Text(
                  '${_selectedApps.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_selectedApps.length} app${_selectedApps.length == 1 ? '' : 's'} selected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _buildAppNamesSentence(),
        ],
      ),
    );

    final selectButton = SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _openAppSelection,
        icon: Icon(_selectedApps.isEmpty ? Icons.add : Icons.edit),
        label: Text(_selectedApps.isEmpty ? 'Select Apps' : 'Edit Apps'),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardHeader,
            const SizedBox(height: 12),
            _selectedApps.isEmpty ? emptyState : selectedAppsDisplay,
            const SizedBox(height: 12),
            selectButton,
          ],
        ),
      ),
    );
  }

  Widget _buildAppNamesSentence() {
    if (_loadingAppNames) {
      return const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading app names...'),
        ],
      );
    }

    final appNames = _selectedApps.map((packageName) {
      return _appNamesCache[packageName] ?? packageName.split('.').last;
    }).toList();

    final sentence = switch (appNames.length) {
      1 => appNames[0],
      2 => '${appNames[0]} and ${appNames[1]}',
      _ => () {
        final lastApp = appNames.removeLast();
        return '${appNames.join(', ')}, and $lastApp';
      }(),
    };

    return Text(
      sentence,
      style: TextStyle(color: Colors.blue.shade900, fontSize: 14),
    );
  }

  Widget _buildTimeWindowCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.schedule, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Monitoring Window',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTimeButton(
                    label: 'Start Time',
                    time: _startTime,
                    onTap: () => _selectTime(context, true),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTimeButton(
                    label: 'End Time',
                    time: _endTime,
                    onTap: () => _selectTime(context, false),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeButton({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              time.format(context),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.timer, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Durations',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _thresholdController,
              focusNode: _thresholdFocusNode,
              decoration: const InputDecoration(
                labelText: 'Usage Threshold (minutes)',
                helperText: 'Alarm triggers when app usage exceeds this',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: (value) {
                _thresholdMinutes = int.tryParse(value) ?? 30;
              },
              onEditingComplete: () {
                _maxAlarmFocusNode.requestFocus();
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _maxAlarmController,
              focusNode: _maxAlarmFocusNode,
              decoration: const InputDecoration(
                labelText: 'Max Alarm Duration (minutes)',
                helperText: 'Alarm stops ringing after this time',
                border: OutlineInputBorder(),
                suffixText: 'min',
              ),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              onChanged: (value) {
                _maxAlarmMinutes = int.tryParse(value) ?? 10;
              },
              onEditingComplete: () {
                _maxAlarmFocusNode.unfocus();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTerminationCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final cardHeader = Row(
      children: [
        const Icon(Icons.directions_walk, size: 20),
        const SizedBox(width: 8),
        const Text(
          'Stop Alarm By',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );

    final segmentedControl = Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              label: 'Walking Steps',
              icon: Icons.directions_walk,
              isSelected: _terminationType == TerminationType.steps,
              onTap: () =>
                  setState(() => _terminationType = TerminationType.steps),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              label: 'Movement',
              icon: Icons.motion_photos_on,
              isSelected: _terminationType == TerminationType.movement,
              onTap: () =>
                  setState(() => _terminationType = TerminationType.movement),
            ),
          ),
        ],
      ),
    );

    final stepsInput = TextFormField(
      controller: _stepsController,
      focusNode: _stepsFocusNode,
      decoration: const InputDecoration(
        labelText: 'Required Steps',
        helperText: 'Number of steps to stop the alarm',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.directions_walk),
        suffixText: 'steps',
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onChanged: (value) => _requiredSteps = int.tryParse(value) ?? 100,
    );

    final movementInput = TextFormField(
      controller: _movementController,
      focusNode: _movementFocusNode,
      decoration: const InputDecoration(
        labelText: 'Required Movement',
        helperText: 'Movement amount to stop the alarm',
        border: OutlineInputBorder(),
        prefixIcon: Icon(Icons.motion_photos_on),
        suffixText: 'units',
      ),
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.done,
      onChanged: (value) => _requiredMovement = double.tryParse(value) ?? 500.0,
    );

    final testButton = OutlinedButton.icon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const MovementTestScreen()),
        );
      },
      icon: const Icon(Icons.science),
      label: const Text('Test Detection Sensitivity'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
      ),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cardHeader,
            const SizedBox(height: 12),
            segmentedControl,
            const SizedBox(height: 16),
            _terminationType == TerminationType.steps
                ? stepsInput
                : movementInput,
            const SizedBox(height: 16),
            testButton,
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isSelected ? colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected
                  ? colorScheme.onPrimary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmSoundCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Alarm Sound',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickAlarmSound,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.volume_up,
                        color: Colors.orange.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _alarmSoundTitle ?? 'Default Alarm',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Tap to change',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openAppSelection() async {
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AppSelectionScreen(initialSelection: _selectedApps),
      ),
    );

    if (result == null) return;

    setState(() {
      _selectedApps = result;
    });
    _loadAppNames();

    // Auto-focus start time after returning from app selection
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _selectTime(context, true);
    });
  }

  Future<void> _selectTime(BuildContext context, bool isStart) async {
    final time = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );

    if (time == null || !mounted) return;

    setState(() {
      if (isStart) {
        _startTime = time;
      } else {
        _endTime = time;
      }
    });

    // Auto-navigate to end time if setting start time
    if (isStart) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _selectTime(context, false);
      });
      return;
    }

    // Auto-focus threshold duration after setting end time
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _thresholdFocusNode.requestFocus();
    });
  }

  Future<void> _pickAlarmSound() async {
    try {
      final result = await platform.invokeMethod('pickAlarmSound');
      if (result == null || !mounted) return;

      setState(() {
        _alarmSoundUri = result['uri'];
        _alarmSoundTitle = result['title'] ?? 'Custom Sound';
      });
    } on PlatformException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
    }
  }

  void _saveRule() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedApps.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one app')),
      );
      return;
    }

    final now = DateTime.now();
    final startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _startTime.hour,
      _startTime.minute,
    );
    final endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _endTime.hour,
      _endTime.minute,
    );

    final rule = DisciplineRule(
      id: widget.rule?.id ?? const Uuid().v4(),
      label: _labelController.text,
      monitoredApps: _selectedApps,
      monitoringWindow: TimeWindow(
        startTime: startDateTime,
        endTime: endDateTime,
      ),
      thresholdDuration: Duration(minutes: _thresholdMinutes),
      maxAlarmDuration: Duration(minutes: _maxAlarmMinutes),
      alarmSound: _alarmSoundUri ?? 'default',
      alarmSoundTitle: _alarmSoundTitle,
      terminationMechanism: _terminationType == TerminationType.steps
          ? TerminationMechanism.steps(requiredSteps: _requiredSteps)
          : TerminationMechanism.movement(requiredMovement: _requiredMovement),
      isEnabled: widget.rule?.isEnabled ?? true,
    );

    if (widget.rule == null) {
      ref.read(rulesProvider.notifier).addRule(rule);
    } else {
      ref.read(rulesProvider.notifier).updateRule(rule);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          widget.rule == null
              ? 'Rule created successfully'
              : 'Rule updated successfully',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    _thresholdController.dispose();
    _maxAlarmController.dispose();
    _stepsController.dispose();
    _movementController.dispose();
    _labelFocusNode.dispose();
    _thresholdFocusNode.dispose();
    _maxAlarmFocusNode.dispose();
    _stepsFocusNode.dispose();
    _movementFocusNode.dispose();
    super.dispose();
  }
}

enum TerminationType { steps, movement }
