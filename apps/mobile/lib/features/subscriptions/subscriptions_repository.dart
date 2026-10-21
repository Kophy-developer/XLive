import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import 'models/subscription_models.dart';

class SubscriptionsRepository {
  SubscriptionsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CreatorSubscriptionPlan> getPlan(String creatorId) async {
    final json = await _client.apiGet('/api/x-live/subscriptions/plans/$creatorId', auth: false);
    return CreatorSubscriptionPlan.fromJson(ApiJson.dataMap(json));
  }

  Future<CreatorSubscriptionPlan> updatePlan({required int monthlyPrice}) async {
    final json = await _client.apiPut(
      '/api/x-live/subscriptions/plan',
      body: {'monthlyPrice': monthlyPrice},
    );
    return CreatorSubscriptionPlan.fromJson(ApiJson.dataMap(json));
  }

  Future<CreatorSubscriptionPlan> updateMonthlyPrice({
    required String creatorId,
    required int monthlyPrice,
  }) async {
    return updatePlan(monthlyPrice: monthlyPrice);
  }

  Future<MySubscription> subscribe(String creatorId) async {
    final json = await _client.apiPost('/api/x-live/subscriptions/$creatorId/subscribe');
    return MySubscription.fromJson(ApiJson.dataMap(json));
  }

  Future<void> cancel(String creatorId) async {
    await _client.apiDelete('/api/x-live/subscriptions/cancel', body: {'creatorId': creatorId});
  }

  Future<List<MySubscription>> listMine({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/subscriptions/mine',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(MySubscription.fromJson).where((s) => s.id.isNotEmpty).toList();
  }
}
