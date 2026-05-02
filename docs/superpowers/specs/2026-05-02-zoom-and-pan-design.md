# Zoom and Pan — Design Spec

**Date:** 2026-05-02  
**Branch:** zoomandpan

---

## Overview

Add viewport zoom and pan to the pixel painter canvas. On mobile, two-finger pinch zooms and two-finger drag pans. On Linux desktop, the scroll wheel zooms toward the cursor and the middle mouse button pans. Drawing is suppressed while any zoom/pan gesture is active.

---

## Architecture

### State

No new Riverpod providers. The viewport transform lives in a `TransformationController` owned by `_ZoomPanWrapper`, a new private widget extracted from `_CanvasArea` in `main.dart`.

`DrawingCanvas` gains a single new parameter: `isGestureActive` (bool). When true, all drawing input is suppressed — `onPanStart`, `onPanUpdate`, and `onPanEnd` are no-ops.

### Widget tree (canvas area)

```
_CanvasArea
  └─ _ZoomPanWrapper (owns TransformationController, LayoutBuilder for min-scale)
       └─ Listener (desktop: scroll wheel + middle mouse button)
            └─ InteractiveViewer (TransformationController, scaleEnabled: false)
                 └─ DrawingCanvas (isGestureActive: bool)
```

`SingleChildScrollView` is removed entirely.

---

## Zoom Bounds

| Bound | Value |
|---|---|
| Min scale | `max(viewportW / canvasW, viewportH / canvasH) * 0.9` — canvas fits with ~10 % margin |
| Max scale | `10.0` |

Min scale is recomputed whenever the viewport or canvas size changes (via `LayoutBuilder`). Both bounds are clamped on every matrix mutation.

---

## Gesture Handling

### Mobile — pinch zoom + two-finger pan

`InteractiveViewer` handles multi-touch natively. Its `onInteractionStart` callback sets `isGestureActive = true`; `onInteractionEnd` resets it to `false`. Single-finger touch reaches the `GestureDetector` inside `DrawingCanvas` as before.

### Desktop — scroll wheel zoom toward cursor

`InteractiveViewer`'s own scroll-to-scale is disabled (`scaleEnabled: false`). The `Listener` intercepts `PointerScrollEvent` in `onPointerSignal`. On each event:

1. Compute `scaleDelta` from `scrollDelta.dy` (negative = zoom in).
2. Clamp the resulting scale within `[minScale, 10.0]`.
3. Build a new `Matrix4` using fixed-point scaling: translate so the cursor's scene position maps to the origin, apply scale, translate back.
4. Assign to `TransformationController.value`.

### Desktop — middle mouse button pan

The `Listener` tracks middle-button state in `onPointerDown` / `onPointerUp` (checking `event.buttons & kMiddleMouseButton`). On `onPointerMove` while the button is held, apply `event.delta` as a translation to `TransformationController.value`, clamped so the canvas cannot be panned entirely off screen.

---

## Coordinate Handling

`DrawingCanvas` lives inside the `InteractiveViewer`'s transformed subtree. Flutter's gesture system delivers `localPosition` in canvas space automatically — no manual matrix inversion required. Existing drawing logic is unchanged.

`_hoverPosition` and `_panPosition` are already canvas-space offsets; the cursor indicator overlay is correct at all zoom levels without modification.

`RepaintBoundary.toImage()` captures the canvas at its natural (unscaled) size, so save and flood-fill are unaffected.

---

## Files Changed

| File | Change |
|---|---|
| `lib/main.dart` | Replace `_CanvasArea` `SingleChildScrollView` body with `_ZoomPanWrapper` + `InteractiveViewer` |
| `lib/widgets/drawing_canvas.dart` | Add `isGestureActive` parameter; gate drawing callbacks on `!isGestureActive` |

No other files are modified.
