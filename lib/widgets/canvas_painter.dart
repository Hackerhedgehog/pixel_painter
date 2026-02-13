import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/draw_action.dart';
import '../models/tool_type.dart';
import '../providers/drawing_provider.dart';

/// CustomPainter that renders all drawing actions and preview.
class CanvasPainter extends CustomPainter {
  CanvasPainter({
    required this.actions,
    required this.previewPoints,
    required this.previewStart,
    required this.previewEnd,
    required this.currentTool,
    required this.currentColor,
    required this.brushStrokeWidth,
    required this.shapeStrokeWidth,
    required this.spraySize,
  });

  final List<DrawAction> actions;
  final List<Offset> previewPoints;
  final Offset? previewStart;
  final Offset? previewEnd;
  final ToolType currentTool;
  final Color currentColor;
  final double brushStrokeWidth;
  final double shapeStrokeWidth;
  final double spraySize;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = canvasColor,
    );
    for (final action in actions) {
      action.paint(canvas, size);
    }

    _paintPreview(canvas, size);
  }

  void _paintPreview(Canvas canvas, Size size) {
    if (previewStart == null && previewPoints.isEmpty) return;

    switch (currentTool) {
      case ToolType.brush:
        _paintBrushPreview(canvas);
        break;
      case ToolType.eraser:
        _paintEraserPreview(canvas);
        break;
      case ToolType.spray:
        _paintSprayPreview(canvas);
        break;
      case ToolType.line:
        if (previewStart != null && previewEnd != null) {
          _paintLinePreview(canvas);
        }
        break;
      case ToolType.rectangle:
        if (previewStart != null && previewEnd != null) {
          _paintRectPreview(canvas);
        }
        break;
      case ToolType.ellipse:
        if (previewStart != null && previewEnd != null) {
          _paintEllipsePreview(canvas);
        }
        break;
      case ToolType.fill:
        break;
    }
  }

  void _paintBrushPreview(Canvas canvas) {
    if (previewPoints.length < 2) return;
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = brushStrokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPoints(ui.PointMode.polygon, previewPoints, paint);
  }

  void _paintEraserPreview(Canvas canvas) {
    if (previewPoints.length < 2) return;
    final paint = Paint()
      ..color = canvasColor
      ..strokeWidth = brushStrokeWidth * 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPoints(ui.PointMode.polygon, previewPoints, paint);
  }

  void _paintSprayPreview(Canvas canvas) {
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (final point in previewPoints) {
      canvas.drawCircle(point, 1, paint);
    }
  }

  void _paintLinePreview(Canvas canvas) {
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = shapeStrokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawLine(previewStart!, previewEnd!, paint);
  }

  void _paintRectPreview(Canvas canvas) {
    final rect = Rect.fromPoints(previewStart!, previewEnd!);
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = shapeStrokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawRect(rect, paint);
  }

  void _paintEllipsePreview(Canvas canvas) {
    final rect = Rect.fromPoints(previewStart!, previewEnd!);
    final paint = Paint()
      ..color = currentColor
      ..strokeWidth = shapeStrokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawOval(rect, paint);
  }

  @override
  bool shouldRepaint(CanvasPainter oldDelegate) {
    return oldDelegate.actions != actions ||
        oldDelegate.previewPoints != previewPoints ||
        oldDelegate.previewStart != previewStart ||
        oldDelegate.previewEnd != previewEnd ||
        oldDelegate.currentTool != currentTool ||
        oldDelegate.currentColor != currentColor;
  }
}
