import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';

class NotificationPushStatus {
  const NotificationPushStatus({this.enabled = false, this.configured = false});

  final bool enabled;
  final bool configured;
}

class NotificationsRepository {
  NotificationsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<bool> isPushConfigured() async {
    final status = await getStatus();
    return status.configured || status.enabled;
  }

  Future<NotificationPushStatus> getStatus() async {
    final json = await _client.apiGet('/api/x-live/notifications/status');
    final data = ApiJson.dataMap(json);
    return NotificationPushStatus(
      enabled: ApiJson.boolValue(data['enabled']),
      configured: ApiJson.boolValue(data['configured']),
    );
  }

  Future<void> registerDevice({
    required String token,
    required String platform,
    required String deviceId,
  }) async {
    await _client.apiPost(
      '/api/x-live/notifications/devices',
      body: {
        'token': token,
        'platform': platform,
        'deviceId': deviceId,
      },
    );
  }

  Future<void> removeDevice({required String token}) async {
    await _client.apiDelete('/api/x-live/notifications/devices', body: {'token': token});
  }
}
