import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/canvas_settings_provider.dart';
import 'widgets/drawing_canvas.dart';
import 'widgets/side_panel.dart';
import 'widgets/tool_panel.dart';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final areaW = max(constraints.maxWidth, canvasWidth + 32);
        final areaH = max(constraints.maxHeight, canvasHeight + 32);
        return SingleChildScrollView(
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: areaW,
              height: areaH,
              child: Center(
                child: Material(
                  elevation: 4,
                  child: const DrawingCanvas(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
