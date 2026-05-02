# Fill Tool Fix — Design Spec

**Date:** 2026-05-02  
**Branch:** fill

## Problem

The Fill tool has three distinct bugs:

1. **Single tap does nothing.** The fill is wired to `onPanStart`, which Flutter only fires after the gesture recognizer detects movement. A stationary tap is never recognized.

2. **Fill is very slow.** `_performFill` captures the canvas at `pixelRatio: 3.0` (an 800×600 canvas becomes 2400×1800 = 4.3M pixels), then encodes to PNG and decodes back — a round-trip that takes seconds even in an isolate.

3. **Anti-aliased strokes leave unfilled halos.** Strokes are drawn with `isAntiAlias: true`, so edge pixels are blended (e.g., black stroke on white → gray border pixels ~230,230,230). The flood fill has `tolerance: 5`, which doesn't match those gray pixels, leaving a thin unfilled ring around every diagonal or curved stroke.

## Approach: Targeted fixes (Option A)

Fix each bug at its root with minimal code surface.

## Fix 1 — Trigger (drawing_canvas.dart)

Add `onTapDown` to the `GestureDetector` in `DrawingCanvas.build`. When the fill tool is active, `onTapDown` calls `_performFill(details.localPosition, canvasSize)`. The existing `onPanStart` handler is kept unchanged — `_isProcessingFill` already guards against concurrent fill calls, so a press-and-drag can't double-fire.

No other code changes needed for this fix.

## Fix 2 — Performance (drawing_canvas.dart + flood_fill.dart)

**Drop `pixelRatio` from 3.0 to 1.0** in `_performFill`. Flood fill operates on pixel colors — it does not need a high-resolution capture. This reduces pixel count 9× (480K instead of 4.3M for the default canvas), shrinking BFS work and memory proportionally.

**Remove the `* 3.0` seed point multiplier** in `_performFill`. It existed to convert logical canvas coordinates into 3× pixel space. At `pixelRatio: 1.0` the seed point is already in pixel space.

**Replace `_createImageFromRgbaBytes`** in `flood_fill.dart`. The current path:  
`raw bytes → img.Image → PNG bytes → ui.decodeImageFromList`  
is replaced with a direct call to `ui.decodeImageFromPixels`:

```dart
Future<ui.Image> _createImageFromRgbaBytes(Uint8List bytes, int width, int height) async {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    bytes, width, height, ui.PixelFormat.rgba8888,
    (image) => completer.complete(image),
  );
  return completer.future;
}
```

No PNG encoding, no `image` package needed for this path. Remove the `package:image/image.dart` import from `flood_fill.dart`.

## Fix 3 — Anti-aliasing tolerance (drawing_canvas.dart)

Raise the `tolerance` argument passed to `floodFill` from `5` to `25`.

At tolerance 25, a halo pixel blended ~10% black on white (≈230,230,230) is within 25 of white (255,255,255) and gets filled. The stroke center (0,0,0) differs by 255 — far outside tolerance — so strokes are never crossed. No changes needed inside `flood_fill.dart`.

## Files changed

| File | Change |
|------|--------|
| `lib/widgets/drawing_canvas.dart` | Add `onTapDown`, change `pixelRatio` to 1.0, remove `* 3.0` seed multiplier, raise `tolerance` to 25 |
| `lib/utils/flood_fill.dart` | Replace `_createImageFromRgbaBytes` with `ui.decodeImageFromPixels`, remove `package:image` import |

## Out of scope

- Configurable tolerance UI (straightforward addition later if needed)
- Rendering without anti-aliasing for fill (Option B — more invasive, not needed)
- Span-fill halo cleanup algorithm (Option C — unnecessary complexity)
