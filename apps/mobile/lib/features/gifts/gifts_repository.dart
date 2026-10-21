import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import 'models/gift_models.dart';

class GiftsRepository {
  GiftsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<List<GiftCatalogItem>> getCatalog() async {
    final json = await _client.apiGet('/api/x-live/gifts/catalog', auth: false);
    return ApiJson.listItems(json).map(GiftCatalogItem.fromJson).where((g) => g.id.isNotEmpty && g.active).toList();
  }

  Future<ReceivedGiftsPage> receivedGifts({int page = 1, int limit = 100}) async {
    final json = await _client.apiGet(
      '/api/x-live/gifts/me/received',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ReceivedGiftsPage.fromJson(json, sent: false);
  }

  Future<ReceivedGiftsPage> sentGifts({int page = 1, int limit = 100}) async {
    final json = await _client.apiGet(
      '/api/x-live/gifts/me/sent',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ReceivedGiftsPage.fromJson(json, sent: true);
  }

  Future<GiftSendResult> sendGift({
    required String streamId,
    required String giftId,
    int quantity = 1,
  }) async {
    final json = await _client.apiPost(
      '/api/x-live/gifts/send',
      body: {
        'streamId': streamId,
        'giftId': giftId,
        'quantity': quantity,
      },
    );
    return GiftSendResult.fromJson(json);
  }
}
