import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:xlive_mobile/core/network/api_client.dart';
import 'package:xlive_mobile/core/network/api_exception.dart';
import 'package:xlive_mobile/core/session/session_store.dart';
import 'package:xlive_mobile/features/videos/videos_repository.dart';
import 'package:xlive_mobile/src/media/media_composer.dart';
import 'package:xlive_mobile/src/media/media_editor_models.dart';
import 'package:xlive_mobile/src/media/media_picker_utils.dart';

const _imagePath =
    '/Users/macpro/.cursor/projects/Users-macpro-Projects-XLive/assets/back_view-d1bf5b6b-acd3-444a-97f3-2ef07fce1e36.png';
const _videoPath = '/Users/macpro/Downloads/WhatsApp Video 2026-07-09 at 08.35.13.mp4';

class _MemoryStorage extends FlutterSecureStorage {
  _MemoryStorage() : super();

  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    _data.remove(key);
  }
}

class _CaptureClient extends http.BaseClient {
  http.BaseRequest? last;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    last = request;
    final body = utf8.encode('{"status":true,"statusCode":200,"data":{"id":"ok1","type":"video","title":"t"}}');
    return http.StreamedResponse(Stream.value(body), 200, headers: {'content-type': 'application/json'});
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sample media files exist and classify correctly', () async {
    final image = File(_imagePath);
    final video = File(_videoPath);
    expect(image.existsSync(), isTrue, reason: 'image missing');
    expect(video.existsSync(), isTrue, reason: 'video missing');
    expect(image.lengthSync(), greaterThan(1000));
    expect(video.lengthSync(), greaterThan(1000));

    expect(isImageFilename(_imagePath), isTrue);
    expect(isVideoFilename(_videoPath), isTrue);

    final imagePicked = pickedGalleryMediaFromXFile(XFile(_imagePath, mimeType: 'image/jpeg'));
    final videoPicked = pickedGalleryMediaFromXFile(XFile(_videoPath, mimeType: 'video/mp4'));
    expect(imagePicked, isNotNull);
    expect(imagePicked!.isVideo, isFalse);
    expect(videoPicked, isNotNull);
    expect(videoPicked!.isVideo, isTrue);

    // ignore: avoid_print
    print('image bytes=${image.lengthSync()} uploadName=${uploadFilenameFor(imagePicked)}');
    // ignore: avoid_print
    print('video bytes=${video.lengthSync()} uploadName=${uploadFilenameFor(videoPicked)}');
  });

  test('image decodes and detects extension/content mismatch', () async {
    final bytes = await File(_imagePath).readAsBytes();
    final decoded = img.decodeImage(bytes);
    expect(decoded, isNotNull, reason: 'image bytes must decode');

    final isJpeg = bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
    final isPng = bytes.length >= 8 && bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47;
    // ignore: avoid_print
    print('decoded ${decoded!.width}x${decoded.height} magic jpeg=$isJpeg png=$isPng ext=${_imagePath.split('.').last}');

    expect(isJpeg, isTrue, reason: 'provided sample is JPEG bytes');
    expect(isPng, isFalse);
    expect(_imagePath.toLowerCase().endsWith('.png'), isTrue);
  });

  test('image no-op export is instant', () async {
    final project = MediaEditProject(sourcePath: _imagePath, isVideo: false);
    expect(project.isUnchangedExport, isTrue);

    final sw = Stopwatch()..start();
    final out = await MediaComposer.export(project);
    sw.stop();
    expect(out, _imagePath);
    expect(sw.elapsedMilliseconds, lessThan(500));
    // ignore: avoid_print
    print('noop export ${sw.elapsedMilliseconds}ms');
  });

  test('video unchanged export returns source path', () async {
    final project = MediaEditProject(
      sourcePath: _videoPath,
      isVideo: true,
      durationSec: 12,
      trimStartSec: 0,
      trimEndSec: 12,
    );
    expect(project.isUnchangedExport, isTrue);
    final out = await MediaComposer.export(project);
    expect(out, _videoPath);
  });

  test('image upload corrects png extension when bytes are jpeg', () async {
    final capture = _CaptureClient();
    final client = ApiClient(
      sessionStore: SessionStore(storage: _MemoryStorage()),
      httpClient: capture,
    );
    await client.sessionStore.writeSession(jwt: 'test-jwt', userId: 'u1', identifier: 'tester');

    final bytes = await File(_imagePath).readAsBytes();
    final media = PickedGalleryMedia(file: XFile(_imagePath), isVideo: false);
    final filename = uploadFilenameForImageBytes(media, bytes);
    expect(filename.toLowerCase().endsWith('.jpg'), isTrue);

    final repo = VideosRepository(client: client);
    await repo.uploadVideo(
      bytes,
      filename: filename,
      fields: {
        'type': 'post',
        'visibility': 'everyone',
        'category': 'other',
        'soundCopyrightChecked': 'true',
        'mediaType': 'image',
      },
    );
    final multi = capture.last! as http.MultipartRequest;
    expect(multi.files.single.filename!.toLowerCase().endsWith('.jpg'), isTrue);
    expect(multi.files.single.contentType?.mimeType, 'image/jpeg');
    // ignore: avoid_print
    print('fixed upload filename=${multi.files.single.filename} contentType=${multi.files.single.contentType}');
  });

  test('multipart video upload request shape matches create post', () async {
    final capture = _CaptureClient();
    final client = ApiClient(
      sessionStore: SessionStore(storage: _MemoryStorage()),
      httpClient: capture,
    );
    await client.sessionStore.writeSession(jwt: 'test-jwt', userId: 'u1', identifier: 'tester');
    final repo = VideosRepository(client: client);
    final result = await repo.uploadVideoFile(
      _videoPath,
      filename: 'whatsapp_test.mp4',
      caption: 'pipeline video test',
      fields: {
        'type': 'post',
        'visibility': 'everyone',
        'category': 'other',
        'soundCopyrightChecked': 'true',
        'mediaType': 'video',
        'duration': '12',
      },
    );
    expect(result.id, 'ok1');
    final multi = capture.last! as http.MultipartRequest;
    expect(multi.fields['mediaType'], 'video');
    expect(multi.fields['duration'], '12');
    expect(multi.files.single.filename, 'whatsapp_test.mp4');
    // ignore: avoid_print
    print('mock video upload fields=${multi.fields}');
  });

  test('live staging upload image+video when XLIVE_TEST_JWT is set', () async {
    final jwt = Platform.environment['XLIVE_TEST_JWT'];
    if (jwt == null || jwt.isEmpty) {
      // ignore: avoid_print
      print('SKIP live upload: export XLIVE_TEST_JWT to run against staging');
      return;
    }
    final store = SessionStore(storage: _MemoryStorage());
    await store.writeSession(jwt: jwt, userId: 'test', identifier: 'test');
    final repo = VideosRepository(client: ApiClient(sessionStore: store));

    try {
      final imageBytes = await File(_imagePath).readAsBytes();
      final image = await repo.uploadVideo(
        imageBytes,
        filename: 'pipeline_test.jpg',
        caption: 'live pipeline image test',
        fields: {
          'type': 'post',
          'visibility': 'everyone',
          'category': 'other',
          'soundCopyrightChecked': 'true',
          'mediaType': 'image',
        },
      );
      // ignore: avoid_print
      print('LIVE IMAGE OK id=${image.id}');
    } on ApiException catch (e) {
      fail('LIVE IMAGE FAIL ${e.statusCode} ${e.message}');
    }

    try {
      final video = await repo.uploadVideoFile(
        _videoPath,
        filename: 'pipeline_test.mp4',
        caption: 'live pipeline video test',
        fields: {
          'type': 'post',
          'visibility': 'everyone',
          'category': 'other',
          'soundCopyrightChecked': 'true',
          'mediaType': 'video',
        },
      );
      // ignore: avoid_print
      print('LIVE VIDEO OK id=${video.id}');
    } on ApiException catch (e) {
      fail('LIVE VIDEO FAIL ${e.statusCode} ${e.message}');
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
