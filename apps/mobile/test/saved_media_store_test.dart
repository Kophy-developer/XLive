import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/core/media/saved_media_store.dart';
import 'package:xlive_mobile/features/feed/feed_album.dart';
import 'package:xlive_mobile/features/feed/models/feed_models.dart';
import 'package:xlive_mobile/features/social/models/social_models.dart';

void main() {
  test('canSaveMediaType allows posts/videos and blocks clips/streams', () {
    expect(canSaveMediaType('video'), isTrue);
    expect(canSaveMediaType('post'), isTrue);
    expect(canSaveMediaType('image'), isTrue);
    expect(canSaveMediaType('reel'), isTrue);
    expect(canSaveMediaType('clip'), isFalse);
    expect(canSaveMediaType('stream'), isFalse);
  });

  test('SavedMediaRef.fromJson normalizes post/image to video targetType', () {
    final ref = SavedMediaRef.fromJson({
      'type': 'post',
      '_id': 'abc123',
      'createdAt': '2026-11-14T14:48:22.229Z',
    });
    expect(ref.targetId, 'abc123');
    expect(ref.targetType, 'video');
  });

  test('MediaDetail.isImage follows mediaType', () {
    final image = MediaDetail.fromJson({
      '_id': 'img1',
      'type': 'post',
      'mediaType': 'image',
      'caption': 'hi',
      'thumbnailUrl': 'https://example.com/a.jpg',
      'access': {'allowed': true},
    }, FeedContentType.video);
    expect(image.isImage, isTrue);
    expect(image.savedByMe, isFalse);

    final video = MediaDetail.fromJson({
      '_id': 'vid1',
      'type': 'post',
      'mediaType': 'video',
      'caption': 'clip',
      'savedByMe': true,
      'access': {'allowed': true},
    }, FeedContentType.video);
    expect(video.isImage, isFalse);
    expect(video.savedByMe, isTrue);
  });

  test('MediaDetail prefers caption when it carries album marker', () {
    const marker = '\u2063xlive_album:group9\u2063';
    final detail = MediaDetail.fromJson({
      '_id': 's1',
      'type': 'post',
      'title': 'Vacation',
      'caption': '${marker}Vacation',
      'mediaType': 'image',
      'access': {'allowed': true},
    }, FeedContentType.video);
    expect(detail.title.contains('xlive_album:'), isTrue);
  });

  test('feedSaveTargetIds returns all album slide ids', () {
    final album = FeedItem(
      id: 'a1',
      type: FeedContentType.video,
      title: 'Album',
      albumSlides: const [
        FeedItem(id: 'a1', type: FeedContentType.video, title: '1', mediaType: 'image'),
        FeedItem(id: 'a2', type: FeedContentType.video, title: '2', mediaType: 'image'),
        FeedItem(id: 'a3', type: FeedContentType.video, title: '3', mediaType: 'video'),
      ],
    );
    expect(feedSaveTargetIds(album), ['a1', 'a2', 'a3']);
    expect(
      feedSaveTargetIds(const FeedItem(id: 'solo', type: FeedContentType.video, title: 'Solo')),
      ['solo'],
    );
  });

  test('coalesceFeedAlbums collapses saved album slides into one card', () {
    const marker = '\u2063xlive_album:group1\u2063';
    final coalesced = coalesceFeedAlbums([
      const FeedItem(id: 's2', type: FeedContentType.video, title: '${marker}two', mediaType: 'image'),
      const FeedItem(id: 'solo', type: FeedContentType.video, title: 'Alone', mediaType: 'video'),
      const FeedItem(id: 's1', type: FeedContentType.video, title: '${marker}one', mediaType: 'image'),
    ]);
    expect(coalesced.length, 2);
    expect(coalesced.first.isAlbum, isTrue);
    expect(coalesced.first.albumSlides.map((e) => e.id).toList(), ['s2', 's1']);
    expect(coalesced.last.id, 'solo');
  });
}
