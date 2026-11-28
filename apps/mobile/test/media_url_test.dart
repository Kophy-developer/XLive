import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/core/media/media_url.dart';

void main() {
  const uuid = 'ea5e3cce-4899-4828-a647-d3ce7a454f28';
  const cloud = 'https://res.cloudinary.com/dlfzn6m9q/video/upload/f_mp4/x-live/$uuid';
  const host = 'https://xlive-app-bcqre.ondigitalocean.app/uploads/x-live/$uuid';

  test('host x-live streamUrl plays from Cloudinary', () {
    expect(playbackVideoUrl(host), cloud);
    expect(resolveMediaUrl(host, resourceType: 'video'), cloud);
    expect(resolveMediaUrl('/uploads/x-live/$uuid', resourceType: 'video'), cloud);
    expect(resolveMediaUrl('uploads/x-live/$uuid', resourceType: 'video'), cloud);
    expect(resolveMediaUrl('$host.mp4', resourceType: 'video'), cloud);
  });

  test('image resolve leaves host uploads alone', () {
    expect(resolveMediaUrl(host, resourceType: 'image'), host);
  });

  test('real Cloudinary and HLS urls are unchanged in kind', () {
    const existing = 'https://res.cloudinary.com/dlfzn6m9q/video/upload/v1/x-live/$uuid.mp4';
    expect(
      playbackVideoUrl(existing),
      'https://res.cloudinary.com/dlfzn6m9q/video/upload/f_mp4/v1/x-live/$uuid.mp4',
    );
    const hls = 'https://res.cloudinary.com/dlfzn6m9q/video/upload/x-live/$uuid.m3u8';
    expect(playbackVideoUrl(hls), hls);
    const jpg = 'https://res.cloudinary.com/dlfzn6m9q/image/upload/v1/x-live/poster.jpg';
    expect(resolveMediaUrl(jpg, resourceType: 'image'), jpg);
  });

  test('unrelated host files are not rewritten', () {
    const other = 'https://xlive-app-bcqre.ondigitalocean.app/uploads/chat/abc.mp4';
    expect(playbackVideoUrl(other), other);
  });

  test('signed Cloudinary URLs are not rewritten', () {
    const signed =
        'https://res.cloudinary.com/dnof89azc/image/upload/s--vGFBuVeq--/v1/x-live/posts/abc/file.mp4?_a=BAMAK';
    expect(resolveMediaUrl(signed, resourceType: 'video'), signed);
    expect(playbackVideoUrl(signed), signed);
  });
}
