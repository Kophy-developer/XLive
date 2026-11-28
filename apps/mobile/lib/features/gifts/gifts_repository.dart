import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../users/users_repository.dart';
import 'models/gift_models.dart';

class GiftsRepository {
  GiftsRepository({ApiClient? client, UsersRepository? usersRepo})
      : _client = client ?? ApiClient(),
        _usersRepo = usersRepo ?? UsersRepository();

  final ApiClient _client;
  final UsersRepository _usersRepo;

  Future<List<GiftCatalogItem>> getCatalog() async {
    final json = await _client.apiGet('/api/x-live/gifts/catalog', auth: false);
    return ApiJson.listItems(json).map(GiftCatalogItem.fromJson).where((g) => g.id.isNotEmpty && g.active).toList();
  }

  Future<ReceivedGiftsPage> receivedGifts({int page = 1, int limit = 100}) async {
    final json = await _client.apiGet(
      '/api/x-live/gifts/me/received',
      query: {'page': '$page', 'limit': '$limit'},
    );
    final pageData = ReceivedGiftsPage.fromJson(json, sent: false);
    final gifts = await _enrichReceivedGifts(pageData.gifts);
    return ReceivedGiftsPage(
      gifts: gifts,
      totalValue: pageData.totalValue,
      totalCash: pageData.totalCash,
      totalCount: pageData.totalCount,
      currency: pageData.currency,
    );
  }

  Future<ReceivedGiftsPage> sentGifts({int page = 1, int limit = 100}) async {
    final json = await _client.apiGet(
      '/api/x-live/gifts/me/sent',
      query: {'page': '$page', 'limit': '$limit'},
    );
    final pageData = ReceivedGiftsPage.fromJson(json, sent: true);
    final gifts = await _enrichReceivedGifts(pageData.gifts);
    return ReceivedGiftsPage(
      gifts: gifts,
      totalValue: pageData.totalValue,
      totalCash: pageData.totalCash,
      totalCount: pageData.totalCount,
      currency: pageData.currency,
    );
  }

  Future<List<ReceivedGift>> _enrichReceivedGifts(List<ReceivedGift> rows) async {
    if (rows.isEmpty) return rows;
    List<GiftCatalogItem> catalog = const [];
    try {
      catalog = await getCatalog();
    } catch (_) {}
    final byGiftId = {for (final g in catalog) g.id: g};
    final nameCache = <String, String>{};
    final out = <ReceivedGift>[];
    for (final row in rows) {
      final catalogGift = row.giftId == null ? null : byGiftId[row.giftId];
      var name = row.name.trim();
      if (name.isEmpty || name == 'Gift') {
        name = catalogGift?.name.trim().isNotEmpty == true ? catalogGift!.name : 'Gift';
      }
      var senderName = row.senderName?.trim();
      final senderId = row.senderId?.trim();
      if ((senderName == null || senderName.isEmpty) && senderId != null && senderId.isNotEmpty) {
        final cached = nameCache[senderId];
        if (cached != null) {
          senderName = cached;
        } else {
          try {
            final user = await _usersRepo.getUser(senderId);
            final resolved = user.effectiveDisplayName.trim();
            if (resolved.isNotEmpty && resolved != 'User') {
              senderName = resolved;
              nameCache[senderId] = resolved;
            }
          } catch (_) {}
        }
      }
      out.add(
        row.copyWith(
          name: name,
          iconUrl: catalogGift?.iconUrl ?? row.iconUrl,
          senderName: senderName,
        ),
      );
    }
    return out;
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
