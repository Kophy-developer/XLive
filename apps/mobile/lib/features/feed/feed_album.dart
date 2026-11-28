import 'dart:math';

import 'models/feed_models.dart';
import '../social/models/social_models.dart';

const _albumPrefix = '\u2063xlive_album:';
const _albumSuffix = '\u2063';

String newFeedAlbumId() {
  final rand = Random.secure().nextInt(0x7fffffff);
  return '${DateTime.now().microsecondsSinceEpoch}_$rand';
}

String wrapFeedAlbumCaption(String? caption, String albumId) {
  final body = caption?.trim() ?? '';
  return '$_albumPrefix$albumId$_albumSuffix$body';
}

String? feedAlbumIdFromTitle(String? title) {
  final raw = title ?? '';
  if (!raw.startsWith(_albumPrefix)) return null;
  final idStart = _albumPrefix.length;
  final end = raw.indexOf(_albumSuffix, idStart);
  if (end <= idStart) return null;
  final id = raw.substring(idStart, end);
  return id.isEmpty ? null : id;
}

String stripFeedAlbumMarker(String title) {
  final id = feedAlbumIdFromTitle(title);
  if (id == null) return title;
  final marker = '$_albumPrefix$id$_albumSuffix';
  final rest = title.replaceFirst(marker, '').trim();
  return rest.isEmpty ? 'Untitled' : rest;
}

bool _isAlbumMediaCandidate(FeedItem item) {
  if (item.type == FeedContentType.stream || item.id.isEmpty) return false;
  if (item.isImage) return true;
  final media = item.mediaType?.toLowerCase();
  if (media == 'video' || media == 'image') return true;
  return item.type == FeedContentType.video || item.type == FeedContentType.clip;
}

List<String> feedSaveTargetIds(FeedItem item) {
  final slides = item.albumSlides.length > 1 ? item.albumSlides : [item];
  final seen = <String>{};
  final ids = <String>[];
  for (final slide in slides) {
    final id = slide.id.trim();
    if (id.isEmpty || !seen.add(id)) continue;
    ids.add(id);
  }
  return ids;
}

List<FeedItem> _uniqueFeedItems(List<FeedItem> items) {
  final seenIds = <String>{};
  final out = <FeedItem>[];
  for (final item in items) {
    if (item.id.isEmpty || seenIds.contains(item.id)) continue;
    seenIds.add(item.id);
    out.add(item);
  }
  return out;
}

List<FeedItem> coalesceFeedAlbums(List<FeedItem> items) {
  if (items.isEmpty) return items;
  final unique = _uniqueFeedItems(items);
  final groups = <String, List<FeedItem>>{};
  for (final item in unique) {
    final albumId = feedAlbumIdFromTitle(item.title);
    if (albumId == null || !_isAlbumMediaCandidate(item)) continue;
    groups.putIfAbsent(albumId, () => []).add(item.withDisplayTitle(stripFeedAlbumMarker(item.title)));
  }
  final emitted = <String>{};
  final out = <FeedItem>[];
  for (final item in unique) {
    final albumId = feedAlbumIdFromTitle(item.title);
    if (albumId != null && _isAlbumMediaCandidate(item)) {
      if (emitted.contains(albumId)) continue;
      emitted.add(albumId);
      final slides = groups[albumId]!;
      if (slides.length == 1) {
        out.add(slides.first);
        continue;
      }
      out.add(slides.first.copyWithAlbumSlides(slides));
      continue;
    }
    out.add(item.withDisplayTitle(stripFeedAlbumMarker(item.title)));
  }
  return out;
}

List<FeedItem> filterOutSavedLives(List<FeedItem> items) {
  return items.where((e) => !e.isSavedOrEndedStream).toList();
}

List<ContentItem> coalesceContentAlbums(List<ContentItem> items) {
  if (items.isEmpty) return items;
  final asFeed = items
      .map(
        (c) => FeedItem(
          id: c.id,
          type: c.type,
          title: c.title,
          thumbnailUrl: c.thumbnailUrl,
          mediaType: c.mediaType,
          viewCount: c.viewCount,
          likeCount: c.likeCount,
          commentCount: c.commentCount,
          creatorId: c.creatorId,
          creatorName: c.creatorName,
          createdAt: c.createdAt,
          accessAllowed: !c.isLocked,
          needsPurchase: c.isLocked,
          needsUnlock: c.isLocked,
        ),
      )
      .toList();
  final coalesced = coalesceFeedAlbums(asFeed);
  ContentItem mapOne(FeedItem f) {
    final slides = f.albumSlides.map(mapOne).toList();
    return ContentItem(
      id: f.id,
      type: f.type,
      title: f.title,
      thumbnailUrl: f.thumbnailUrl,
      mediaType: f.mediaType,
      viewCount: f.viewCount,
      likeCount: f.likeCount,
      commentCount: f.commentCount,
      isLocked: f.isLocked,
      creatorId: f.creatorId,
      creatorName: f.creatorName,
      createdAt: f.createdAt,
      albumSlides: slides,
    );
  }
  return coalesced.map(mapOne).toList();
}
