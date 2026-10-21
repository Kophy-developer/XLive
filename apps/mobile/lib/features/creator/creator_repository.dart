import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../clips/models/clip_models.dart';
import 'models/creator_models.dart';

class CreatorRepository {
  CreatorRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<CreatorEarnings> getEarnings({String range = 'month'}) async {
    final json = await _client.apiGet(
      '/api/x-live/settings/creator/earnings',
      query: {'range': range},
    );
    return CreatorEarnings.fromJson(json);
  }

  Future<List<WithdrawalMethod>> listWithdrawalMethods() async {
    final json = await _client.apiGet('/api/x-live/settings/creator/withdrawal-methods');
    return ApiJson.listItems(json).map(WithdrawalMethod.fromJson).where((m) => m.id.isNotEmpty).toList();
  }

  Future<WithdrawalMethod> createBankWithdrawalMethod({
    required String accountName,
    required String bankName,
    required String accountNumber,
    String routingNumber = '000000000',
    bool isDefault = true,
  }) async {
    final json = await _client.apiPost(
      '/api/x-live/settings/creator/withdrawal-methods',
      body: {
        'type': 'bank',
        'isDefault': isDefault,
        'accountName': accountName,
        'bankName': bankName,
        'accountNumber': accountNumber.replaceAll(' ', ''),
        'routingNumber': routingNumber,
      },
    );
    return WithdrawalMethod.fromJson(ApiJson.dataMap(json));
  }

  Future<void> createWithdrawalRequest({required double amount, required String methodId}) async {
    await _client.apiPost(
      '/api/x-live/settings/creator/withdrawals',
      body: {'amount': amount, 'methodId': methodId},
    );
  }

  Future<CreatorAnalytics> getAnalytics({String range = 'month'}) async {
    final json = await _client.apiGet(
      '/api/x-live/settings/creator/analytics',
      query: {'range': range},
    );
    return CreatorAnalytics.fromJson(json);
  }

  Future<CreatorSettings> getCreatorSettings() async {
    final json = await _client.apiGet('/api/x-live/settings/creator');
    return CreatorSettings.fromJson(json);
  }

  Future<CreatorSettings> updateCreatorSettings(CreatorSettings settings) async {
    final json = await _client.apiPatch('/api/x-live/settings/creator', body: settings.toPatchJson());
    return CreatorSettings.fromJson(json);
  }

  Future<List<ClipSummary>> listArchivedClips({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/settings/creator/clips/archived',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(ClipSummary.fromJson).where((c) => c.id.isNotEmpty).toList();
  }

  Future<List<WithdrawalRecord>> listWithdrawals({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/settings/creator/withdrawals',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(WithdrawalRecord.fromJson).where((w) => w.id.isNotEmpty).toList();
  }

  Future<WithdrawalMethod> updateWithdrawalMethod(
    String methodId, {
    String? accountName,
    String? bankName,
    String? accountNumber,
    bool? isDefault,
  }) async {
    final body = <String, dynamic>{};
    if (accountName != null) body['accountName'] = accountName;
    if (bankName != null) body['bankName'] = bankName;
    if (accountNumber != null) body['accountNumber'] = accountNumber.replaceAll(' ', '');
    if (isDefault != null) body['isDefault'] = isDefault;
    final json = await _client.apiPatch('/api/x-live/settings/creator/withdrawal-methods/$methodId', body: body);
    return WithdrawalMethod.fromJson(ApiJson.dataMap(json));
  }

  Future<void> deleteWithdrawalMethod(String methodId) async {
    await _client.apiDelete('/api/x-live/settings/creator/withdrawal-methods/$methodId');
  }
}
