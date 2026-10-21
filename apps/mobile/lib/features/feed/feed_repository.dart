import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../core/network/api_json.dart';
import '../social/social_repository.dart';
import '../streams/streams_repository.dart';
import '../social/models/social_models.dart';
import 'models/feed_models.dart';

class FeedRepository {
  FeedRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static final Map<String, List<FeedItem>> _firstPageCache = {};
  static final Map<String, UserPublicProfile> _creatorCache = {};

  List<FeedItem>? cachedFirstPage(String key) => _firstPageCache[key];

  static void clearCache() {
    _firstPageCache.clear();
  }

  List<FeedItem> _mergeFresh(List<FeedItem> base, List<FeedItem> extra) {
    final seen = {for (final item in base) item.id};
    final fresh = extra.where((item) => item.id.isNotEmpty && !seen.contains(item.id)).toList()
      ..sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    return [...fresh, ...base];
  }

  Future<List<FeedItem>> _latestVideos({int limit = 24}) async {
    try {
      final json = await _client.apiGet(
        '/api/x-live/videos',
        query: {'page': '1', 'limit': '$limit'},
      );
      return _parseFeed(json);
    } catch (_) {
      return const [];
    }
  }

  Future<List<FeedItem>> _ownContent() async {
    final userId = AuthSession.instance.user?.id;
    if (userId == null || userId.isEmpty) return const [];
    try {
      final json = await _client.apiGet(
        '/api/x-live/users/$userId/content',
        query: {'page': '1', 'limit': '24'},
      );
      return _parseFeed(json);
    } catch (_) {
      return const [];
    }
  }

  void _cacheFirstPage(String key, int page, List<FeedItem> items) {
    if (page == 1) _firstPageCache[key] = items;
  }

  List<FeedItem> _parseFeed(Map<String, dynamic> json) {
    return ApiJson.listItems(json).map(FeedItem.fromJson).where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<FeedItem>> enrichCreators(List<FeedItem> items) => _enrichCreators(items);

  Future<List<FeedItem>> _enrichCreators(List<FeedItem> items) async {
    final social = SocialRepository(client: _client);
    final ids = items
        .map((item) => item.creatorId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .where((id) => !items.any((item) => item.creatorId == id && (item.creatorName?.isNotEmpty ?? false)))
        .toSet();
    final missing = ids.where((id) => !_creatorCache.containsKey(id)).toList();
    await Future.wait(missing.map((id) async {
      try {
        _creatorCache[id] = await social.getProfile(id);
      } catch (_) {}
    }));
    return items.map((item) {
      final profile = item.creatorId == null ? null : _creatorCache[item.creatorId!];
      if (profile == null) return item;
      return item.copyWith(
        creatorName: item.creatorName ?? profile.name,
        creatorAvatarUrl: item.creatorAvatarUrl ?? profile.avatarUrl,
        creatorIsLive: profile.isLive,
      );
    }).toList();
  }

  Future<List<FeedItem>> getForYou({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/feed/for-you',
      query: {'page': '$page', 'limit': '$limit'},
      auth: AuthSession.instance.isSignedIn,
    );
    var items = _parseFeed(json);
    if (page == 1) {
      final latest = await _latestVideos(limit: 24);
      final mine = await _ownContent();
      items = _mergeFresh(items, [...latest, ...mine]);
    }
    _cacheFirstPage('for-you', page, items);
    return items;
  }

  String? _followTargetId(Map<String, dynamic> row) {
    for (final key in ['user', 'followed', 'following', 'followee', 'target', 'profile']) {
      final nested = row[key];
      if (nested is Map) {
        final id = ApiJson.pickString(Map<String, dynamic>.from(nested), ['id', '_id', 'userId']);
        if (id != null && id.isNotEmpty) return id;
      }
      if (nested is String && nested.trim().isNotEmpty) return nested.trim();
    }
    return ApiJson.pickString(row, ['followingId', 'followedId', 'followeeId', 'userId', 'id', '_id']);
  }

  Future<List<FeedItem>> _followingFromPeople() async {
    final userId = AuthSession.instance.user?.id;
    if (userId == null || userId.isEmpty) return const [];
    try {
      final json = await _client.apiGet(
        '/api/x-live/follow/$userId/following',
        query: {'page': '1', 'limit': '40'},
        auth: false,
      );
      final ids = <String>{};
      for (final row in ApiJson.listItems(json)) {
        final id = _followTargetId(row);
        if (id != null && id.isNotEmpty && id != userId) ids.add(id);
      }
      if (ids.isEmpty) return const [];
      final batches = await Future.wait(ids.take(20).map((id) async {
        try {
          final content = await _client.apiGet(
            '/api/x-live/users/$id/content',
            query: {'page': '1', 'limit': '12'},
            auth: false,
          );
          return _parseFeed(content);
        } catch (_) {
          return const <FeedItem>[];
        }
      }));
      final merged = <FeedItem>[];
      final seen = <String>{};
      for (final item in batches.expand((list) => list)) {
        if (item.id.isEmpty || seen.contains(item.id)) continue;
        seen.add(item.id);
        merged.add(item);
      }
      merged.sort((a, b) {
        final ta = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final tb = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
      return merged;
    } catch (_) {
      return const [];
    }
  }

  Future<List<FeedItem>> getFollowing({int page = 1, int limit = 20}) async {
    if (!AuthSession.instance.isSignedIn) {
      throw ApiException('Sign in to see posts from people you follow.', statusCode: 401);
    }
    final json = await _client.apiGet(
      '/api/x-live/feed/following',
      query: {'page': '$page', 'limit': '$limit'},
    );
    var items = _parseFeed(json);
    if (page == 1 && items.isEmpty) {
      items = await _followingFromPeople();
    }
    _cacheFirstPage('following', page, items);
    return items;
  }

  Future<List<FeedItem>> getClips({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/feed/clips',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    final items = _parseFeed(json);
    _cacheFirstPage('clips', page, items);
    return items;
  }

  Future<List<FeedItem>> getLive({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/feed/live',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    var items = _parseFeed(json).where((item) => item.isStreamLive).toList();
    if (items.isEmpty && page == 1) {
      try {
        final streams = await StreamsRepository(client: _client).listLive(page: page, limit: limit);
        items = streams
            .map(
              (stream) => FeedItem.fromJson({
                '_id': stream.id,
                'hostId': stream.hostId,
                'title': stream.title,
                'caption': stream.caption,
                'status': stream.status,
                'thumbnailUrl': stream.thumbnailUrl,
                'type': 'live',
              }),
            )
            .where((item) => item.isStreamLive)
            .toList();
      } catch (_) {}
    }
    _cacheFirstPage('live', page, items);
    return items;
  }

  Future<List<FeedItem>> getCategoryFeed(String categorySlug, {int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/feed/category/$categorySlug',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(FeedItem.fromJson).where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<FeedItem>> followersFeed({int page = 1, int limit = 20}) async {
    if (!AuthSession.instance.isSignedIn) {
      throw ApiException('Sign in to see posts from people you follow.', statusCode: 401);
    }
    final json = await _client.apiGet(
      '/api/x-live/feed/followers',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(FeedItem.fromJson).where((item) => item.id.isNotEmpty).toList();
  }

  Future<List<FeedItem>> categoryFeed(String categorySlug, {int page = 1, int limit = 20}) =>
      getCategoryFeed(categorySlug, page: page, limit: limit);

  Future<void> recordInteraction({
    required String action,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? metadata,
  }) async {
    await _client.apiPost(
      '/api/x-live/feed/interactions',
      body: {
        'action': action,
        'targetType': targetType,
        'targetId': targetId,
        if (metadata != null) 'metadata': metadata,
      },
    );
  }
}
