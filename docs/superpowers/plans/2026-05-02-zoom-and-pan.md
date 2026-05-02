# Zoom and Pan — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add pinch-zoom and two-finger pan on mobile, scroll-wheel zoom toward cursor and middle-mouse-button pan on Linux desktop, suppressing all drawing during navigation gestures.

**Architecture:** Replace `_CanvasArea`'s nested `SingleChildScrollView` with a `_ZoomPanWrapper` that owns a `TransformationController` and a `Listener` for raw pointer events. `InteractiveViewer` (its own gesture-handling disabled) applies the matrix visually. `DrawingCanvas` gains an `isGestureActive` flag — when true, all drawing callbacks are no-ops and any in-progress stroke is cancelled.

**Tech Stack:** Flutter, `dart:math` (`sqrt`, `exp`, `min`), `TransformationController`, `InteractiveViewer`, `Listener` (raw pointer events), `GestureBinding.instance.pointerSignalResolver`, `kMiddleMouseButton`

---

### Task 1: Gate drawing on `isGestureActive` in `DrawingCanvas`

**Files:**
- Modify: `lib/widgets/drawing_canvas.dart`

- [ ] **Step 1: Add `isGestureActive` parameter to the widget**

In `lib/widgets/drawing_canvas.dart`, change the widget class:

```dart
class DrawingCanvas extends ConsumerStatefulWidget {
  const DrawingCanvas({super.key, this.isGestureActive = false});

  final bool isGestureActive;

  @override
  ConsumerState<DrawingCanvas> createState() => _DrawingCanvasState();
}
```

- [ ] **Step 2: Cancel any in-progress draw when gesture starts**

Add `didUpdateWidget` inside `_DrawingCanvasState` (after `initState`):

```dart
@override
void didUpdateWidget(DrawingCanvas oldWidget) {
  super.didUpdateWidget(oldWidget);
  if (widget.isGestureActive && !oldWidget.isGestureActive) {
    ref.read(drawingProvider.notifier).clearPreview();
    setState(() => _panPosition = null);
  }
}
```

- [ ] **Step 3: Gate all drawing callbacks**

Replace the entire `GestureDetector` block in `build` with this version (adds `if (widget.isGestureActive) return;` at the top of every callback):

```dart
GestureDetector(
  onPanStart: (details) {
    if (widget.isGestureActive) return;
    if (state.currentTool == ToolType.fill) {
      _performFill(details.localPosition);
    } else {
      notifier.onPanStart(details.localPosition);
      setState(() => _panPosition = details.localPosition);
    }
  },
  onPanUpdate: (details) {
    if (widget.isGestureActive) return;
    if (state.currentTool != ToolType.fill) {
      notifier.onPanUpdate(details.localPosition);
      setState(() => _panPosition = details.localPosition);
    }
  },
  onPanEnd: (details) {
    if (widget.isGestureActive) return;
    if (state.currentTool != ToolType.fill) {
      notifier.onPanEnd(canvasSize);
    }
    setState(() => _panPosition = null);
  },
  onPanCancel: () {
    if (widget.isGestureActive) return;
    notifier.clearPreview();
    setState(() => _panPosition = null);
  },
  child: RepaintBoundary(
    key: _repaintBoundaryKey,
    child: CustomPaint(
      painter: CanvasPainter(
        actions: state.actions,
        previewPoints: state.previewPoints,
        previewStart: state.previewStart,
        previewEnd: state.previewEnd,
        currentTool: state.currentTool,
        currentColor: state.currentColor,
        brushStrokeWidth: state.brushStrokeWidth,
        shapeStrokeWidth: state.shapeStrokeWidth,
        spraySize: state.spraySize,
      ),
      size: canvasSize,
    ),
  ),
),
```

- [ ] **Step 4: Verify the app still compiles and draws normally**

```bash
flutter run -d linux
```

Expected: app starts, drawing works as before — `isGestureActive` defaults to `false` so no behaviour change.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/drawing_canvas.dart
git commit -m "feat: gate DrawingCanvas drawing on isGestureActive flag"
```

---

### Task 2: Replace `_CanvasArea` scroll view with `_ZoomPanWrapper` skeleton

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Replace `_CanvasArea` with a thin delegating widget**

Replace the entire `_CanvasArea` class in `lib/main.dart` with:

```dart
class _CanvasArea extends StatelessWidget {
  const _CanvasArea({
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double canvasWidth;
  final double canvasHeight;

  @override
  Widget build(BuildContext context) {
    return _ZoomPanWrapper(
      canvasWidth: canvasWidth,
      canvasHeight: canvasHeight,
    );
  }
}
```

- [ ] **Step 2: Add `_ZoomPanWrapper` skeleton at the end of `lib/main.dart`**

```dart
class _ZoomPanWrapper extends StatefulWidget {
  const _ZoomPanWrapper({
    required this.canvasWidth,
    required this.canvasHeight,
  });

  final double canvasWidth;
  final double canvasHeight;

  @override
  State<_ZoomPanWrapper> createState() => _ZoomPanWrapperState();
}

class _ZoomPanWrapperState extends State<_ZoomPanWrapper> {
  final TransformationController _controller = TransformationController();
  bool _isGestureActive = false;
  bool _initialized = false;

  // Pinch tracking
  final Map<int, Offset> _pointers = {};
  double? _lastPinchDistance;
  Offset? _lastPinchCentroid;

  // Middle mouse tracking
  bool _middleButtonDown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _minScale(BoxConstraints constraints) {
    final sx = constraints.maxWidth / widget.canvasWidth;
    final sy = constraints.maxHeight / widget.canvasHeight;
    return min(sx, sy) * 0.9;
  }

  double get _currentScale {
    final m = _controller.value;
    return sqrt(m[0] * m[0] + m[1] * m[1]);
  }

  void _applyZoom(Offset focalPoint, double scaleDelta, double minScale) {
    final double newScale = (_currentScale * scaleDelta).clamp(minScale, 10.0);
    final double clampedDelta = newScale / _currentScale;
    final Matrix4 zoomMatrix = Matrix4.identity()
      ..translate(focalPoint.dx, focalPoint.dy, 0)
      ..scale(clampedDelta, clampedDelta, 1)
      ..translate(-focalPoint.dx, -focalPoint.dy, 0);
    _controller.value = zoomMatrix * _controller.value;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!_initialized) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_initialized || !mounted) return;
            final dx = (constraints.maxWidth - widget.canvasWidth) / 2.0;
            final dy = (constraints.maxHeight - widget.canvasHeight) / 2.0;
            _controller.value = Matrix4.translationValues(
              dx.clamp(0.0, double.infinity),
              dy.clamp(0.0, double.infinity),
              0,
            );
            setState(() => _initialized = true);
          });
        }

        return InteractiveViewer(
          transformationController: _controller,
          panEnabled: false,
          scaleEnabled: false,
          constrained: false,
          child: DrawingCanvas(isGestureActive: _isGestureActive),
        );
      },
    );
  }
}
```

- [ ] **Step 3: Run and verify canvas appears centered, drawing still works**

```bash
flutter run -d linux
```

Expected: canvas appears centered in the viewport. Drawing works. No scroll/zoom yet.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add _ZoomPanWrapper with InteractiveViewer skeleton"
```

---

### Task 3: Add mobile two-finger pinch zoom and pan

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add `_handlePointerDown` for touch**

Add this method to `_ZoomPanWrapperState`:

```dart
void _handlePointerDown(PointerDownEvent event, double minScale) {
  if (event.kind == PointerDeviceKind.touch) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      final positions = _pointers.values.toList();
      _lastPinchDistance = (positions[0] - positions[1]).distance;
      _lastPinchCentroid = (positions[0] + positions[1]) / 2;
      setState(() => _isGestureActive = true);
    }
  }
}
```

- [ ] **Step 2: Add `_handlePointerMove` for touch**

```dart
void _handlePointerMove(PointerMoveEvent event, double minScale) {
  if (event.kind == PointerDeviceKind.touch) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2 &&
        _lastPinchDistance != null &&
        _lastPinchCentroid != null) {
      final positions = _pointers.values.toList();
      final newDistance = (positions[0] - positions[1]).distance;
      final newCentroid = (positions[0] + positions[1]) / 2;

      if (_lastPinchDistance! > 0) {
        _applyZoom(newCentroid, newDistance / _lastPinchDistance!, minScale);
      }

      final centroidDelta = newCentroid - _lastPinchCentroid!;
      _controller.value =
          Matrix4.translationValues(centroidDelta.dx, centroidDelta.dy, 0) *
              _controller.value;

      _lastPinchDistance = newDistance;
      _lastPinchCentroid = newCentroid;
    }
  }
}
```

- [ ] **Step 3: Add `_handlePointerUp` for touch**

```dart
void _handlePointerUp(PointerEvent event) {
  if (event.kind == PointerDeviceKind.touch) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _lastPinchDistance = null;
      _lastPinchCentroid = null;
      if (_pointers.isEmpty) {
        setState(() => _isGestureActive = false);
      }
    }
  }
}
```

- [ ] **Step 4: Wrap `InteractiveViewer` in `Listener` inside `build`**

Replace `return InteractiveViewer(...)` in `build` with:

```dart
return Listener(
  onPointerDown: (e) => _handlePointerDown(e, _minScale(constraints)),
  onPointerMove: (e) => _handlePointerMove(e, _minScale(constraints)),
  onPointerUp: _handlePointerUp,
  onPointerCancel: _handlePointerUp,
  child: InteractiveViewer(
    transformationController: _controller,
    panEnabled: false,
    scaleEnabled: false,
    constrained: false,
    child: DrawingCanvas(isGestureActive: _isGestureActive),
  ),
);
```

- [ ] **Step 5: Run on Android and test pinch zoom + two-finger pan**

```bash
flutter run -d <device-id>
```

Expected:
- Single-finger draw works normally.
- Two-finger pinch zooms in and out.
- Two-finger drag pans the canvas.
- No draw stroke is created while two fingers are down.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add mobile two-finger pinch zoom and pan"
```

---

### Task 4: Add desktop scroll wheel zoom toward cursor

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Add `_handleScroll` method**

Add to `_ZoomPanWrapperState`:

```dart
void _handleScroll(PointerSignalEvent event, double minScale) {
  if (event is! PointerScrollEvent) return;
  GestureBinding.instance.pointerSignalResolver.register(event, (event) {
    if (event is! PointerScrollEvent) return;
    // exp(-dy/500): scroll down (dy>0) zooms out, scroll up (dy<0) zooms in.
    // dy≈100 per click → exp(-0.2) ≈ 0.82 per notch (~18% step).
    final double scaleDelta = exp(-event.scrollDelta.dy / 500.0);
    _applyZoom(event.localPosition, scaleDelta, minScale);
  });
}
```

- [ ] **Step 2: Wire `onPointerSignal` into `Listener` in `build`**

Add `onPointerSignal` to the existing `Listener`:

```dart
return Listener(
  onPointerDown: (e) => _handlePointerDown(e, _minScale(constraints)),
  onPointerMove: (e) => _handlePointerMove(e, _minScale(constraints)),
  onPointerUp: _handlePointerUp,
  onPointerCancel: _handlePointerUp,
  onPointerSignal: (e) => _handleScroll(e, _minScale(constraints)),
  child: InteractiveViewer(
    transformationController: _controller,
    panEnabled: false,
    scaleEnabled: false,
    constrained: false,
    child: DrawingCanvas(isGestureActive: _isGestureActive),
  ),
);
```

- [ ] **Step 3: Run on Linux and verify cursor-centric scroll zoom**

```bash
flutter run -d linux
```

Expected:
- Scroll up → zoom in, the pixel under the cursor stays fixed.
- Scroll down → zoom out, the pixel under the cursor stays fixed.
- Cannot zoom in beyond 10×.
- Cannot zoom out past the point where the full canvas fits with margin.

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add scroll wheel zoom toward cursor on desktop"
```

---

### Task 5: Add desktop middle mouse button pan

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: Update `_handlePointerDown` to also handle middle mouse button**

Replace the existing `_handlePointerDown` with this unified version:

```dart
void _handlePointerDown(PointerDownEvent event, double minScale) {
  if (event.kind == PointerDeviceKind.touch) {
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2) {
      final positions = _pointers.values.toList();
      _lastPinchDistance = (positions[0] - positions[1]).distance;
      _lastPinchCentroid = (positions[0] + positions[1]) / 2;
      setState(() => _isGestureActive = true);
    }
  } else if (event.buttons & kMiddleMouseButton != 0) {
    setState(() {
      _middleButtonDown = true;
      _isGestureActive = true;
    });
  }
}
```

- [ ] **Step 2: Update `_handlePointerMove` to also handle middle mouse pan**

Replace the existing `_handlePointerMove` with this unified version:

```dart
void _handlePointerMove(PointerMoveEvent event, double minScale) {
  if (event.kind == PointerDeviceKind.touch) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_pointers.length == 2 &&
        _lastPinchDistance != null &&
        _lastPinchCentroid != null) {
      final positions = _pointers.values.toList();
      final newDistance = (positions[0] - positions[1]).distance;
      final newCentroid = (positions[0] + positions[1]) / 2;

      if (_lastPinchDistance! > 0) {
        _applyZoom(newCentroid, newDistance / _lastPinchDistance!, minScale);
      }

      final centroidDelta = newCentroid - _lastPinchCentroid!;
      _controller.value =
          Matrix4.translationValues(centroidDelta.dx, centroidDelta.dy, 0) *
              _controller.value;

      _lastPinchDistance = newDistance;
      _lastPinchCentroid = newCentroid;
    }
  } else if (_middleButtonDown) {
    _controller.value =
        Matrix4.translationValues(event.delta.dx, event.delta.dy, 0) *
            _controller.value;
  }
}
```

- [ ] **Step 3: Update `_handlePointerUp` to also release middle mouse**

Replace the existing `_handlePointerUp` with this unified version:

```dart
void _handlePointerUp(PointerEvent event) {
  if (event.kind == PointerDeviceKind.touch) {
    _pointers.remove(event.pointer);
    if (_pointers.length < 2) {
      _lastPinchDistance = null;
      _lastPinchCentroid = null;
      if (_pointers.isEmpty) {
        setState(() => _isGestureActive = false);
      }
    }
  } else if (event is PointerUpEvent &&
      _middleButtonDown &&
      event.buttons & kMiddleMouseButton == 0) {
    setState(() {
      _middleButtonDown = false;
      _isGestureActive = false;
    });
  }
}
```

- [ ] **Step 4: Run on Linux and verify middle mouse button pan**

```bash
flutter run -d linux
```

Expected:
- Hold middle mouse button and drag → canvas pans smoothly.
- Left mouse button drawing still works normally.
- Drawing is suppressed while middle button is held.
- Releasing middle button immediately re-enables drawing.

- [ ] **Step 5: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add middle mouse button pan on desktop"
```
