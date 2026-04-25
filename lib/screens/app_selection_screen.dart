import 'package:flutter/material.dart';
import '../services/app_monitoring_service.dart';

class AppSelectionScreen extends StatefulWidget {
  final List<String> initialSelection;

  const AppSelectionScreen({
    super.key,
    required this.initialSelection,
  });

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<Application> _allApps = [];
  List<Application> _filteredApps = [];
  Set<String> _selectedPackages = {};
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedPackages = Set.from(widget.initialSelection);
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);

    try {
      final apps = await AppMonitoringService().getInstalledApps();
      setState(() {
        _allApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading apps: $e')),
        );
      }
    }
  }

  void _filterApps(String query) {
    if (query.isEmpty) {
      setState(() => _filteredApps = _allApps);
      return;
    }

    setState(() {
      _filteredApps = _allApps.where((app) {
        return app.appName.toLowerCase().contains(query.toLowerCase()) ||
            app.packageName.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  void _toggleSelection(String packageName) {
    setState(() {
      if (_selectedPackages.contains(packageName)) {
        _selectedPackages.remove(packageName);
      } else {
        _selectedPackages.add(packageName);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPackages = Set.from(_filteredApps.map((app) => app.packageName));
    });
  }

  void _clearAll() {
    setState(() {
      _selectedPackages.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Apps'),
        actions: [
          if (_selectedPackages.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context, _selectedPackages.toList());
              },
              child: Text(
                'Done (${_selectedPackages.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search apps...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterApps('');
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: _filterApps,
            ),
          ),

          // Action buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: _selectAll,
                  icon: const Icon(Icons.select_all),
                  label: const Text('Select All'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Clear All'),
                ),
                const Spacer(),
                Text(
                  '${_selectedPackages.length} selected',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          const Divider(),

          // Apps list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'No apps found'
                              : 'No apps match your search',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredApps.length,
                        itemBuilder: (context, index) {
                          final app = _filteredApps[index];
                          final isSelected = _selectedPackages.contains(app.packageName);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (_) => _toggleSelection(app.packageName),
                            title: Text(app.appName),
                            subtitle: Text(
                              app.packageName,
                              style: const TextStyle(fontSize: 12),
                            ),
                            secondary: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: Colors.primaries[
                                    app.appName.hashCode % Colors.primaries.length],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Text(
                                  app.appName[0].toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 20,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: _selectedPackages.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.pop(context, _selectedPackages.toList());
              },
              icon: const Icon(Icons.check),
              label: Text('Confirm (${_selectedPackages.length})'),
            )
          : null,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
