import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';

class InsightsRepository {
  InsightsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<Map<String, dynamic>> getVideoInsights(String videoId) async {
    final json = await _client.apiGet('/api/x-live/insights/video/$videoId');
    return ApiJson.dataMap(json);
  }

  Future<Map<String, dynamic>> getClipInsights(String clipId) async {
    final json = await _client.apiGet('/api/x-live/insights/clip/$clipId');
    return ApiJson.dataMap(json);
  }

  Future<Map<String, dynamic>> getInsights({
    required String targetType,
    required String targetId,
  }) async {
    if (targetType == 'clip') return getClipInsights(targetId);
    return getVideoInsights(targetId);
  }
}
