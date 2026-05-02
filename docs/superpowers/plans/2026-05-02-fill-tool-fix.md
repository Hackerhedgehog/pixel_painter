# Fill Tool Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the Fill tool so a single tap reliably fills all connected same-colored pixels using the selected color, quickly and without leaving anti-aliased halos.

**Architecture:** Three targeted fixes across two files — add `onTapDown` for gesture detection, drop `pixelRatio` from 3.0 to 1.0 and replace the slow PNG round-trip with `ui.decodeImageFromPixels` for performance, and raise fill tolerance from 5 to 25 to cover anti-aliased halo pixels.

**Tech Stack:** Flutter/Dart, Riverpod (`flutter_riverpod`), `flutter_test`

---

## File Map

| File | Change |
|------|--------|
| `lib/utils/flood_fill.dart` | Replace `_createImageFromRgbaBytes` with `ui.decodeImageFromPixels`; remove `package:image` import |
| `lib/widgets/drawing_canvas.dart` | Add `onTapDown`; change `pixelRatio` to 1.0; remove `* 3.0` seed multiplier; raise `tolerance` to 25 |
| `test/utils/flood_fill_test.dart` | New: unit tests for tolerance behavior |

---

### Task 1: Write failing test for tolerance behavior

**Files:**
- Create: `test/utils/flood_fill_test.dart`

- [ ] **Step 1: Create the test directory and file**

```bash
mkdir -p test/utils
```

Create `test/utils/flood_fill_test.dart`:

```dart
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
```

- [ ] **Step 2: Run tests to verify first test FAILS, second PASSES**

```bash
flutter test test/utils/flood_fill_test.dart -v
```

Expected output:
```
✗ floodFill fills anti-aliased halo pixels when tolerance is 25
  Expected: <255>
  Actual: <230>   ← halo not filled because current call-site uses tolerance=5
✓ floodFill leaves anti-aliased halo unfilled when tolerance is 5
```

---

### Task 2: Fix flood_fill.dart — remove PNG round-trip

**Files:**
- Modify: `lib/utils/flood_fill.dart`

The current `_createImageFromRgbaBytes` encodes raw bytes to PNG then decodes them back via the `image` package — a slow round-trip that takes seconds on a default canvas. Replace it with `ui.decodeImageFromPixels`, which creates a `ui.Image` directly from RGBA bytes.

- [ ] **Step 1: Remove the `package:image` import (line 7)**

Delete this line from `lib/utils/flood_fill.dart`:

```dart
import 'package:image/image.dart' as img;
```

- [ ] **Step 2: Replace `_createImageFromRgbaBytes` (lines 279–294)**

Replace the entire function with:

```dart
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
```

- [ ] **Step 3: Run tests to confirm no regression**

```bash
flutter test test/utils/flood_fill_test.dart -v
```

Expected: same results as Task 1 — first test FAIL, second PASS. The internal image-creation path changed but the observable behavior (which pixels get filled) is unchanged.

- [ ] **Step 4: Commit**

```bash
git add lib/utils/flood_fill.dart test/utils/flood_fill_test.dart
git commit -m "perf: replace PNG round-trip with ui.decodeImageFromPixels in flood fill"
```

---

### Task 3: Fix drawing_canvas.dart — pixelRatio, seed point, tolerance

**Files:**
- Modify: `lib/widgets/drawing_canvas.dart` (`_performFill` method, lines 55–82)

- [ ] **Step 1: Replace `_performFill`**

Replace the entire `_performFill` method with:

```dart
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
```

Changes from old code:
- `pixelRatio: 1.0` (was `3.0`) — 9× fewer pixels to BFS
- `seedPoint: clamped` (was `clamped * 3.0`) — no longer scaling to 3× pixel space
- `tolerance: 25` (was `5`) — fills anti-aliased halo pixels

- [ ] **Step 2: Run tests**

```bash
flutter test test/utils/flood_fill_test.dart -v
```

Expected: both tests PASS. The first test now passes because `tolerance: 25` is the value exercised by `_performFill`, and the test calls `floodFill` directly with `tolerance: 25`.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/drawing_canvas.dart
git commit -m "fix: drop fill pixelRatio to 1.0, remove 3x seed scaling, raise tolerance to 25"
```

---

### Task 4: Fix drawing_canvas.dart — tap trigger

**Files:**
- Modify: `lib/widgets/drawing_canvas.dart` (`build` method)

The `GestureDetector` currently only has `onPanStart`, which Flutter fires only after detecting movement. A stationary tap never triggers fill. Adding `onTapDown` fires on the initial pointer-down event before any movement threshold.

- [ ] **Step 1: Add `onTapDown` to the `GestureDetector` in `build`**

Find the `GestureDetector` in `DrawingCanvas.build` (around line 174). Add `onTapDown` immediately before the existing `onPanStart`:

```dart
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
      final start = clampToCanvas(details.localPosition, canvasSize);
      notifier.onPanStart(start);
      setState(() {
        _paintGestureActive = true;
        _panPosition = start;
      });
    }
  },
  // onPanUpdate, onPanEnd, onPanCancel unchanged
```

- [ ] **Step 2: Run all tests**

```bash
flutter test -v
```

Expected: all tests PASS — including the existing `widget_test.dart` app-loads test.

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/drawing_canvas.dart
git commit -m "fix: trigger fill on tap via onTapDown"
```

---

### Task 5: Manual verification

- [ ] **Step 1: Run the app**

```bash
flutter run
```

- [ ] **Step 2: Verify the three fixes**

1. **Tap trigger** — Draw a black stroke enclosing an area. Select Fill tool. Single-tap (no dragging) inside the area → fills immediately.
2. **Speed** — Fill completes in well under 1 second on the default 800×600 canvas.
3. **No halos** — Draw a curved or diagonal black stroke on white. Fill the white area adjacent to it → no thin unfilled gray ring visible around the stroke edge.

- [ ] **Step 3: Verify undo/redo**

After filling, press Undo → canvas reverts to pre-fill state. Press Redo → fill reapplies correctly.
