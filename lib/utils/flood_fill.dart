import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Performs flood fill on an image and returns the result as a new [ui.Image].
/// Runs the heavy BFS in a background isolate to avoid freezing the UI.
Future<ui.Image> floodFill({
  required ui.Image image,
  required Offset seedPoint,
  required Color fillColor,
  int tolerance = 5,
}) async {
  final width = image.width;
  final height = image.height;

  final byteData = await image.toByteData(
    format: ui.ImageByteFormat.rawStraightRgba,
  );
  if (byteData == null) throw Exception('Failed to get image bytes');

  final bytes = byteData.buffer.asUint8List();
  final seedX = seedPoint.dx.round().clamp(0, width - 1);
  final seedY = seedPoint.dy.round().clamp(0, height - 1);

  final fillR = (fillColor.r * 255.0).round() & 0xff;
  final fillG = (fillColor.g * 255.0).round() & 0xff;
  final fillB = (fillColor.b * 255.0).round() & 0xff;
  final fillA = (fillColor.a * 255.0).round() & 0xff;

  // Run flood fill in background isolate to avoid blocking UI
  final filled = await compute(
    _floodFillIsolate,
    _FloodFillParams(
      bytes: bytes,
      width: width,
      height: height,
      seedX: seedX,
      seedY: seedY,
      fillR: fillR,
      fillG: fillG,
      fillB: fillB,
      fillA: fillA,
      tolerance: tolerance,
    ),
  );

  if (filled == null) return image; // No change (same color)

  return _createImageFromRgbaBytes(filled, width, height);
}

/// Parameters for isolate - must be simple for compute().
class _FloodFillParams {
  _FloodFillParams({
    required this.bytes,
    required this.width,
    required this.height,
    required this.seedX,
    required this.seedY,
    required this.fillR,
    required this.fillG,
    required this.fillB,
    required this.fillA,
    required this.tolerance,
  });

  final Uint8List bytes;
  final int width;
  final int height;
  final int seedX;
  final int seedY;
  final int fillR;
  final int fillG;
  final int fillB;
  final int fillA;
  final int tolerance;
}

/// Top-level function for compute() - runs in background isolate.
Uint8List? _floodFillIsolate(_FloodFillParams p) {
  final targetR = _getByte(p.bytes, p.width, p.height, p.seedX, p.seedY, 0);
  final targetG = _getByte(p.bytes, p.width, p.height, p.seedX, p.seedY, 1);
  final targetB = _getByte(p.bytes, p.width, p.height, p.seedX, p.seedY, 2);
  final targetA = _getByte(p.bytes, p.width, p.height, p.seedX, p.seedY, 3);

  if (_colorsMatch(
    targetR,
    targetG,
    targetB,
    targetA,
    p.fillR,
    p.fillG,
    p.fillB,
    p.fillA,
    p.tolerance,
  )) {
    return null;
  }

  final filled = Uint8List.fromList(p.bytes);
  final queue = Queue<int>();
  final visited = Uint8List(p.width * p.height);

  final seedIndex = p.seedY * p.width + p.seedX;
  queue.add(seedIndex);
  visited[seedIndex] = 1;

  // Fill the seed pixel itself (the BFS only fills neighbors via _tryAdd)
  final seedPixelIndex = seedIndex * 4;
  filled[seedPixelIndex]     = p.fillR;
  filled[seedPixelIndex + 1] = p.fillG;
  filled[seedPixelIndex + 2] = p.fillB;
  filled[seedPixelIndex + 3] = p.fillA;

  while (queue.isNotEmpty) {
    final index = queue.removeFirst();
    final x = index % p.width;
    final y = index ~/ p.width;

    _tryAdd(
      filled,
      visited,
      queue,
      p.width,
      p.height,
      x - 1,
      y,
      targetR,
      targetG,
      targetB,
      targetA,
      p.fillR,
      p.fillG,
      p.fillB,
      p.fillA,
      p.tolerance,
    );
    _tryAdd(
      filled,
      visited,
      queue,
      p.width,
      p.height,
      x + 1,
      y,
      targetR,
      targetG,
      targetB,
      targetA,
      p.fillR,
      p.fillG,
      p.fillB,
      p.fillA,
      p.tolerance,
    );
    _tryAdd(
      filled,
      visited,
      queue,
      p.width,
      p.height,
      x,
      y - 1,
      targetR,
      targetG,
      targetB,
      targetA,
      p.fillR,
      p.fillG,
      p.fillB,
      p.fillA,
      p.tolerance,
    );
    _tryAdd(
      filled,
      visited,
      queue,
      p.width,
      p.height,
      x,
      y + 1,
      targetR,
      targetG,
      targetB,
      targetA,
      p.fillR,
      p.fillG,
      p.fillB,
      p.fillA,
      p.tolerance,
    );
  }

  return filled;
}

int _getByte(
  Uint8List bytes,
  int width,
  int height,
  int x,
  int y,
  int channel,
) {
  if (x < 0 || x >= width || y < 0 || y >= height) return 0;
  final index = (y * width + x) * 4 + channel;
  if (index < 0 || index >= bytes.length) return 0;
  return bytes[index];
}

bool _colorsMatch(
  int r1,
  int g1,
  int b1,
  int a1,
  int r2,
  int g2,
  int b2,
  int a2,
  int tolerance,
) {
  if (tolerance == 0) {
    return r1 == r2 && g1 == g2 && b1 == b2 && a1 == a2;
  }
  return (r1 - r2).abs() <= tolerance &&
      (g1 - g2).abs() <= tolerance &&
      (b1 - b2).abs() <= tolerance &&
      (a1 - a2).abs() <= tolerance;
}

void _tryAdd(
  Uint8List filled,
  Uint8List visited,
  Queue<int> queue,
  int width,
  int height,
  int x,
  int y,
  int targetR,
  int targetG,
  int targetB,
  int targetA,
  int fillR,
  int fillG,
  int fillB,
  int fillA,
  int tolerance,
) {
  if (x < 0 || x >= width || y < 0 || y >= height) return;
  final index = y * width + x;
  if (visited[index] != 0) return;

  final r = _getByte(filled, width, height, x, y, 0);
  final g = _getByte(filled, width, height, x, y, 1);
  final b = _getByte(filled, width, height, x, y, 2);
  final a = _getByte(filled, width, height, x, y, 3);

  if (!_colorsMatch(
    r,
    g,
    b,
    a,
    targetR,
    targetG,
    targetB,
    targetA,
    tolerance,
  )) {
    return;
  }

  final pixelIndex = index * 4;
  filled[pixelIndex] = fillR;
  filled[pixelIndex + 1] = fillG;
  filled[pixelIndex + 2] = fillB;
  filled[pixelIndex + 3] = fillA;

  visited[index] = 1;
  queue.add(index);
}

Future<ui.Image> _createImageFromRgbaBytes(
  Uint8List bytes,
  int width,
  int height,
) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes,
    width,
    height,
    ui.PixelFormat.rgba8888,
    (image) => completer.complete(image),
  );
  return completer.future;
}
