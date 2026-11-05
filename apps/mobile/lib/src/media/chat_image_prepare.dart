import 'dart:io';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

bool _looksLikeHeic(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.heic') || lower.endsWith('.heif');
}

bool _isAlreadyJpegFriendly(String path) {
  final lower = path.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.webp') ||
      lower.endsWith('.gif');
}

Future<String> prepareChatImageForUpload(String path) async {
  final file = File(path);
  if (!await file.exists()) return path;

  if (_isAlreadyJpegFriendly(path) && !_looksLikeHeic(path)) {
    return path;
  }

  final bytes = await file.readAsBytes();
  img.Image? decoded = img.decodeImage(bytes);

  if (decoded == null) {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final uiImage = frame.image;
      final pngBytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (pngBytes != null) {
        decoded = img.decodeImage(pngBytes.buffer.asUint8List());
      }
    } catch (_) {}
  }

  if (decoded == null) return path;

  final dir = await getTemporaryDirectory();
  final out = '${dir.path}/chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
  await File(out).writeAsBytes(img.encodeJpg(decoded, quality: 90));
  return out;
}
