import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/tool_type.dart';
import '../providers/canvas_settings_provider.dart';
import '../providers/drawing_provider.dart';
import '../providers/save_provider.dart';
import '../utils/canvas_bounds.dart';
import '../utils/flood_fill.dart';
import 'canvas_painter.dart';

import '../save_io.dart' if (dart.library.html) '../save_web.dart' as save_impl;

class DrawingCanvas extends ConsumerStatefulWidget {
  const DrawingCanvas({super.key, this.isGestureActive = false});

  final bool isGestureActive;

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends ConsumerState<DrawingCanvas> {
  final GlobalKey _repaintBoundaryKey = GlobalKey();
  bool _isProcessingFill = false;

  /// Set by MouseRegion on pointer devices — always tracks cursor position.
  Offset? _hoverPosition;

  /// Set during active pan gesture — used on touch devices to show indicator
  /// only while drawing.
  Offset? _panPosition;

  /// True while a draw gesture is in progress (brush, shapes, etc.). Hides the
  /// brush preview ring: mouse hover stops updating during drag, which would
  /// otherwise leave the ring stuck at the stroke start.
  bool _paintGestureActive = false;

  Future<void> _captureAndSave() async {
    final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    await save_impl.saveToStorage(byteData.buffer.asUint8List());
  }

  Future<void> _performFill(Offset localPosition, Size canvasSize) async {
    if (_isProcessingFill) return;
    _isProcessingFill = true;

    try {
      final boundary = _repaintBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 1.0);
      final clamped = clampToCanvas(localPosition, canvasSize);
      final filledImage = await floodFill(
        image: image,
        seedPoint: clamped,
        fillColor: ref.read(drawingProvider).currentColor,
        tolerance: 25,
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
  void didUpdateWidget(DrawingCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isGestureActive && !oldWidget.isGestureActive) {
      // Cannot modify Riverpod state during didUpdateWidget — defer until after build.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(drawingProvider.notifier).clearPreview();
      });
      setState(() {
        _panPosition = null;
        _paintGestureActive = false;
      });
    }
  }

  Widget _buildCursorIndicator(DrawingState state, Offset position) {
    double radius;
    bool isEraser;

    switch (state.currentTool) {
      case ToolType.brush:
        radius = state.brushStrokeWidth / 2;
        isEraser = false;
        break;
      case ToolType.eraser:
        // Eraser stroke width is 2× brush width, so indicator matches that.
        radius = state.brushStrokeWidth;
        isEraser = true;
        break;
      case ToolType.spray:
        radius = state.spraySize;
        isEraser = false;
        break;
      default:
        return const SizedBox.shrink();
    }

    radius = radius.clamp(3.0, 200.0);
    final diameter = radius * 2;

    return Positioned(
      left: position.dx - radius,
      top: position.dy - radius,
      child: IgnorePointer(
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: CustomPaint(
            painter: _CursorIndicatorPainter(
              color: state.currentColor,
              dashed: isEraser,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(drawingProvider);
    final notifier = ref.read(drawingProvider.notifier);
    final canvasSettings = ref.watch(canvasSettingsProvider);
    final canvasSize = Size(canvasSettings.width, canvasSettings.height);

    // On pointer devices MouseRegion fires, giving a persistent position.
    // On touch-only devices _hoverPosition stays null so we fall back to
    // _panPosition, which is only set during an active gesture.
    // Hide the ring while drawing: hover does not track during mouse drag.
    final indicatorPosition =
        _paintGestureActive ? null : (_hoverPosition ?? _panPosition);

    return SizedBox(
      width: canvasSize.width,
      height: canvasSize.height,
      child: MouseRegion(
        onHover: (e) => setState(() => _hoverPosition =
            clampToCanvas(e.localPosition, canvasSize)),
        onExit: (_) => setState(() => _hoverPosition = null),
        child: Stack(
          children: [
            GestureDetector(
              onTapDown: (details) {
                if (widget.isGestureActive) return;
                if (state.currentTool == ToolType.fill) {
                  _performFill(details.localPosition, canvasSize);
                }
              },
              onPanStart: (details) {
                if (widget.isGestureActive) return;
                if (state.currentTool == ToolType.fill) {
                  _performFill(details.localPosition, canvasSize);
                } else {
                  final start =
                      clampToCanvas(details.localPosition, canvasSize);
                  notifier.onPanStart(start);
                  setState(() {
                    _paintGestureActive = true;
                    _panPosition = start;
                  });
                }
              },
              onPanUpdate: (details) {
                if (widget.isGestureActive) return;
                if (state.currentTool != ToolType.fill) {
                  final p = clampToCanvas(details.localPosition, canvasSize);
                  notifier.onPanUpdate(p);
                  setState(() => _panPosition = p);
                }
              },
              onPanEnd: (details) {
                if (widget.isGestureActive) return;
                if (state.currentTool != ToolType.fill) {
                  notifier.onPanEnd(canvasSize);
                }
                setState(() {
                  _paintGestureActive = false;
                  _panPosition = null;
                });
              },
              onPanCancel: () {
                if (widget.isGestureActive) return;
                notifier.clearPreview();
                setState(() {
                  _paintGestureActive = false;
                  _panPosition = null;
                });
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
                  size: canvasSize,
                ),
              ),
            ),
            if (indicatorPosition != null)
              _buildCursorIndicator(state, indicatorPosition),
          ],
        ),
      ),
    );
  }
}

/// Draws a circle outline with a thin contrasting outer ring for visibility
/// on any background color.
class _CursorIndicatorPainter extends CustomPainter {
  const _CursorIndicatorPainter({required this.color, required this.dashed});

  final Color color;
  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Outer contrast ring so the indicator is always visible.
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.4)
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..isAntiAlias = true,
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    if (dashed) {
      const dashCount = 16;
      const dashAngle = 2 * pi / dashCount;
      for (var i = 0; i < dashCount; i += 2) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * dashAngle,
          dashAngle,
          false,
          paint,
        );
      }
    } else {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_CursorIndicatorPainter old) =>
      old.color != color || old.dashed != dashed;
}
