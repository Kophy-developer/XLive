import 'dart:typed_data';
import 'dart:ui' as ui;

import '../network/api_exception.dart';

class PreparedImageUpload {
  const PreparedImageUpload({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

Future<PreparedImageUpload> prepareAvatarUpload(
  List<int> bytes, {
  int maxWidth = 1200,
}) async {
  final codec = await ui.instantiateImageCodec(
    Uint8List.fromList(bytes),
    targetWidth: maxWidth,
  );
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
  frame.image.dispose();
  if (data == null) {
    throw ApiException('Could not process image');
  }
  return PreparedImageUpload(
    bytes: data.buffer.asUint8List(),
    filename: 'avatar.png',
  );
}
