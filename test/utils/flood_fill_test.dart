import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pixel_painter/utils/flood_fill.dart';

Future<ui.Image> _imageFromBytes(Uint8List bytes, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes, width, height, ui.PixelFormat.rgba8888,
    (img) => completer.complete(img),
  );
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 3×1 image layout: [white | gray(230) | black]
  // gray is exactly 25 units from white on all channels.
  // At tolerance=25 the gray halo must be filled; at tolerance=5 it must not be.

  Future<Uint8List> makeTestImage() async {
    final bytes = Uint8List(3 * 1 * 4);
    // pixel 0 — white (seed)
    bytes[0] = 255; bytes[1] = 255; bytes[2] = 255; bytes[3] = 255;
    // pixel 1 — gray halo (25 units from white)
    bytes[4] = 230; bytes[5] = 230; bytes[6] = 230; bytes[7] = 255;
    // pixel 2 — black stroke (255 units from white, must never be filled)
    bytes[8] = 0;   bytes[9] = 0;   bytes[10] = 0;  bytes[11] = 255;
    return bytes;
  }

  test('floodFill fills anti-aliased halo pixels when tolerance is 25', () async {
    final bytes = await makeTestImage();
    final image = await _imageFromBytes(bytes, 3, 1);

    final filled = await floodFill(
      image: image,
      seedPoint: const Offset(0, 0),
      fillColor: const Color(0xFFFF0000), // red
      tolerance: 25,
    );

    final bd = await filled.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final out = bd!.buffer.asUint8List();

    // pixel 0 (white seed) → red
    expect(out[0], 255, reason: 'seed pixel R should be red');
    expect(out[1], 0,   reason: 'seed pixel G should be 0');

    // pixel 1 (gray halo, 25 units from white) → also red
    expect(out[4], 255, reason: 'halo pixel R should be filled at tolerance 25');
    expect(out[5], 0,   reason: 'halo pixel G should be 0');

    // pixel 2 (black stroke, 255 units from white) → unchanged
    expect(out[8], 0, reason: 'stroke pixel must not be filled');
  });

  test('floodFill leaves anti-aliased halo unfilled when tolerance is 5', () async {
    final bytes = await makeTestImage();
    final image = await _imageFromBytes(bytes, 3, 1);

    final filled = await floodFill(
      image: image,
      seedPoint: const Offset(0, 0),
      fillColor: const Color(0xFFFF0000),
      tolerance: 5,
    );

    final bd = await filled.toByteData(format: ui.ImageByteFormat.rawStraightRgba);
    final out = bd!.buffer.asUint8List();

    // pixel 1 (gray, 25 units from white) must NOT be filled at tolerance 5
    expect(out[4], 230, reason: 'halo pixel R should remain 230 at tolerance 5');
  });
}
