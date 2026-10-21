import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../../core/media/media_url_cache.dart';
import 'models/clip_models.dart';

class ClipsRepository {
  ClipsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ClipSummary> createClip({
    required String sourceType,
    required String sourceId,
    required int startMs,
    required int endMs,
    String? title,
    int? price,
    bool? isCollectible,
  }) async {
    final body = <String, dynamic>{
      'sourceType': sourceType,
      'sourceId': sourceId,
      'startMs': startMs,
      'endMs': endMs,
    };
    if (title != null) body['title'] = title;
    if (price != null) body['price'] = price;
    if (isCollectible != null) body['isCollectible'] = isCollectible;
    final json = await _client.apiPost('/api/x-live/clips', body: body);
    return ClipSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<ClipSummary> createCollectible({
    required String filePath,
    required String filename,
    required String name,
    String? description,
    required int price,
    int maxSupply = 1,
  }) async {
    final fields = <String, String>{
      'name': name,
      'title': name,
      'price': '$price',
      'maxSupply': '${maxSupply < 1 ? 1 : maxSupply}',
    };
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) {
      fields['description'] = desc;
      fields['caption'] = desc;
    }
    final json = await _client.apiUploadMultipartFile(
      '/api/x-live/clips/collectible',
      fieldName: 'file',
      filePath: filePath,
      filename: filename,
      fields: fields,
    );
    return ClipSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<List<ClipSummary>> listClips({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet('/api/x-live/clips', query: {'page': '$page', 'limit': '$limit'});
    return ApiJson.listItems(json).map(ClipSummary.fromJson).where((c) => c.id.isNotEmpty).toList();
  }

  Future<ClipSummary> getClip(String clipId) async {
    final json = await _client.apiGet('/api/x-live/clips/$clipId', auth: false);
    return ClipSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<ClipMediaUrl> getMediaUrl(String clipId) async {
    final cached = MediaUrlCache.peek('clip', clipId);
    if (cached != null && (cached.url?.isNotEmpty ?? false)) return cached;
    final json = await _client.apiGet('/api/x-live/clips/$clipId/media');
    final media = ClipMediaUrl.fromJson(json);
    MediaUrlCache.put('clip', clipId, media);
    return media;
  }

  Future<Map<String, dynamic>> getCollectible(String clipId) async {
    final json = await _client.apiGet('/api/x-live/clips/$clipId/collectible', auth: false);
    return ApiJson.dataMap(json);
  }

  Future<ClipSummary> purchaseCollectible(String clipId) async {
    final json = await _client.apiPost('/api/x-live/clips/$clipId/purchase');
    return ClipSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<List<ClipSummary>> listCollection({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/clips/mine/collection',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map((item) {
      final clip = ApiJson.map(item['clip']) ?? item;
      return ClipSummary.fromJson(clip);
    }).where((c) => c.id.isNotEmpty).toList();
  }

  Future<List<ClipMarketplaceListing>> marketplaceResale({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/clips/marketplace/resale',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json)
        .map(ClipMarketplaceListing.fromJson)
        .where((item) => item.ownershipId.isNotEmpty)
        .toList();
  }

  Future<void> purchaseResale(String ownershipId) async {
    await _client.apiPost('/api/x-live/clips/mine/ownership/$ownershipId/purchase-resale');
  }

  Future<OwnedClip> listForResale({required String ownershipId, required int price}) async {
    final json = await _client.apiPost(
      '/api/x-live/clips/mine/ownership/$ownershipId/list-for-resale',
      body: {'price': price},
    );
    final data = ApiJson.dataMap(json);
    return OwnedClip.fromJson({'ownership': data, 'clip': data});
  }

  Future<OwnedClip> cancelResaleListing(String ownershipId) async {
    final json = await _client.apiDelete('/api/x-live/clips/mine/ownership/$ownershipId/list-for-resale');
    final data = ApiJson.dataMap(json);
    return OwnedClip.fromJson({'ownership': data, 'clip': data});
  }

  Future<List<OwnedClip>> listOwned({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/clips/mine/owned',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(OwnedClip.fromJson).where((c) => c.ownershipId.isNotEmpty).toList();
  }

  Future<List<ClipSummary>> listCreated({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/clips/mine/created',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(ClipSummary.fromJson).where((c) => c.id.isNotEmpty).toList();
  }

  Future<List<ClipOwner>> listOwners(String clipId, {int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/clips/$clipId/owners',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(ClipOwner.fromJson).where((o) => o.userId.isNotEmpty).toList();
  }

  Future<ClipEarnings> getEarnings(String clipId) async {
    final json = await _client.apiGet(
      '/api/x-live/clips/mine/earnings',
      query: {'clipId': clipId},
    );
    return ClipEarnings.fromJson(json, clipId: clipId);
  }

  Future<ClipEarnings> getMyClipEarnings() async {
    final json = await _client.apiGet('/api/x-live/clips/mine/earnings');
    return ClipEarnings.fromJson(json);
  }

  Future<ClipSummary> archiveClip(String clipId) async {
    final json = await _client.apiPost('/api/x-live/clips/$clipId/archive');
    return ClipSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<ClipSummary> updateClip(
    String clipId, {
    String? title,
    int? price,
    bool? isCollectible,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (price != null) body['price'] = price;
    if (isCollectible != null) body['isCollectible'] = isCollectible;
    final json = await _client.apiPatch('/api/x-live/clips/$clipId', body: body);
    return ClipSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<void> deleteClip(String clipId) async {
    await _client.apiDelete('/api/x-live/clips/$clipId');
  }
}
