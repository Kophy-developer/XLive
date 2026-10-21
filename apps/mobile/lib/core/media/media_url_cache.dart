import '../../features/clips/clips_repository.dart';
import '../../features/clips/models/clip_models.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/social/social_repository.dart';
import '../../features/videos/videos_repository.dart';
import 'media_url.dart';

class MediaUrlCache {
  MediaUrlCache._();

  static const _maxEntries = 64;
  static final Map<String, ClipMediaUrl> _entries = {};
  static final List<String> _order = [];

  static String _key(String targetType, String id) => '$targetType:$id';

  static ClipMediaUrl? peek(String targetType, String id) {
    final key = _key(targetType, id);
    final entry = _entries[key];
    if (entry == null) return null;
    final expires = entry.expiresAt;
    if (expires != null && expires.isBefore(DateTime.now())) {
      _entries.remove(key);
      _order.remove(key);
      return null;
    }
    return entry;
  }

  static String? resolved(String targetType, String id, {String? resourceType}) {
    final url = resolveMediaUrl(peek(targetType, id)?.url, resourceType: resourceType);
    return url.isEmpty ? null : url;
  }

  static void put(String targetType, String id, ClipMediaUrl value) {
    final key = _key(targetType, id);
    if (_entries.containsKey(key)) _order.remove(key);
    _entries[key] = value;
    _order.add(key);
    while (_order.length > _maxEntries) {
      final oldest = _order.removeAt(0);
      _entries.remove(oldest);
    }
  }

  static void invalidate(String targetType, String id) {
    final key = _key(targetType, id);
    _entries.remove(key);
    _order.remove(key);
  }

  static Future<ClipMediaUrl> fetch(String targetType, String id, {bool force = false}) async {
    if (!force) {
      final cached = peek(targetType, id);
      if (cached != null && (cached.url?.isNotEmpty ?? false)) return cached;
    } else {
      invalidate(targetType, id);
    }
    ClipMediaUrl media;
    try {
      media = targetType == 'clip'
          ? await ClipsRepository().getMediaUrl(id)
          : await VideosRepository().getMediaUrl(id);
    } catch (_) {
      media = const ClipMediaUrl(url: null);
    }
    if (media.url == null || media.url!.isEmpty) {
      try {
        final detail = await SocialRepository().getMediaDetail(targetType: targetType, targetId: id);
        if (detail.streamUrl != null && detail.streamUrl!.isNotEmpty) {
          media = ClipMediaUrl(url: detail.streamUrl);
          put(targetType, id, media);
        }
      } catch (_) {}
    }
    return media;
  }

  static Future<void> prefetchFeedItems(Iterable<FeedItem> items, {int limit = 3}) async {
    final targets = items
        .where((item) =>
            !item.isLocked &&
            !item.isImage &&
            item.type != FeedContentType.stream &&
            item.id.isNotEmpty)
        .take(limit)
        .toList();
    await Future.wait(targets.map((item) async {
      if (peek(item.targetType, item.id) != null) return;
      try {
        await fetch(item.targetType, item.id);
      } catch (_) {}
    }));
  }
}
