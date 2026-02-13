import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_type.dart';
import '../providers/drawing_provider.dart';
import '../providers/save_provider.dart';

/// Tool selection and settings panel.
class ToolPanel extends ConsumerWidget {
  const ToolPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return Container(
      height: 200,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolRow(
              children: [
                _UndoSaveRow(
                  notifier: notifier,
                  state: state,
                  onSave: ref.read(saveCallbackProvider),
                ),
                const Spacer(),
                _ColorButton(
                  color: state.currentColor,
                  onTap: () => _showColorPicker(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _ToolRow(
              children: [
                _ToolButton(
                  icon: Icons.brush,
                  label: 'Brush',
                  isSelected: state.currentTool == ToolType.brush,
                  onTap: () => notifier.setTool(ToolType.brush),
                ),
                _ToolButton(
                  icon: Icons.horizontal_rule,
                  label: 'Line',
                  isSelected: state.currentTool == ToolType.line,
                  onTap: () => notifier.setTool(ToolType.line),
                ),
                _ToolButton(
                  icon: Icons.crop_square,
                  label: 'Rect',
                  isSelected: state.currentTool == ToolType.rectangle,
                  onTap: () => notifier.setTool(ToolType.rectangle),
                ),
                _ToolButton(
                  icon: Icons.panorama_fish_eye,
                  label: 'Ellipse',
                  isSelected: state.currentTool == ToolType.ellipse,
                  onTap: () => notifier.setTool(ToolType.ellipse),
                ),
                _ToolButton(
                  icon: Icons.format_paint,
                  label: 'Fill',
                  isSelected: state.currentTool == ToolType.fill,
                  onTap: () => notifier.setTool(ToolType.fill),
                ),
                _ToolButton(
                  icon: Icons.blur_on,
                  label: 'Spray',
                  isSelected: state.currentTool == ToolType.spray,
                  onTap: () => notifier.setTool(ToolType.spray),
                ),
                _ToolButton(
                  icon: Icons.auto_fix_high,
                  label: 'Eraser',
                  isSelected: state.currentTool == ToolType.eraser,
                  onTap: () => notifier.setTool(ToolType.eraser),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 40,
              child: _buildSizeSelector(state, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSizeSelector(DrawingState state, DrawingNotifier notifier) {
    if (state.currentTool == ToolType.brush || state.currentTool == ToolType.eraser) {
      return _SizeSelector(
        label: 'Brush size',
        value: state.brushStrokeWidth,
        options: const [4.0, 12.0],
        onChanged: notifier.setBrushStrokeWidth,
      );
    }
    if (state.currentTool == ToolType.line) {
      return _SizeSelector(
        label: 'Outline',
        value: state.shapeStrokeWidth,
        options: const [2.0, 6.0],
        onChanged: notifier.setShapeStrokeWidth,
      );
    }
    if (state.currentTool == ToolType.rectangle ||
        state.currentTool == ToolType.ellipse) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SizeSelector(
            label: 'Outline',
            value: state.shapeStrokeWidth,
            options: const [2.0, 6.0],
            onChanged: notifier.setShapeStrokeWidth,
          ),
          const SizedBox(width: 16),
          _LockAspectToggle(
            value: state.lockAspectRatio,
            onChanged: notifier.setLockAspectRatio,
          ),
        ],
      );
    }
    if (state.currentTool == ToolType.spray) {
      return _SizeSelector(
        label: 'Spray size',
        value: state.spraySize,
        options: const [8.0, 24.0],
        onChanged: notifier.setSpraySize,
      );
    }
    return const SizedBox.shrink();
  }

  void _showColorPicker(BuildContext context, WidgetRef ref) {
    final state = ref.read(drawingProvider);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pick a color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: state.currentColor,
            onColorChanged: (color) {
              ref.read(drawingProvider.notifier).setColor(color);
            },
            availableColors: const [
              Colors.black,
              Colors.white,
              Colors.red,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.lightBlue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lightGreen,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.grey,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: children,
    );
  }
}

class _UndoSaveRow extends StatelessWidget {
  const _UndoSaveRow({
    required this.notifier,
    required this.state,
    required this.onSave,
  });

  final DrawingNotifier notifier;
  final DrawingState state;
  final Future<void> Function()? onSave;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: state.undoHistory.isEmpty
              ? null
              : () => notifier.undo(),
          tooltip: 'Undo',
        ),
        IconButton(
          icon: const Icon(Icons.save),
          onPressed: onSave == null
              ? null
              : () async {
                  await onSave!();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          kIsWeb
                              ? 'Drawing downloaded'
                              : 'Drawing saved',
                        ),
                      ),
                    );
                  }
                },
          tooltip: 'Save',
        ),
      ],
    );
  }
}

class _ColorButton extends StatelessWidget {
  const _ColorButton({
    required this.color,
    required this.onTap,
  });

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade400, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 24),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeSelector extends StatelessWidget {
  const _SizeSelector({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final double value;
  final List<double> options;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ', style: Theme.of(context).textTheme.bodySmall),
        ...options.map((size) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(size.toInt().toString()),
                selected: (value - size).abs() < 0.5,
                onSelected: (_) => onChanged(size),
              ),
            )),
      ],
    );
  }
}

class _LockAspectToggle extends StatelessWidget {
  const _LockAspectToggle({
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: value
          ? Theme.of(context).colorScheme.primaryContainer
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.lock : Icons.lock_open,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                '1:1',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
