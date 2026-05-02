import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/draw_action.dart';
import '../models/tool_type.dart';

const int maxUndoSteps = 20;

const Color canvasColor = Colors.white;

class DrawingState {
  const DrawingState({
    this.actions = const [],
    this.undoHistory = const [],
    this.redoHistory = const [],
    this.currentTool = ToolType.brush,
    this.currentColor = Colors.black,
    this.brushStrokeWidth = 4,
    this.shapeStrokeWidth = 2,
    this.spraySize = 10,
    this.lockAspectRatio = false,
    this.previewPoints = const [],
    this.previewStart,
    this.previewEnd,
  });

  final List<DrawAction> actions;
  final List<List<DrawAction>> undoHistory;
  final List<List<DrawAction>> redoHistory;
  final ToolType currentTool;
  final Color currentColor;
  final double brushStrokeWidth;
  final double shapeStrokeWidth;
  final double spraySize;
  final bool lockAspectRatio;
  final List<Offset> previewPoints;
  final Offset? previewStart;
  final Offset? previewEnd;

  // Sentinel so copyWith can distinguish "not provided" from explicit null.
  static const _absent = Object();

  DrawingState copyWith({
    List<DrawAction>? actions,
    List<List<DrawAction>>? undoHistory,
    List<List<DrawAction>>? redoHistory,
    ToolType? currentTool,
    Color? currentColor,
    double? brushStrokeWidth,
    double? shapeStrokeWidth,
    double? spraySize,
    bool? lockAspectRatio,
    List<Offset>? previewPoints,
    Object? previewStart = _absent,
    Object? previewEnd = _absent,
  }) {
    return DrawingState(
      actions: actions ?? this.actions,
      undoHistory: undoHistory ?? this.undoHistory,
      redoHistory: redoHistory ?? this.redoHistory,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      brushStrokeWidth: brushStrokeWidth ?? this.brushStrokeWidth,
      shapeStrokeWidth: shapeStrokeWidth ?? this.shapeStrokeWidth,
      spraySize: spraySize ?? this.spraySize,
      lockAspectRatio: lockAspectRatio ?? this.lockAspectRatio,
      previewPoints: previewPoints ?? this.previewPoints,
      previewStart:
          previewStart == _absent ? this.previewStart : previewStart as Offset?,
      previewEnd:
          previewEnd == _absent ? this.previewEnd : previewEnd as Offset?,
    );
  }
}

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
    state = state.copyWith(
      currentColor: color,
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
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

  void setLockAspectRatio(bool value) {
    state = state.copyWith(lockAspectRatio: value);
  }

  /// Unified UI size 1–100 for brush/eraser stroke, shape outline, or spray radius.
  int get toolSizeDisplayValue {
    switch (state.currentTool) {
      case ToolType.brush:
      case ToolType.eraser:
        return state.brushStrokeWidth.round().clamp(1, 100);
      case ToolType.line:
      case ToolType.rectangle:
      case ToolType.ellipse:
        return state.shapeStrokeWidth.round().clamp(1, 100);
      case ToolType.spray:
        return _sprayToDisplay(state.spraySize);
      case ToolType.fill:
        return 1;
    }
  }

  void setToolSizeFromDisplay(int raw) {
    final v = raw.clamp(1, 100);
    switch (state.currentTool) {
      case ToolType.brush:
      case ToolType.eraser:
        setBrushStrokeWidth(v.toDouble());
        break;
      case ToolType.line:
      case ToolType.rectangle:
      case ToolType.ellipse:
        setShapeStrokeWidth(v.toDouble());
        break;
      case ToolType.spray:
        setSpraySize(_displayToSpray(v));
        break;
      case ToolType.fill:
        break;
    }
  }

  static const double _minSpray = 2;
  static const double _maxSpray = 100;

  int _sprayToDisplay(double spray) {
    final s = spray.clamp(_minSpray, _maxSpray);
    return (1 + (s - _minSpray) / (_maxSpray - _minSpray) * 99).round().clamp(1, 100);
  }

  double _displayToSpray(int display) {
    return _minSpray + (display - 1) / 99 * (_maxSpray - _minSpray);
  }

  Offset _constrainToSquare(Offset start, Offset end) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    if (dx == 0 && dy == 0) return end;
    final size = dx.abs() == 0
        ? dy.abs()
        : (dy.abs() == 0 ? dx.abs() : min(dx.abs(), dy.abs()));
    return Offset(
      start.dx + (dx >= 0 ? size : -size),
      start.dy + (dy >= 0 ? size : -size),
    );
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
      redoHistory: [],
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
        state = state.copyWith(previewEnd: point);
        break;
      case ToolType.rectangle:
      case ToolType.ellipse:
        final constrained = state.lockAspectRatio && state.previewStart != null
            ? _constrainToSquare(state.previewStart!, point)
            : point;
        state = state.copyWith(previewEnd: constrained);
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
          final start = state.previewStart!;
          final end = state.lockAspectRatio
              ? _constrainToSquare(start, state.previewEnd!)
              : state.previewEnd!;
          addAction(RectangleAction(
            start: start,
            end: end,
            color: state.currentColor,
            strokeWidth: state.shapeStrokeWidth,
          ));
        }
        break;
      case ToolType.ellipse:
        if (state.previewStart != null && state.previewEnd != null) {
          final start = state.previewStart!;
          final end = state.lockAspectRatio
              ? _constrainToSquare(start, state.previewEnd!)
              : state.previewEnd!;
          addAction(EllipseAction(
            start: start,
            end: end,
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
    final newRedo = [List<DrawAction>.from(state.actions), ...state.redoHistory]
        .take(maxUndoSteps)
        .toList();
    state = state.copyWith(
      actions: previous,
      undoHistory: state.undoHistory.skip(1).toList(),
      redoHistory: newRedo,
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }

  void redo() {
    if (state.redoHistory.isEmpty) return;
    final next = state.redoHistory.first;
    final newUndo = [List<DrawAction>.from(state.actions), ...state.undoHistory]
        .take(maxUndoSteps)
        .toList();
    state = state.copyWith(
      actions: next,
      undoHistory: newUndo,
      redoHistory: state.redoHistory.skip(1).toList(),
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

  void clearAll() {
    _pushUndo();
    state = state.copyWith(
      actions: [],
      redoHistory: [],
      previewPoints: [],
      previewStart: null,
      previewEnd: null,
    );
  }
}

final drawingProvider =
    StateNotifierProvider<DrawingNotifier, DrawingState>((ref) {
  return DrawingNotifier();
});
