import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';

class NotificationPushStatus {
  const NotificationPushStatus({this.enabled = false, this.configured = false});

  final bool enabled;
  final bool configured;
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.readAt,
    this.data = const {},
    this.targetUrl,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final String? readAt;
  final Map<String, dynamic> data;
  final String? targetUrl;

  bool get isUnread => readAt == null || readAt!.isEmpty;

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    final dataRaw = json['data'];
    final data = dataRaw is Map ? Map<String, dynamic>.from(dataRaw) : <String, dynamic>{};
    return InboxNotification(
      id: (ApiJson.pickString(json, ['id', '_id']) ?? '').trim(),
      type: (ApiJson.pickString(json, ['type']) ?? data['type']?.toString() ?? '').trim(),
      title: (ApiJson.pickString(json, ['title', 'subject']) ?? 'Notification').trim(),
      body: ApiJson.pickString(json, ['body', 'message', 'content']),
      readAt: ApiJson.pickString(json, ['readAt']),
      data: data,
      targetUrl: ApiJson.pickString(json, ['targetUrl', 'url', 'link']),
    );
  }
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

  Future<int> unreadCount() async {
    final json = await _client.apiGet('/api/x-live/notifications/unread-count');
    final data = ApiJson.dataMap(json);
    return ApiJson.pickInt(data, ['count', 'unreadCount', 'total', 'unread']);
  }

  Future<InboxNotification?> getNotification(String id) async {
    if (id.trim().isEmpty) return null;
    final json = await _client.apiGet('/api/x-live/notifications/$id');
    final parsed = InboxNotification.fromJson(ApiJson.dataMap(json));
    return parsed.id.isEmpty ? null : parsed;
  }

  Future<List<InboxNotification>> listInbox({int page = 1, int limit = 30}) async {
    final json = await _client.apiGet(
      '/api/x-live/notifications',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(InboxNotification.fromJson).where((n) => n.id.isNotEmpty).toList();
  }

  Future<void> markRead(String id) async {
    await _client.apiPost('/api/x-live/notifications/$id/read');
  }

  Future<void> markAllRead() async {
    await _client.apiPost('/api/x-live/notifications/read-all');
  }
}
