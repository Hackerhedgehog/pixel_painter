import 'package:flutter/material.dart';

/// Keeps a point inside the drawable canvas rectangle [0, width] × [0, height].
Offset clampToCanvas(Offset offset, Size canvasSize) {
  return Offset(
    offset.dx.clamp(0.0, canvasSize.width),
    offset.dy.clamp(0.0, canvasSize.height),
  );
}
