import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import 'models/wallet_models.dart';

class WalletRepository {
  WalletRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<WalletInfo> getWallet() async {
    final json = await _client.apiGet('/api/x-live/wallet');
    return WalletInfo.fromJson(json);
  }

  Future<List<WalletTransaction>> listTransactions({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/wallet/transactions',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(WalletTransaction.fromJson).where((t) => t.id.isNotEmpty).toList();
  }

  Future<FundPaymentResult> initiateFund({
    required int amount,
    required String provider,
    String flow = 'sdk',
    String? packageId,
    int? coins,
  }) async {
    final body = <String, dynamic>{
      'amount': amount,
      'provider': provider,
      'flow': flow,
    };
    if (packageId != null && packageId.isNotEmpty) body['packageId'] = packageId;
    if (coins != null && coins > 0) body['coins'] = coins;
    final json = await _client.apiPost(
      '/api/x-live/wallet/fund/initiate',
      body: body,
    );
    return FundPaymentResult.fromJson(json);
  }

  Future<WalletInfo> verifyFund({
    required String paymentId,
    String? paymentIntentId,
    String? reference,
    String? orderId,
  }) async {
    final body = <String, dynamic>{'paymentId': paymentId};
    if (paymentIntentId != null && paymentIntentId.isNotEmpty) body['paymentIntentId'] = paymentIntentId;
    if (reference != null && reference.isNotEmpty) body['reference'] = reference;
    if (orderId != null && orderId.isNotEmpty) body['orderId'] = orderId;
    final json = await _client.apiPost('/api/x-live/wallet/fund/verify', body: body);
    return WalletInfo.fromJson(json);
  }

  Future<Map<String, dynamic>> paymentMethods() async {
    final json = await _client.apiGet('/api/x-live/wallet/payment-methods');
    return ApiJson.dataMap(json);
  }

  Future<Map<String, dynamic>> paymentStatus(String paymentId) async {
    final json = await _client.apiGet('/api/x-live/wallet/fund/payments/$paymentId');
    return ApiJson.dataMap(json);
  }
}
