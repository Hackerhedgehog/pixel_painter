import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/canvas_settings_provider.dart';
import 'widgets/drawing_canvas.dart';
import 'widgets/side_panel.dart';
import 'widgets/tool_panel.dart';
import 'widgets/top_tool_bar.dart';

final sidePanelOpenProvider = StateProvider<bool>((ref) => false);

void main() {
  runApp(
    const ProviderScope(
      child: PixelPainterApp(),
    ),
  );
}

class PixelPainterApp extends StatelessWidget {
  const PixelPainterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pixel Painter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueGrey),
        useMaterial3: true,
      ),
      home: const PaintingPage(),
    );
  }
}

class PaintingPage extends ConsumerWidget {
  const PaintingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPanelOpen = ref.watch(sidePanelOpenProvider);
    final canvasSettings = ref.watch(canvasSettingsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(isPanelOpen ? Icons.close : Icons.menu),
          onPressed: () =>
              ref.read(sidePanelOpenProvider.notifier).state = !isPanelOpen,
          tooltip: isPanelOpen ? 'Close panel' : 'Open panel',
        ),
        title: const Text('Pixel Painter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Row(
        children: [
          // Collapsible side panel — slides in from the left.
          ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: isPanelOpen ? 240.0 : 0.0,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 240,
                maxWidth: 240,
                child: const SidePanel(),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                const TopToolBar(),
                Expanded(
                  child: _CanvasArea(
                    canvasWidth: canvasSettings.width,
                    canvasHeight: canvasSettings.height,
                  ),
                ),
                const ToolPanel(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
    final Matrix4 zoomMatrix =
        Matrix4.translationValues(focalPoint.dx, focalPoint.dy, 0) *
        Matrix4.diagonal3Values(clampedDelta, clampedDelta, 1) *
        Matrix4.translationValues(-focalPoint.dx, -focalPoint.dy, 0);
    _controller.value = zoomMatrix * _controller.value;
  }

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
      },
    );
  }
}
