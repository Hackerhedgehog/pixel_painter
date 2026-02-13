import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saver_gallery/saver_gallery.dart';

/// Saves PNG bytes to storage.
/// On mobile: saves to gallery in Pictures/PixelPainter folder.
/// On desktop: saves to app documents directory.
Future<void> saveToStorage(Uint8List bytes) async {
  if (Platform.isAndroid || Platform.isIOS) {
    await _saveToGallery(bytes);
  } else {
    await _saveToDocuments(bytes);
  }
}

Future<void> _saveToGallery(Uint8List bytes) async {
  if (Platform.isIOS) {
    final granted = await _requestGalleryPermission();
    if (!granted) return;
  }
  // Android 10+ can save to MediaStore without storage permission

  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final name = 'drawing_$timestamp.png';

  await SaverGallery.saveImage(
    bytes,
    fileName: name,
    androidRelativePath: 'Pictures/PixelPainter',
    skipIfExists: false,
  );
}

Future<bool> _requestGalleryPermission() async {
  if (Platform.isAndroid) {
    // Android 10+ can write to MediaStore without permission; request for older devices
    final status = await Permission.storage.request();
    return status.isGranted;
  }
  if (Platform.isIOS) {
    final status = await Permission.photosAddOnly.request();
    return status.isGranted;
  }
  return false;
}

Future<void> _saveToDocuments(Uint8List bytes) async {
  final directory = await getApplicationDocumentsDirectory();
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final path = '${directory.path}/drawing_$timestamp.png';
  final file = File(path);
  await file.writeAsBytes(bytes);
}
