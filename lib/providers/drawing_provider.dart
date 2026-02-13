import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/draw_action.dart';
import '../models/tool_type.dart';

/// Maximum undo steps to keep in history.
const int maxUndoSteps = 5;

/// Canvas default (background) color.
const Color canvasColor = Colors.white;

/// Drawing state - actions, tool settings, and preview.
class DrawingState {
  const DrawingState({
    this.actions = const [],
    this.undoHistory = const [],
    this.currentTool = ToolType.brush,
    this.currentColor = Colors.black,
    this.brushStrokeWidth = 4,
    this.shapeStrokeWidth = 2,
    this.spraySize = 10,
    this.previewPoints = const [],
    this.previewStart,
    this.previewEnd,
  });

  final List<DrawAction> actions;
  final List<List<DrawAction>> undoHistory;
  final ToolType currentTool;
  final Color currentColor;
  final double brushStrokeWidth;
  final double shapeStrokeWidth;
  final double spraySize;
  final List<Offset> previewPoints;
  final Offset? previewStart;
  final Offset? previewEnd;

  DrawingState copyWith({
    List<DrawAction>? actions,
    List<List<DrawAction>>? undoHistory,
    ToolType? currentTool,
    Color? currentColor,
    double? brushStrokeWidth,
    double? shapeStrokeWidth,
    double? spraySize,
    List<Offset>? previewPoints,
    Offset? previewStart,
    Offset? previewEnd,
  }) {
    return DrawingState(
      actions: actions ?? this.actions,
      undoHistory: undoHistory ?? this.undoHistory,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      brushStrokeWidth: brushStrokeWidth ?? this.brushStrokeWidth,
      shapeStrokeWidth: shapeStrokeWidth ?? this.shapeStrokeWidth,
      spraySize: spraySize ?? this.spraySize,
      previewPoints: previewPoints ?? this.previewPoints,
      previewStart: previewStart ?? this.previewStart,
      previewEnd: previewEnd ?? this.previewEnd,
    );
  }
}

/// Notifier for drawing state.
class DrawingNotifier extends StateNotifier<DrawingState> {
  DrawingNotifier() : super(const DrawingState());

  void setTool(ToolType tool) {
    state = state.copyWith(
      currentTool: tool,
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }

  void setColor(Color color) {
    state = state.copyWith(currentColor: color);
  }

  void setBrushStrokeWidth(double width) {
    state = state.copyWith(brushStrokeWidth: width);
  }

  void setShapeStrokeWidth(double width) {
    state = state.copyWith(shapeStrokeWidth: width);
  }

  void setSpraySize(double size) {
    state = state.copyWith(spraySize: size);
  }

  void _pushUndo() {
    final newHistory = [
      List<DrawAction>.from(state.actions),
      ...state.undoHistory,
    ];
    state = state.copyWith(
      undoHistory: newHistory.take(maxUndoSteps).toList(),
    );
  }

  void addAction(DrawAction action) {
    _pushUndo();
    state = state.copyWith(
      actions: [...state.actions, action],
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }

  void onPanStart(Offset point) {
    state = state.copyWith(
      previewStart: point,
      previewEnd: point,
      previewPoints: [point],
    );
  }

  void onPanUpdate(Offset point) {
    final random = Random();
    switch (state.currentTool) {
      case ToolType.brush:
      case ToolType.eraser:
        state = state.copyWith(
          previewPoints: [...state.previewPoints, point],
        );
        break;
      case ToolType.spray:
        final points = List<Offset>.from(state.previewPoints);
        for (var i = 0; i < 15; i++) {
          final angle = random.nextDouble() * 2 * pi;
          final r = random.nextDouble() * state.spraySize;
          points.add(Offset(
            point.dx + cos(angle) * r,
            point.dy + sin(angle) * r,
          ));
        }
        state = state.copyWith(previewPoints: points);
        break;
      case ToolType.line:
      case ToolType.rectangle:
      case ToolType.ellipse:
        state = state.copyWith(previewEnd: point);
        break;
      case ToolType.fill:
        break;
    }
  }

  void onPanEnd(Size canvasSize) {
    switch (state.currentTool) {
      case ToolType.brush:
        if (state.previewPoints.length >= 2) {
          addAction(BrushAction(
            points: List.from(state.previewPoints),
            color: state.currentColor,
            strokeWidth: state.brushStrokeWidth,
          ));
        }
        break;
      case ToolType.eraser:
        if (state.previewPoints.length >= 2) {
          addAction(EraserAction(
            points: List.from(state.previewPoints),
            strokeWidth: state.brushStrokeWidth * 2,
            canvasColor: canvasColor,
          ));
        }
        break;
      case ToolType.spray:
        if (state.previewPoints.isNotEmpty) {
          addAction(SprayAction(
            points: List.from(state.previewPoints),
            color: state.currentColor,
            spraySize: state.spraySize,
          ));
        }
        break;
      case ToolType.line:
        if (state.previewStart != null && state.previewEnd != null) {
          addAction(LineAction(
            start: state.previewStart!,
            end: state.previewEnd!,
            color: state.currentColor,
            strokeWidth: state.shapeStrokeWidth,
          ));
        }
        break;
      case ToolType.rectangle:
        if (state.previewStart != null && state.previewEnd != null) {
          addAction(RectangleAction(
            start: state.previewStart!,
            end: state.previewEnd!,
            color: state.currentColor,
            strokeWidth: state.shapeStrokeWidth,
          ));
        }
        break;
      case ToolType.ellipse:
        if (state.previewStart != null && state.previewEnd != null) {
          addAction(EllipseAction(
            start: state.previewStart!,
            end: state.previewEnd!,
            color: state.currentColor,
            strokeWidth: state.shapeStrokeWidth,
          ));
        }
        break;
      case ToolType.fill:
        break;
    }
    state = state.copyWith(
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }

  void addFillAction(ui.Image fillImage) {
    addAction(FillAction(image: fillImage));
  }

  void undo() {
    if (state.undoHistory.isEmpty) return;
    final previous = state.undoHistory.first;
    state = state.copyWith(
      actions: previous,
      undoHistory: state.undoHistory.skip(1).toList(),
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }

  void clearPreview() {
    state = state.copyWith(
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }
}

/// Provider for drawing state.
final drawingProvider =
    StateNotifierProvider<DrawingNotifier, DrawingState>((ref) {
  return DrawingNotifier();
});
