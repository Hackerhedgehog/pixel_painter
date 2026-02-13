import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Base class for all drawing actions. Each action represents a single
/// user operation that can be painted and undone.
abstract class DrawAction {
  void paint(Canvas canvas, Size size);
}

/// Brush stroke - freehand drawing with points.
class BrushAction extends DrawAction {
  BrushAction({
    required this.points,
    required this.color,
    required this.strokeWidth,
  });

  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPoints(ui.PointMode.polygon, points, paint);
  }
}

/// Straight line shape.
class LineAction extends DrawAction {
  LineAction({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawLine(start, end, paint);
  }
}

/// Rectangle shape.
class RectangleAction extends DrawAction {
  RectangleAction({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawRect(rect, paint);
  }
}

/// Ellipse shape.
class EllipseAction extends DrawAction {
  EllipseAction({
    required this.start,
    required this.end,
    required this.color,
    required this.strokeWidth,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(start, end);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawOval(rect, paint);
  }
}

/// Spray/airbrush stroke - multiple random points.
class SprayAction extends DrawAction {
  SprayAction({
    required this.points,
    required this.color,
    required this.spraySize,
  });

  final List<Offset> points;
  final Color color;
  final double spraySize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    for (final point in points) {
      canvas.drawCircle(point, 1, paint);
    }
  }
}

/// Eraser stroke - draws with canvas default (white) color.
class EraserAction extends DrawAction {
  EraserAction({
    required this.points,
    required this.strokeWidth,
    required this.canvasColor,
  });

  final List<Offset> points;
  final double strokeWidth;
  final Color canvasColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final paint = Paint()
      ..color = canvasColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;
    canvas.drawPoints(ui.PointMode.polygon, points, paint);
  }
}

/// Fill action - draws a pre-rendered filled region as image.
class FillAction extends DrawAction {
  FillAction({required this.image});

  final ui.Image image;

  @override
  void paint(Canvas canvas, Size size) {
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, Paint());
  }
}
