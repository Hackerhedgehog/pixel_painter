import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_type.dart';
import '../providers/drawing_provider.dart';
import '../providers/save_provider.dart';
import '../utils/flood_fill.dart';
import 'canvas_painter.dart';

// Conditional imports for platform-specific save
import '../save_io.dart' if (dart.library.html) '../save_web.dart' as save_impl;

/// The main drawing canvas widget.
class DrawingCanvas extends ConsumerStatefulWidget {
  const DrawingCanvas({super.key});

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isProcessingFill = false;

  Future<void> _captureAndSave() async {
    final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    await save_impl.saveToStorage(byteData.buffer.asUint8List());
  }

  Future<void> _performFill(Offset localPosition) async {
    if (_isProcessingFill) return;
    _isProcessingFill = true;

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final filledImage = await floodFill(
        image: image,
        seedPoint: localPosition * 3.0,
        fillColor: ref.read(drawingProvider).currentColor,
      );

      if (mounted) {
        ref.read(drawingProvider.notifier).addFillAction(filledImage);
      }
    } catch (e) {
      debugPrint('Fill error: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingFill = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(saveCallbackProvider.notifier).state = _captureAndSave;
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);

    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onPanStart: (details) {
            if (state.currentTool == ToolType.fill) {
              _performFill(details.localPosition);
            } else {
              notifier.onPanStart(details.localPosition);
            }
          },
          onPanUpdate: (details) {
            if (state.currentTool != ToolType.fill) {
              notifier.onPanUpdate(details.localPosition);
            }
          },
          onPanEnd: (details) {
            if (state.currentTool != ToolType.fill) {
              notifier.onPanEnd(constraints.biggest);
            }
          },
          onPanCancel: () {
            notifier.clearPreview();
          },
          child: RepaintBoundary(
            key: _repaintBoundaryKey,
            child: CustomPaint(
              painter: CanvasPainter(
                actions: state.actions,
                previewPoints: state.previewPoints,
                previewStart: state.previewStart,
                previewEnd: state.previewEnd,
                currentTool: state.currentTool,
                currentColor: state.currentColor,
                brushStrokeWidth: state.brushStrokeWidth,
                shapeStrokeWidth: state.shapeStrokeWidth,
                spraySize: state.spraySize,
              ),
              size: constraints.biggest,
            ),
          ),
        );
      },
    );
  }
}
