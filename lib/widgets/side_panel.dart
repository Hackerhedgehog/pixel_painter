import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/canvas_settings_provider.dart';
import '../providers/drawing_provider.dart';
import '../providers/save_provider.dart';

class SidePanel extends ConsumerStatefulWidget {
  const SidePanel({super.key});

  @override
  ConsumerState<SidePanel> createState() => _SidePanelState();
}

class _SidePanelState extends ConsumerState<SidePanel> {
  late final TextEditingController _widthController;
  late final TextEditingController _heightController;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(canvasSettingsProvider);
    _widthController =
        TextEditingController(text: settings.width.toInt().toString());
    _heightController =
        TextEditingController(text: settings.height.toInt().toString());
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  void _applyWidth(String value) {
    final w = double.tryParse(value);
    if (w != null) ref.read(canvasSettingsProvider.notifier).setWidth(w);
  }

  void _applyHeight(String value) {
    final h = double.tryParse(value);
    if (h != null) ref.read(canvasSettingsProvider.notifier).setHeight(h);
  }

  Future<void> _save() async {
    final onSave = ref.read(saveCallbackProvider);
    if (onSave == null) return;
    await onSave();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(kIsWeb ? 'Drawing downloaded' : 'Drawing saved'),
        ),
      );
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear canvas?'),
        content: const Text(
            'This will erase everything. You can undo afterwards.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed == true) ref.read(drawingProvider.notifier).clearAll();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        border: Border(
          right: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Canvas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _SizeField(
              label: 'Width',
              controller: _widthController,
              onSubmit: _applyWidth,
            ),
            const SizedBox(height: 8),
            _SizeField(
              label: 'Height',
              controller: _heightController,
              onSubmit: _applyHeight,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save'),
                onPressed: _save,
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Clear all'),
                onPressed: _clearAll,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SizeField extends StatefulWidget {
  const _SizeField({
    required this.label,
    required this.controller,
    required this.onSubmit,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  State<_SizeField> createState() => _SizeFieldState();
}

class _SizeFieldState extends State<_SizeField> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus) widget.onSubmit(widget.controller.text);
      });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      decoration: InputDecoration(
        labelText: widget.label,
        isDense: true,
        border: const OutlineInputBorder(),
        suffix: const Text('px'),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onSubmitted: widget.onSubmit,
    );
  }
}
