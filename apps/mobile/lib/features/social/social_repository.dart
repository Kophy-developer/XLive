import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../../core/social/comment_emoji.dart';
import '../feed/models/feed_models.dart';
import '../users/models/user_models.dart';
import 'models/social_models.dart';

class SocialRepository {
  SocialRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<UserPublicProfile> getProfile(String userId) async {
    final json = await _client.apiGet('/api/x-live/users/$userId/profile');
    return UserPublicProfile.fromJson(json);
  }

  Future<List<ContentItem>> getUserContent(
    String userId, {
    String tab = 'all',
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _client.apiGet(
      '/api/x-live/users/$userId/content',
      query: {'tab': tab, 'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(ContentItem.fromJson).where((item) => item.id.isNotEmpty).toList();
  }

  Future<void> follow(String userId) async {
    await _client.apiPost('/api/x-live/follow/follow', body: {'userId': userId, 'followingId': userId});
  }

  Future<void> unfollow(String userId) async {
    await _client.apiPost('/api/x-live/follow/unfollow', body: {'userId': userId, 'followingId': userId});
  }

  Future<List<CommentItem>> listComments({
    required String targetType,
    required String targetId,
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _client.apiGet(
      '/api/x-live/comments',
      query: {
        'targetType': targetType,
        'targetId': targetId,
        'page': '$page',
        'limit': '$limit',
      },
    );
    return _flattenComments(
      ApiJson.listItems(json).map(CommentItem.fromJson).where((item) => item.id.isNotEmpty).toList(),
    );
  }

  List<CommentItem> _flattenComments(List<CommentItem> roots) {
    final out = <CommentItem>[];
    void walk(CommentItem c, String? forcedParent) {
      final node = forcedParent == null || (c.parentId != null && c.parentId!.isNotEmpty)
          ? c
          : CommentItem(
              id: c.id,
              content: c.content,
              authorId: c.authorId,
              authorName: c.authorName,
              authorAvatarUrl: c.authorAvatarUrl,
              createdAt: c.createdAt,
              replyCount: c.replyCount,
              parentId: forcedParent,
            );
      out.add(node);
      for (final reply in c.replies) {
        walk(reply, c.id);
      }
    }
    for (final c in roots) {
      walk(c, null);
    }
    return out;
  }

  static final Map<String, int> _commentCountCache = {};

  static String _commentCountKey(String targetType, String targetId) => '$targetType:$targetId';

  static void rememberCommentCount({
    required String targetType,
    required String targetId,
    required int count,
  }) {
    _commentCountCache[_commentCountKey(targetType, targetId)] = count;
  }

  static int? rememberedCommentCount({
    required String targetType,
    required String targetId,
  }) {
    return _commentCountCache[_commentCountKey(targetType, targetId)];
  }

  Future<int> getCommentCount({
    required String targetType,
    required String targetId,
  }) async {
    final seen = <String>{};
    final all = <CommentItem>[];
    var page = 1;
    const limit = 80;
    while (page <= 40) {
      final batch = await listComments(targetType: targetType, targetId: targetId, page: page, limit: limit);
      var added = 0;
      for (final comment in batch) {
        if (seen.contains(comment.id)) continue;
        seen.add(comment.id);
        all.add(comment);
        added += 1;
      }
      if (added == 0 || batch.length < limit) break;
      page += 1;
    }
    final count = all.where((c) => !isReactionComment(c.content)).length;
    rememberCommentCount(targetType: targetType, targetId: targetId, count: count);
    return count;
  }

  Future<CommentItem> createComment({
    required String targetType,
    required String targetId,
    required String content,
    String? parentId,
  }) async {
    final body = <String, dynamic>{
      'targetType': targetType,
      'targetId': targetId,
      'content': content,
    };
    if (parentId != null && parentId.isNotEmpty) {
      body['parentId'] = parentId;
    }
    final json = await _client.apiPost(
      '/api/x-live/comments',
      body: body,
    );
    final data = ApiJson.dataMap(json);
    return CommentItem.fromJson(data);
  }

  Future<LikeSummary> getLikeSummary({
    required String targetType,
    required String targetId,
  }) async {
    final json = await _client.apiGet(
      '/api/x-live/likes',
      query: {'targetType': targetType, 'targetId': targetId},
      auth: AuthSession.instance.isSignedIn,
    );
    return LikeSummary.fromJson(json);
  }

  Future<void> like({required String targetType, required String targetId}) async {
    await _client.apiPost('/api/x-live/likes', body: {'targetType': targetType, 'targetId': targetId});
  }

  Future<void> unlike({required String targetType, required String targetId}) async {
    await _client.apiDelete(
      '/api/x-live/likes',
      body: {'targetType': targetType, 'targetId': targetId},
    );
  }

  Future<void> deleteComment(String commentId) async {
    await _client.apiDelete('/api/x-live/comments/$commentId');
  }

  Future<List<ContentItem>> getUserCollection(
    String userId, {
    int page = 1,
    int limit = 20,
  }) async {
    final json = await _client.apiGet(
      '/api/x-live/users/$userId/collection',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(ContentItem.fromJson).where((item) => item.id.isNotEmpty).toList();
  }

  Future<MediaDetail> getVideo(String videoId) async {
    final json = await _client.apiGet('/api/x-live/videos/$videoId', auth: false);
    return MediaDetail.fromJson(json, FeedContentType.video);
  }

  Future<MediaDetail> getClip(String clipId) async {
    final json = await _client.apiGet('/api/x-live/clips/$clipId', auth: false);
    return MediaDetail.fromJson(json, FeedContentType.clip);
  }

  Future<MediaDetail> getMediaDetail({
    required String targetType,
    required String targetId,
  }) async {
    if (targetType == 'clip') return getClip(targetId);
    return getVideo(targetId);
  }

  Future<List<XLiveUser>> getFollowers(String userId, {int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/follow/$userId/followers',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(XLiveUser.fromJson).where((u) => u.id.isNotEmpty).toList();
  }

  Future<List<XLiveUser>> getFollowing(String userId, {int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/follow/$userId/following',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(XLiveUser.fromJson).where((u) => u.id.isNotEmpty).toList();
  }
}
