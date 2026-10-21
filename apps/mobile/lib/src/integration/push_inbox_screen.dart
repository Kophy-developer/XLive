import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_json.dart';
import '../../core/notifications/in_app_notification_store.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../features/notifications/notifications_repository.dart';
import '../../features/streams/models/stream_models.dart';
import '../chats/dm_chat_screen.dart';
import '../chats/group_chat_screen.dart';
import '../live/live_stream_flow.dart';
import '../live/widgets/stream_invite_dialog.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _light = Color(0xFFF6F6F6);

class PushInboxScreen extends StatefulWidget {
  const PushInboxScreen({super.key});

  @override
  State<PushInboxScreen> createState() => _PushInboxScreenState();
}

class _PushInboxScreenState extends State<PushInboxScreen> {
  final _notificationsRepo = NotificationsRepository();
  final _store = InAppNotificationStore.instance;
  final _push = PushNotificationService.instance;
  bool _pushLoading = true;
  bool _syncing = false;
  bool? _pushEnabled;
  String? _pushError;

  @override
  void initState() {
    super.initState();
    _store.bindSocket();
    _store.addListener(_onStoreChanged);
    _push.addListener(_onPushChanged);
    _loadPushStatus();
    _store.hydrateFromApi().then((_) {
      if (mounted) setState(() {});
    });
    if (_push.snapshot.signedIn) {
      unawaited(_resync(silent: true));
    }
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _push.removeListener(_onPushChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  void _onPushChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _resync({bool silent = false}) async {
    if (_syncing) return;
    setState(() => _syncing = true);
    final snap = await _push.syncRegistration(force: true);
    if (!mounted) return;
    setState(() {
      _syncing = false;
      _pushEnabled = snap.serverEnabled ?? _pushEnabled;
    });
    if (!silent && mounted) {
      final ok = snap.registered && snap.lastError == null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Device registered for push (${snap.tokenPreview ?? 'token ok'})'
                : (snap.lastError ?? 'Push registration failed'),
          ),
        ),
      );
    }
  }

  Future<void> _testLocal() async {
    try {
      await _push.showLocalTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Local test notification sent')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  void _copyTokenPreview() {
    final token = _push.snapshot.tokenPreview;
    if (token == null || token.isEmpty) return;
    Clipboard.setData(ClipboardData(text: token));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Token preview copied')),
    );
  }

  Future<void> _openEvent(InAppNotification event) async {
    final payload = event.payload;
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

  Future<void> _loadPushStatus() async {
    setState(() {
      _pushLoading = true;
      _pushError = null;
    });
    try {
      final status = await _notificationsRepo.getStatus();
      if (!mounted) return;
      setState(() {
        _pushEnabled = status.enabled;
        _pushLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pushLoading = false;
        _pushError = friendlyApiMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final events = _store.events;
    final snap = _push.snapshot;
    return XLiveSubpage(
      title: 'Notifications',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _light,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x1A0A0A0A)),
              ),
              child: _pushLoading
                  ? const Row(
                      children: [
                        SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Checking push status…'),
                      ],
                    )
                  : _pushError != null
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_pushError!, style: TextStyle(color: Colors.grey.shade800)),
                            TextButton(onPressed: _loadPushStatus, child: const Text('Retry')),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _pushEnabled == true ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                                  color: _pushEnabled == true ? _purple : Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _pushEnabled == true ? 'Push notifications enabled' : 'Push notifications disabled',
                                    style: const TextStyle(fontWeight: FontWeight.w600, color: _black),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            _diagLine('Firebase', snap.firebaseReady ? 'ready' : 'not ready'),
                            _diagLine('Service', snap.serviceReady ? 'ready' : 'not ready'),
                            _diagLine('Signed in', snap.signedIn ? 'yes' : 'no'),
                            _diagLine('Permission', snap.permission),
                            _diagLine('Device registered', snap.registered ? 'yes' : 'no'),
                            _diagLine('Token', snap.tokenPreview ?? 'none'),
                            if (snap.lastError != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                snap.lastError!,
                                style: TextStyle(color: Colors.red.shade700, height: 1.35),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                FilledButton(
                                  onPressed: _syncing ? null : () => _resync(),
                                  style: FilledButton.styleFrom(backgroundColor: _purple),
                                  child: Text(_syncing ? 'Registering…' : 'Register device'),
                                ),
                                OutlinedButton(
                                  onPressed: _testLocal,
                                  child: const Text('Test local alert'),
                                ),
                                if (snap.tokenPreview != null)
                                  TextButton(
                                    onPressed: _copyTokenPreview,
                                    child: const Text('Copy token preview'),
                                  ),
                              ],
                            ),
                          ],
                        ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text('In-app events', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
          ),
          Expanded(
            child: events.isEmpty
                ? const _PushInboxEmptyBody()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: events.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final event = events[i];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openEvent(event),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
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
                                      Text(event.title, style: const TextStyle(fontWeight: FontWeight.w700, color: _black)),
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

  Widget _diagLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _black)),
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
            Text('No in-app events yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
            const SizedBox(height: 8),
            Text(
              'Live invites, calls, and other socket events will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
