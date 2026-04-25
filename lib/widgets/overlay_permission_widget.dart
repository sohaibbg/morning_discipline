import 'package:flutter/material.dart';
import '../services/countdown_overlay_service.dart';
import '../dependency_injection.dart';

class OverlayPermissionWidget extends StatefulWidget {
  final ValueChanged<bool> onPermissionChanged;

  const OverlayPermissionWidget({
    super.key,
    required this.onPermissionChanged,
  });

  @override
  State<OverlayPermissionWidget> createState() => _OverlayPermissionWidgetState();
}

class _OverlayPermissionWidgetState extends State<OverlayPermissionWidget> {
  final _overlayService = getIt<CountdownOverlayService>();

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final hasPermission = await _overlayService.hasOverlayPermission();
    widget.onPermissionChanged(hasPermission);
  }

  Future<void> _requestPermission() async {
    await _overlayService.requestOverlayPermission();
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Overlay Permission Required',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'To show countdown overlays on monitored apps, overlay permission is needed.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _requestPermission,
            icon: const Icon(Icons.launch),
            label: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }
}
