import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../feed/feed_repository.dart';
import '../feed/models/feed_models.dart';

class HashtagItem {
  const HashtagItem({required this.tag, this.postCount = 0});

  final String tag;
  final int postCount;

  factory HashtagItem.fromJson(Map<String, dynamic> json) {
    return HashtagItem(
      tag: ApiJson.pickString(json, ['tag', 'hashtag', 'name']) ?? '',
      postCount: ApiJson.pickInt(json, ['postCount', 'count', 'usageCount']),
    );
  }
}

class HashtagsRepository {
  HashtagsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<HashtagItem>> trending({int limit = 20}) async {
    final json = await _client.apiGet('/api/x-live/hashtags/trending', query: {'limit': '$limit'}, auth: false);
    return ApiJson.listItems(json).map(HashtagItem.fromJson).where((h) => h.tag.isNotEmpty).toList();
  }

  Future<List<HashtagItem>> search(String query, {int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/hashtags/search',
      query: {'q': query, 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(HashtagItem.fromJson).where((h) => h.tag.isNotEmpty).toList();
  }

  Future<List<FeedItem>> feed(String hashtag, {int page = 1, int limit = 20}) async {
    final tag = hashtag.replaceAll('#', '');
    final json = await _client.apiGet(
      '/api/x-live/hashtags/$tag/feed',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    final items = ApiJson.listItems(json).map(FeedItem.fromJson).where((i) => i.id.isNotEmpty).toList();
    return FeedRepository(client: _client).enrichFeedItems(items);
  }
}
