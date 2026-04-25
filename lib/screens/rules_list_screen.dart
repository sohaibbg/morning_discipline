import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/discipline_rule.dart';
import '../providers/rules_provider.dart';
import '../widgets/permission_prompt_widget.dart';
import '../widgets/overlay_permission_widget.dart';
import '../widgets/rule_card.dart';
import 'rule_edit_screen.dart';
import 'usage_debug_screen.dart';

class RulesListScreen extends ConsumerStatefulWidget {
  const RulesListScreen({super.key});

  @override
  ConsumerState<RulesListScreen> createState() => _RulesListScreenState();
}

class _RulesListScreenState extends ConsumerState<RulesListScreen> {
  bool _showUsagePermission = false;
  bool _showOverlayPermission = false;

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider);

    final emptyState = const Center(
      child: Text(
        'No rules yet.\nTap + to create one.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );

    final rulesList = ListView.builder(
      itemCount: rules.length,
      itemBuilder: (context, index) {
        final rule = rules[index];
        return RuleCard(
          rule: rule,
          onEdit: () => _navigateToEdit(context, rule),
          onDuplicate: () => _showDuplicateDialog(context, ref, rule),
          onDelete: () => _showDeleteConfirmation(context, ref, rule.id),
        );
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discipline Rules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Debug Usage Stats',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const UsageDebugWidget(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.analytics),
            onPressed: () => Navigator.pushNamed(context, '/dashboard'),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_showUsagePermission)
            PermissionPromptWidget(
              onPermissionChanged: (hasPermission) {
                setState(() => _showUsagePermission = !hasPermission);
              },
            ),
          if (_showOverlayPermission)
            OverlayPermissionWidget(
              onPermissionChanged: (hasPermission) {
                setState(() => _showOverlayPermission = !hasPermission);
              },
            ),
          Expanded(child: rules.isEmpty ? emptyState : rulesList),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const RuleEditScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _navigateToEdit(BuildContext context, DisciplineRule rule) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => RuleEditScreen(rule: rule)),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    String ruleId,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this rule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref.read(rulesProvider.notifier).deleteRule(ruleId);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showDuplicateDialog(
    BuildContext context,
    WidgetRef ref,
    DisciplineRule rule,
  ) {
    final labelController = TextEditingController(text: '${rule.label} (Copy)');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Rule'),
        content: TextField(
          controller: labelController,
          decoration: const InputDecoration(
            labelText: 'New Rule Name',
            hintText: 'Enter a unique name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newLabel = labelController.text.trim();
              if (newLabel.isEmpty) return;

              final duplicatedRule = rule.copyWith(
                id: const Uuid().v4(),
                label: newLabel,
              );

              ref.read(rulesProvider.notifier).addRule(duplicatedRule);
              Navigator.pop(context);

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rule "$newLabel" created'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Duplicate'),
          ),
        ],
      ),
    ).then((_) => labelController.dispose());
  }
}
