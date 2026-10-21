import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

const apiBase = 'https://store-x-live.4tqepo.easypanel.host';
const imagePath =
    '/Users/macpro/.cursor/projects/Users-macpro-Projects-XLive/assets/back_view-d1bf5b6b-acd3-444a-97f3-2ef07fce1e36.png';
const videoPath = '/Users/macpro/Downloads/WhatsApp Video 2026-07-09 at 08.35.13.mp4';

Future<void> main() async {
  final jwt = Platform.environment['XLIVE_TEST_JWT'];
  if (jwt == null || jwt.isEmpty) {
    stderr.writeln('Missing XLIVE_TEST_JWT');
    exit(1);
  }

  final imageBytes = await File(imagePath).readAsBytes();
  final isJpeg = imageBytes.length >= 3 && imageBytes[0] == 0xFF && imageBytes[1] == 0xD8 && imageBytes[2] == 0xFF;
  final imageName = isJpeg ? 'pipeline_test.jpg' : 'pipeline_test.png';
  final imageType = isJpeg ? MediaType('image', 'jpeg') : MediaType('image', 'png');

  stdout.writeln('Uploading image as $imageName (${imageBytes.length} bytes, jpeg=$isJpeg)...');
  final imageSw = Stopwatch()..start();
  final imageRes = await _upload(
    jwt: jwt,
    filename: imageName,
    bytes: imageBytes,
    contentType: imageType,
    fields: {
      'type': 'post',
      'visibility': 'everyone',
      'category': 'other',
      'soundCopyrightChecked': 'true',
      'mediaType': 'image',
      'caption': 'live pipeline image test',
    },
  );
  imageSw.stop();
  stdout.writeln('IMAGE ${imageRes.statusCode} in ${imageSw.elapsedMilliseconds}ms');
  stdout.writeln(imageRes.body.length > 800 ? '${imageRes.body.substring(0, 800)}…' : imageRes.body);

  stdout.writeln('\nUploading video...');
  final videoSw = Stopwatch()..start();
  final videoRes = await _uploadFile(
    jwt: jwt,
    filename: 'pipeline_test.mp4',
    filePath: videoPath,
    contentType: MediaType('video', 'mp4'),
    fields: {
      'type': 'post',
      'visibility': 'everyone',
      'category': 'other',
      'soundCopyrightChecked': 'true',
      'mediaType': 'video',
      'caption': 'live pipeline video test',
    },
  );
  videoSw.stop();
  stdout.writeln('VIDEO ${videoRes.statusCode} in ${videoSw.elapsedMilliseconds}ms');
  stdout.writeln(videoRes.body.length > 800 ? '${videoRes.body.substring(0, 800)}…' : videoRes.body);

  final imageOk = imageRes.statusCode >= 200 && imageRes.statusCode < 300;
  final videoOk = videoRes.statusCode >= 200 && videoRes.statusCode < 300;
  if (!imageOk || !videoOk) exit(2);
  stdout.writeln('\nBOTH UPLOADS OK');
}

Future<http.Response> _upload({
  required String jwt,
  required String filename,
  required List<int> bytes,
  required MediaType contentType,
  required Map<String, String> fields,
}) async {
  final uri = Uri.parse('$apiBase/api/x-live/videos/upload');
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $jwt';
  req.headers['Accept'] = 'application/json';
  req.fields.addAll(fields);
  req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename, contentType: contentType));
  final streamed = await req.send().timeout(const Duration(minutes: 3));
  return http.Response.fromStream(streamed).timeout(const Duration(minutes: 3));
}

Future<http.Response> _uploadFile({
  required String jwt,
  required String filename,
  required String filePath,
  required MediaType contentType,
  required Map<String, String> fields,
}) async {
  final uri = Uri.parse('$apiBase/api/x-live/videos/upload');
  final req = http.MultipartRequest('POST', uri);
  req.headers['Authorization'] = 'Bearer $jwt';
  req.headers['Accept'] = 'application/json';
  req.fields.addAll(fields);
  req.files.add(await http.MultipartFile.fromPath('file', filePath, filename: filename, contentType: contentType));
  final streamed = await req.send().timeout(const Duration(minutes: 5));
  return http.Response.fromStream(streamed).timeout(const Duration(minutes: 5));
}
