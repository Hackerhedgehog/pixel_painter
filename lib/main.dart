import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'widgets/drawing_canvas.dart';
import 'widgets/tool_panel.dart';

/// Canvas default background color.
const Color _canvasColor = Colors.white;

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

class PaintingPage extends StatelessWidget {
  const PaintingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('Pixel Painter'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: _canvasColor,
              child: const DrawingCanvas(),
            ),
          ),
          const ToolPanel(),
        ],
      ),
    );
  }
}
