import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// Saves PNG bytes by triggering a download in the browser (web only).
Future<void> saveToStorage(Uint8List bytes) async {
  final data = bytes.buffer.toJS;
  final blob = web.Blob([data].toJS, web.BlobPropertyBag(type: 'image/png'));
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..style.display = 'none'
    ..download = 'drawing_${DateTime.now().millisecondsSinceEpoch}.png';
  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
}
