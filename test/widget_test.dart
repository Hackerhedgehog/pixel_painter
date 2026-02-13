import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pixel_painter/main.dart';

void main() {
  testWidgets('Pixel Painter app loads', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: PixelPainterApp()));

    expect(find.text('Pixel Painter'), findsOneWidget);
  });
}
