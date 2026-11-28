import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_json.dart';
import '../../core/notifications/in_app_notification_store.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/session/auth_session.dart';
import '../../features/notifications/notifications_repository.dart';
import '../../features/streams/models/stream_models.dart';
import '../chats/dm_chat_screen.dart';
import '../chats/group_chat_screen.dart';
import '../live/live_stream_flow.dart';
import '../live/widgets/stream_invite_dialog.dart';
import '../social/social_api_screens.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);

class PushInboxScreen extends StatefulWidget {
  const PushInboxScreen({super.key});

  @override
  State<PushInboxScreen> createState() => _PushInboxScreenState();
}

class _PushInboxScreenState extends State<PushInboxScreen> {
  final _notificationsRepo = NotificationsRepository();
  final _store = InAppNotificationStore.instance;
  final _push = PushNotificationService.instance;

  @override
  void initState() {
    super.initState();
    _store.bindSocket();
    _store.addListener(_onStoreChanged);
    unawaited(AuthSession.instance.refreshNotificationUnread());
    _store.hydrateFromApi().then((_) {
      if (mounted) setState(() {});
    });
    if (_push.snapshot.signedIn) {
      unawaited(_push.syncRegistration(force: true));
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openEvent(InAppNotification event) async {
    var payload = Map<String, dynamic>.from(event.payload);
    final notificationId =
        ApiJson.pickString(payload, ['notificationId', 'id']) ?? (event.id.startsWith('notif_') ? null : event.id);
    if (notificationId != null && notificationId.isNotEmpty) {
      try {
        final full = await _notificationsRepo.getNotification(notificationId);
        if (full != null) {
          payload = {
            ...payload,
            ...full.data,
            'title': full.title,
            if (full.body != null) 'body': full.body,
            if (full.targetUrl != null) 'targetUrl': full.targetUrl,
            'notificationId': full.id,
          };
        }
      } catch (_) {}
      unawaited(() async {
        try {
          await _notificationsRepo.markRead(notificationId);
          _store.markLocalRead(event.id);
          await AuthSession.instance.refreshNotificationUnread();
        } catch (_) {}
      }());
    }
    if (!mounted) return;
    switch (event.type) {
      case 'stream_invite_incoming':
        final invite = StreamInvite.fromJson(payload);
        if (invite.id.isNotEmpty) {
          await showStreamInviteAcceptDialog(context, invite: invite);
        } else {
          Navigator.pushNamed(context, '/social/stream-invites');
        }
        return;
      case 'stream_invite_accepted':
        final streamId = ApiJson.pickString(payload, ['streamId']) ??
            ApiJson.pickString(ApiJson.map(payload['stream']) ?? const {}, ['id', '_id']);
        final role = (ApiJson.pickString(payload, ['role']) ?? '').toLowerCase();
        if (streamId != null && streamId.isNotEmpty) {
          Navigator.pushNamed(
            context,
            '/live/during',
            arguments: LiveDuringArgs(
              streamId: streamId,
              isCohost: role == 'cohost' || role == 'co-host',
            ),
          );
        } else {
          Navigator.pushNamed(context, '/social/stream-invites');
        }
        return;
      case 'dm_call_incoming':
      case 'message_received':
      case 'group_message_received':
        final chatId = ApiJson.pickString(payload, ['chatId', 'dmChatId']);
        final groupId = ApiJson.pickString(payload, ['groupId']);
        final peerName = ApiJson.pickString(payload, ['senderName', 'displayName', 'peerName', 'name']) ?? 'Chat';
        final peerAvatar = ApiJson.pickString(payload, ['senderAvatarUrl', 'avatarUrl', 'peerAvatarUrl']) ?? '';
        final peerUserId = ApiJson.pickString(payload, ['senderId', 'userId', 'peerUserId']);
        if (groupId != null && groupId.isNotEmpty) {
          final groupName = ApiJson.pickString(payload, ['groupName', 'name']) ?? 'Group';
          final avatar = ApiJson.pickString(payload, ['groupAvatarUrl', 'avatarUrl']) ?? '';
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => GroupChatScreen(groupId: groupId, groupName: groupName, avatarUrl: avatar),
            ),
          );
          return;
        }
        if (chatId != null && chatId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DmChatScreen(
                chatId: chatId,
                peerName: peerName,
                peerAvatarUrl: peerAvatar,
                peerUserId: peerUserId,
              ),
            ),
          );
          return;
        }
        Navigator.pushNamed(context, '/chats');
        return;
      case 'group_call_started':
        final groupId = ApiJson.pickString(payload, ['groupId']);
        if (groupId != null && groupId.isNotEmpty) {
          final groupName = ApiJson.pickString(payload, ['groupName', 'name']) ?? 'Group';
          final avatar = ApiJson.pickString(payload, ['groupAvatarUrl', 'avatarUrl']) ?? '';
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => GroupChatScreen(groupId: groupId, groupName: groupName, avatarUrl: avatar),
            ),
          );
          return;
        }
        Navigator.pushNamed(context, '/chats');
        return;
      case 'gift_sent':
      case 'stream_ended':
        final streamId = ApiJson.pickString(payload, ['streamId', 'id']);
        if (streamId != null && streamId.isNotEmpty) {
          Navigator.pushNamed(context, '/live/during', arguments: LiveDuringArgs(streamId: streamId));
        }
        return;
      default:
        final chatId = ApiJson.pickString(payload, ['chatId', 'dmChatId']);
        final groupId = ApiJson.pickString(payload, ['groupId']);
        final streamId = ApiJson.pickString(payload, ['streamId']);
        if (chatId != null && chatId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => DmChatScreen(
                chatId: chatId,
                peerName: ApiJson.pickString(payload, ['senderName', 'displayName', 'peerName', 'name']) ?? 'Chat',
                peerAvatarUrl: ApiJson.pickString(payload, ['senderAvatarUrl', 'avatarUrl']) ?? '',
                peerUserId: ApiJson.pickString(payload, ['senderId', 'userId', 'peerUserId']),
              ),
            ),
          );
          return;
        }
        if (groupId != null && groupId.isNotEmpty) {
          Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => GroupChatScreen(
                groupId: groupId,
                groupName: ApiJson.pickString(payload, ['groupName', 'name']) ?? 'Group',
                avatarUrl: ApiJson.pickString(payload, ['groupAvatarUrl', 'avatarUrl']) ?? '',
              ),
            ),
          );
          return;
        }
        if (streamId != null && streamId.isNotEmpty) {
          Navigator.pushNamed(context, '/live/during', arguments: LiveDuringArgs(streamId: streamId));
          return;
        }
        if (ApiJson.pickString(payload, ['paymentId']) != null || event.type.contains('wallet')) {
          Navigator.pushNamed(context, '/wallet/xlive');
        }
        return;
    }
  }

  String _formatType(String type) {
    return switch (type) {
      'stream_invite_incoming' => 'Live invite',
      'dm_call_incoming' => 'Incoming call',
      'message_received' => 'Message',
      'stream_invite_accepted' => 'Invite accepted',
      'stream_invite_declined' => 'Invite declined',
      'gift_sent' => 'Gift',
      'stream_ended' => 'Stream ended',
      'group_call_started' => 'Group call',
      'dm_call_ended' => 'Call ended',
      _ => type.replaceAll('_', ' '),
    };
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final events = _store.events;
    return XLiveSubpage(
      title: 'Notifications',
      actions: [
        TextButton(
          onPressed: () async {
            try {
              await _notificationsRepo.markAllRead();
              _store.markAllLocalRead();
              await AuthSession.instance.refreshNotificationUnread();
            } catch (_) {}
          },
          child: const Text('Mark all read'),
        ),
        IconButton(
          tooltip: 'Notification settings',
          onPressed: () => Navigator.pushNamed(context, '/profile/notifications'),
          icon: const Icon(Icons.settings_outlined),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: events.isEmpty
                ? const _PushInboxEmptyBody()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: events.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final event = events[i];
                      final unread = ApiJson.pickString(event.payload, ['readAt']) == null;
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openEvent(event),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: unread ? const Color(0xFFF7F0FF) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [_purple, _sky]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.notifications_none_rounded, color: Colors.white, size: 22),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700, color: _black)),
                                          ),
                                          if (unread)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: const BoxDecoration(color: _purple, shape: BoxShape.circle),
                                            ),
                                        ],
                                      ),
                                      if (event.body != null && event.body!.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(event.body!, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
                                      ],
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(_formatType(event.type), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                          const SizedBox(width: 8),
                                          Text(_formatTime(event.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

}

class _PushInboxEmptyBody extends StatelessWidget {
  const _PushInboxEmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No notifications yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              'Live invites, calls, and other updates will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
