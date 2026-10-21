import 'dart:async';

import 'package:flutter/foundation.dart';

import '../network/api_json.dart';
import '../session/auth_session.dart';
import '../socket/xlive_socket_client.dart';
import '../../features/streams/streams_repository.dart';
import 'notification_persistence.dart';

class InAppNotification {
  const InAppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.payload = const {},
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String? body;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        if (body != null) 'body': body,
        'payload': payload,
        'createdAt': createdAt.toIso8601String(),
      };

  factory InAppNotification.fromJson(Map<String, dynamic> json) {
    return InAppNotification(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? 'event',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString(),
      payload: json['payload'] is Map ? Map<String, dynamic>.from(json['payload'] as Map) : const {},
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class InAppNotificationStore extends ChangeNotifier {
  InAppNotificationStore._();

  static final InAppNotificationStore instance = InAppNotificationStore._();

  static const _maxItems = 100;

  final List<InAppNotification> _items = [];
  final List<StreamSubscription<Map<String, dynamic>>> _subscriptions = [];
  final _persistence = NotificationPersistence();
  bool _bound = false;
  bool _loaded = false;

  List<InAppNotification> get notifications => List.unmodifiable(_items);
  List<InAppNotification> get events => notifications;

  Future<void> loadForCurrentUser() async {
    if (_loaded) return;
    _loaded = true;
    final userId = AuthSession.instance.user?.id;
    final saved = await _persistence.load(userId);
    if (saved.isEmpty) return;
    final existing = _items.map((e) => e.id).toSet();
    for (final item in saved) {
      if (!existing.contains(item.id)) _items.add(item);
    }
    _items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (_items.length > _maxItems) _items.removeRange(_maxItems, _items.length);
    notifyListeners();
  }

  Future<void> _persist() async {
    await _persistence.save(AuthSession.instance.user?.id, _items);
  }

  void bindSocket() {
    if (_bound) return;
    _bound = true;
    loadForCurrentUser();
    final socket = XLiveSocketClient.instance;
    _subscriptions.addAll([
      socket.onStreamInviteIncoming.listen((data) => _ingest('stream_invite_incoming', data)),
      socket.onDmCallIncoming.listen((data) => _ingest('dm_call_incoming', data)),
      socket.onMessageReceived.listen((data) => _ingest('message_received', data)),
      socket.onStreamInviteAccepted.listen((data) => _ingest('stream_invite_accepted', data)),
      socket.onStreamInviteDeclined.listen((data) => _ingest('stream_invite_declined', data)),
      socket.onGiftSent.listen((data) => _ingest('gift_sent', data)),
      socket.onStreamEnded.listen((data) => _ingest('stream_ended', data)),
      socket.onGroupCallStarted.listen((data) => _ingest('group_call_started', data)),
      socket.onDmCallEnded.listen((data) => _ingest('dm_call_ended', data)),
    ]);
  }

  Future<void> hydrateFromApi() async {
    try {
      final invites = await StreamsRepository().myInvites(limit: 20);
      for (final invite in invites) {
        if (invite.status?.toLowerCase() == 'accepted' || invite.status?.toLowerCase() == 'declined') continue;
        _ingest(
          'stream_invite_incoming',
          {
            'inviteId': invite.id,
            'streamId': invite.streamId,
            'title': invite.streamTitle,
            'hostName': invite.hostName,
            'status': invite.status,
            'hydrated': true,
          },
        );
      }
    } catch (_) {}
  }

  void ingestRemotePush({
    required String title,
    String? body,
    Map<String, dynamic> data = const {},
  }) {
    final type = data['type']?.toString() ?? 'push';
    _ingest(type, {
      ...data,
      'title': title,
      'body': ?body,
    });
  }

  void unbindSocket() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
    _bound = false;
  }

  void _ingest(String type, Map<String, dynamic> data) {
    final id = _resolveId(type, data);
    if (_items.any((item) => item.id == id)) return;

    final title = _resolveTitle(type, data);
    final body = _resolveBody(type, data);
    final createdAt = _resolveCreatedAt(data);

    _items.insert(
      0,
      InAppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        payload: Map<String, dynamic>.from(data),
        createdAt: createdAt,
      ),
    );
    if (_items.length > _maxItems) {
      _items.removeRange(_maxItems, _items.length);
    }
    notifyListeners();
    _persist();
  }

  String _resolveId(String type, Map<String, dynamic> data) {
    final direct = ApiJson.pickString(data, [
      'id',
      '_id',
      'notificationId',
      'inviteId',
      'callId',
      'messageId',
      'streamId',
    ]);
    if (direct != null) return '$type:$direct';
    final invite = ApiJson.map(data['invite']);
    if (invite != null) {
      final inviteId = ApiJson.pickString(invite, ['id', '_id', 'inviteId']);
      if (inviteId != null) return '$type:$inviteId';
    }
    final call = ApiJson.map(data['call']);
    if (call != null) {
      final callId = ApiJson.pickString(call, ['id', '_id', 'callId']);
      if (callId != null) return '$type:$callId';
    }
    return '$type:${DateTime.now().microsecondsSinceEpoch}';
  }

  String _resolveTitle(String type, Map<String, dynamic> data) {
    final explicit = ApiJson.pickString(data, ['title', 'headline', 'subject']);
    if (explicit != null) return explicit;
    switch (type) {
      case 'stream_invite_incoming':
        final stream = ApiJson.map(data['stream']);
        final host = ApiJson.pickString(data, ['hostName', 'callerName']);
        final title = ApiJson.pickString(stream ?? data, ['title', 'name']);
        if (host != null && title != null) return '$host invited you to $title';
        if (title != null) return 'Live invite: $title';
        return 'Live invite';
      case 'dm_call_incoming':
        return ApiJson.pickString(data, ['callerName', 'displayName', 'name']) ?? 'Incoming call';
      case 'message_received':
        return ApiJson.pickString(data, ['senderName', 'displayName']) ?? 'New message';
      case 'unread_updated':
        return 'Unread updated';
      case 'stream_invite_accepted':
        return 'Invite accepted';
      case 'stream_invite_declined':
        return 'Invite declined';
      case 'gift_sent':
        return ApiJson.pickString(data, ['senderName', 'giftName']) ?? 'Gift received';
      case 'stream_ended':
        return 'Stream ended';
      case 'group_call_started':
        return ApiJson.pickString(data, ['groupName', 'title']) ?? 'Group call started';
      case 'dm_call_ended':
        return 'Call ended';
      default:
        return type.replaceAll('_', ' ');
    }
  }

  String? _resolveBody(String type, Map<String, dynamic> data) {
    final explicit = ApiJson.pickString(data, ['body', 'subtitle', 'description', 'content', 'preview']);
    if (explicit != null) return explicit;
    if (type == 'message_received') {
      return ApiJson.pickString(data, ['content', 'text']);
    }
    if (type == 'unread_updated') {
      final total = ApiJson.pickInt(data, ['total', 'totalUnread', 'count']);
      return total > 0 ? '$total unread' : null;
    }
    return null;
  }

  DateTime _resolveCreatedAt(Map<String, dynamic> data) {
    final raw = ApiJson.pickString(data, ['createdAt', 'timestamp', 'receivedAt']);
    return DateTime.tryParse(raw ?? '') ?? DateTime.now();
  }

  void clear() {
    _items.clear();
    notifyListeners();
    _persistence.clear(AuthSession.instance.user?.id);
  }

  void removeById(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
    _persist();
  }

  void resetForSignOut() {
    _items.clear();
    _loaded = false;
    notifyListeners();
  }

  @override
  void dispose() {
    unbindSocket();
    super.dispose();
  }
}
