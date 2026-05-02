import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_type.dart';
import '../providers/drawing_provider.dart';

/// Bottom bar: tool selection only.
class ToolPanel extends ConsumerWidget {
  const ToolPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        child: Row(
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
