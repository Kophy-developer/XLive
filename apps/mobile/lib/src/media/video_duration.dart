import 'dart:io';

import 'package:video_player/video_player.dart';

Future<int> readVideoDurationSeconds(String filePath) async {
  final controller = VideoPlayerController.file(File(filePath));
  try {
    await controller.initialize();
    final seconds = controller.value.duration.inMilliseconds / 1000.0;
    if (!seconds.isFinite || seconds <= 0) return 1;
    return seconds.round().clamp(1, 24 * 3600);
  } catch (_) {
    return 1;
  } finally {
    await controller.dispose();
  }
}
