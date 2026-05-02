import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_type.dart';
import '../providers/drawing_provider.dart';

/// Tool parameters: undo/redo, color, size slider, shape options.
class TopToolBar extends ConsumerWidget {
  const TopToolBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return Material(
      elevation: 1,
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.undo),
              onPressed: state.undoHistory.isEmpty ? null : notifier.undo,
              tooltip: 'Undo',
            ),
            IconButton(
              icon: const Icon(Icons.redo),
              onPressed: state.redoHistory.isEmpty ? null : notifier.redo,
              tooltip: 'Redo',
            ),
            const SizedBox(width: 4),
            _ColorButton(
              color: state.currentColor,
              onTap: () => _showColorPicker(context, ref),
            ),
            const SizedBox(width: 12),
            if (_showsSizeForTool(state.currentTool)) ...[
              Text(
                'Size',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ToolSizeControl(
                  value: notifier.toolSizeDisplayValue,
                  onChanged: notifier.setToolSizeFromDisplay,
                ),
              ),
            ] else
              const Spacer(),
            if (state.currentTool == ToolType.rectangle ||
                state.currentTool == ToolType.ellipse) ...[
              const SizedBox(width: 8),
              _LockAspectToggle(
                value: state.lockAspectRatio,
                onChanged: notifier.setLockAspectRatio,
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _showsSizeForTool(ToolType tool) {
    switch (tool) {
      case ToolType.fill:
        return false;
      case ToolType.brush:
      case ToolType.line:
      case ToolType.rectangle:
      case ToolType.ellipse:
      case ToolType.spray:
      case ToolType.eraser:
        return true;
    }
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

class _ColorButton extends StatelessWidget {
  const _ColorButton({required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Color',
      child: GestureDetector(
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
      ),
    );
  }
}

class _ToolSizeControl extends StatefulWidget {
  const _ToolSizeControl({
    required this.value,
    required this.onChanged,
  });

  final int value;
  final ValueChanged<int> onChanged;

  @override
  State<_ToolSizeControl> createState() => _ToolSizeControlState();
}

class _ToolSizeControlState extends State<_ToolSizeControl> {
  late final TextEditingController _controller;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.value}');
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitText();
    }
  }

  void _commitText() {
    final parsed = int.tryParse(_controller.text.trim());
    if (parsed != null) {
      widget.onChanged(parsed.clamp(1, 100));
    } else {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void didUpdateWidget(covariant _ToolSizeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
            ),
            child: Slider(
              min: 1,
              max: 100,
              divisions: 99,
              value: widget.value.toDouble().clamp(1, 100),
              label: '${widget.value}',
              onChanged: (v) {
                final i = v.round();
                _controller.text = '$i';
                widget.onChanged(i);
              },
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 56,
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3),
            ],
            decoration: const InputDecoration(
              isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _commitText(),
          ),
        ),
      ],
    );
  }
}

class _LockAspectToggle extends StatelessWidget {
  const _LockAspectToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Lock aspect ratio (1:1)',
      child: Material(
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
                Icon(value ? Icons.lock : Icons.lock_open, size: 20),
                const SizedBox(width: 4),
                Text('1:1', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
