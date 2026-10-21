import 'dart:async';
import 'dart:ui';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../../core/live/agora_call_view.dart';
import '../../core/navigation/app_navigator.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/calls/calls_repository.dart';
import '../../features/calls/models/call_models.dart';
import '../../features/chats/chats_repository.dart';
import '../../features/groups/groups_repository.dart';
import '../../features/streams/models/stream_models.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _red = Color(0xFFFF3B5C);

final Set<String> _selfManagedCallIds = <String>{};
final Set<String> _activeSelfGroupCallGroupIds = <String>{};

List<Widget> dmChatCallActions({
  required BuildContext context,
  required String chatId,
  required String peerName,
  String? peerUserId,
}) {
  return [
    IconButton(
      icon: const Icon(Icons.call_rounded),
      onPressed: () => startDmCall(context, chatId: chatId, peerName: peerName, callType: CallMediaType.audio),
    ),
    IconButton(
      icon: const Icon(Icons.videocam_rounded),
      onPressed: () => startDmCall(context, chatId: chatId, peerName: peerName, callType: CallMediaType.video),
    ),
  ];
}

List<Widget> groupChatCallActions({
  required BuildContext context,
  required String groupId,
  required String groupName,
}) {
  return [
    IconButton(
      icon: const Icon(Icons.videocam_rounded),
      onPressed: () => startGroupCall(context, groupId: groupId, groupName: groupName, callType: CallMediaType.video),
    ),
    IconButton(
      icon: const Icon(Icons.call_rounded),
      onPressed: () => startGroupCall(context, groupId: groupId, groupName: groupName, callType: CallMediaType.audio),
    ),
  ];
}

Future<void> startDmCall(
  BuildContext context, {
  required String chatId,
  required String peerName,
  required CallMediaType callType,
}) async {
  try {
    final session = await CallsRepository().startDmCall(chatId: chatId, callType: callType);
    final me = AuthSession.instance.user;
    XLiveSocketClient.instance.emitDmCallStart(
      chatId: chatId,
      callType: callMediaTypeToApi(callType),
      callId: session.id,
      calleeId: session.calleeId ?? session.peerUserId,
      callerName: me?.displayName ?? me?.username,
      callerAvatar: me?.avatarUrl,
    );
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => DmCallScreen(
          chatId: chatId,
          peerName: peerName,
          callId: session.id,
          isIncoming: false,
          callType: callType,
          initialCredentials: session.credentials,
        ),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyApiMessage(e))),
    );
  }
}

Future<void> ensureGroupCallSocketRooms(String groupId) async {
  if (groupId.isEmpty) return;
  final socket = XLiveSocketClient.instance;
  await socket.joinGroup(groupId);
  await socket.joinGroupChat(groupId);
}

Future<void> joinOngoingGroupCall(
  BuildContext context, {
  required String groupId,
  required String groupName,
  CallMediaType callType = CallMediaType.audio,
}) {
  return startGroupCall(context, groupId: groupId, groupName: groupName, callType: callType);
}

Future<void> startGroupCall(
  BuildContext context, {
  required String groupId,
  required String groupName,
  CallMediaType callType = CallMediaType.video,
}) async {
  try {
    final repo = CallsRepository();
    _activeSelfGroupCallGroupIds.add(groupId);
    final active = await repo.getActiveGroupCall(groupId);
    final CallSession session;
    final bool isHost;
    final CallMediaType resolvedType;
    if (active != null && active.id.isNotEmpty) {
      session = await repo.joinGroupCall(active.id);
      isHost = false;
      resolvedType = active.callType;
      _selfManagedCallIds.add(active.id);
      XLiveSocketClient.instance.emitGroupCallJoin(active.id);
    } else {
      final started = await repo.startGroupCall(groupId: groupId, callType: callType);
      session = await repo.joinGroupCall(started.id);
      isHost = true;
      resolvedType = callType;
      _selfManagedCallIds.add(started.id);
      XLiveSocketClient.instance.emitGroupCallStart(
        groupId: groupId,
        callId: started.id,
        callType: callMediaTypeToApi(callType),
      );
      XLiveSocketClient.instance.emitGroupCallJoin(started.id);
    }
    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GroupCallScreen(
          groupId: groupId,
          groupName: groupName,
          callId: session.id,
          isIncoming: false,
          isHost: isHost,
          callType: resolvedType,
          initialCredentials: session.credentials,
        ),
      ),
    );
  } catch (e) {
    _activeSelfGroupCallGroupIds.remove(groupId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(friendlyApiMessage(e))),
    );
  }
}

sealed class _IncomingPrompt {}

class _DmIncomingPrompt extends _IncomingPrompt {
  _DmIncomingPrompt(this.payload);
  final IncomingCallPayload payload;
}

class _GroupIncomingPrompt extends _IncomingPrompt {
  _GroupIncomingPrompt(this.payload);
  final GroupCallEventPayload payload;
}

class IncomingCallOverlay extends StatefulWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<IncomingCallOverlay> createState() => _IncomingCallOverlayState();
}

class _IncomingCallOverlayState extends State<IncomingCallOverlay> with WidgetsBindingObserver {
  StreamSubscription<Map<String, dynamic>>? _dmIncomingSub;
  StreamSubscription<Map<String, dynamic>>? _groupStartedSub;
  _IncomingPrompt? _prompt;
  final _joinedGroupRooms = <String>{};
  final _joinedGroupChatRooms = <String>{};
  final _handledGroupCallIds = <String>{};
  bool _syncingGroupRooms = false;
  bool _scanningActiveCalls = false;
  Timer? _activeCallPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final socket = XLiveSocketClient.instance;
    socket.addListener(_onSocketClientChanged);
    _activeCallPollTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) {
        _scanActiveGroupCalls();
        _scanActiveDmCalls();
        _checkActivePromptValidity();
      }
    });
    _dmIncomingSub = socket.onDmCallIncoming.listen((data) {
      final payload = IncomingCallPayload.fromJson(data);
      if (payload.callId.isEmpty || payload.groupId != null) return;
      if (_selfManagedCallIds.contains(payload.callId)) return;
      final me = AuthSession.instance.user?.id ?? socket.userId;
      if (payload.peerUserId != null && payload.peerUserId!.isNotEmpty && me != null && payload.peerUserId == me) return;
      _presentPrompt(_DmIncomingPrompt(payload));
    });
    _groupStartedSub = socket.onGroupCallStarted.listen((data) {
      final payload = GroupCallEventPayload.fromJson(data);
      if (payload.callId.isEmpty || payload.groupId.isEmpty) return;
      if (_selfManagedCallIds.contains(payload.callId)) return;
      if (_activeSelfGroupCallGroupIds.contains(payload.groupId)) return;
      if (_handledGroupCallIds.contains(payload.callId)) return;
      final me = AuthSession.instance.user?.id ?? socket.userId;
      final starter = payload.userId;
      if (starter != null && starter.isNotEmpty && me != null && starter == me) return;
      _presentPrompt(_GroupIncomingPrompt(payload));
    });
    _syncGroupSocketRooms();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (!XLiveSocketClient.instance.isConnected) {
        unawaited(XLiveSocketClient.instance.connectIfSignedIn());
      }
      _syncGroupSocketRooms();
      _scanActiveGroupCalls();
      _scanActiveDmCalls();
    }
  }

  void _onSocketClientChanged() {
    _syncGroupSocketRooms();
  }

  Future<void> _syncGroupSocketRooms() async {
    if (!AuthSession.instance.isSignedIn) return;
    if (!XLiveSocketClient.instance.isConnected) return;
    if (_syncingGroupRooms) return;
    _syncingGroupRooms = true;
    try {
      final groups = await GroupsRepository().listMyGroups(limit: 100);
      final socket = XLiveSocketClient.instance;
      for (final group in groups) {
        if (group.id.isEmpty) continue;
        if (!_joinedGroupRooms.contains(group.id)) {
          final ok = await socket.joinGroup(group.id);
          if (ok) _joinedGroupRooms.add(group.id);
        }
        if (!_joinedGroupChatRooms.contains(group.id)) {
          final ok = await socket.joinGroupChat(group.id);
          if (ok) _joinedGroupChatRooms.add(group.id);
        }
      }
    } catch (_) {
    } finally {
      _syncingGroupRooms = false;
    }
    _scanActiveGroupCalls();
  }

  Future<void> _scanActiveGroupCalls() async {
    if (!AuthSession.instance.isSignedIn) return;
    if (_scanningActiveCalls) return;
    if (_prompt != null) return;
    _scanningActiveCalls = true;
    try {
      final repo = CallsRepository();
      final groups = await GroupsRepository().listMyGroups(limit: 100);
      final me = AuthSession.instance.user?.id ?? XLiveSocketClient.instance.userId;
      for (final group in groups) {
        if (group.id.isEmpty) continue;
        if (!mounted || _prompt != null) break;
        final CallSession? active;
        try {
          active = await repo.getActiveGroupCall(group.id);
        } catch (_) {
          continue;
        }
        if (active == null || active.id.isEmpty) continue;
        if (_selfManagedCallIds.contains(active.id)) continue;
        if (_activeSelfGroupCallGroupIds.contains(group.id)) continue;
        if (_handledGroupCallIds.contains(active.id)) continue;
        final starter = active.peerUserId;
        if (starter != null && starter.isNotEmpty && me != null && starter == me) continue;
        _presentPrompt(_GroupIncomingPrompt(GroupCallEventPayload(
          groupId: group.id,
          callId: active.id,
          callType: active.callType,
          groupName: group.name,
        )));
        break;
      }
    } catch (_) {
    } finally {
      _scanningActiveCalls = false;
    }
  }

  Future<void> _checkActivePromptValidity() async {
    final prompt = _prompt;
    if (prompt is! _DmIncomingPrompt) return;
    final chatId = prompt.payload.chatId;
    if (chatId == null || chatId.isEmpty) return;
    try {
      final active = await CallsRepository().getActiveDmCall(chatId);
      if (active == null || active.id != prompt.payload.callId) {
        if (mounted && _prompt == prompt) {
          _dismiss();
        }
      }
    } catch (_) {}
  }

  Future<void> _scanActiveDmCalls() async {
    if (!AuthSession.instance.isSignedIn) return;
    if (_prompt != null) return;
    try {
      final callsRepo = CallsRepository();
      final me = AuthSession.instance.user?.id ?? XLiveSocketClient.instance.userId;

      try {
        final notifRes = await ApiClient().apiGet('/api/x-live/notifications?limit=3');
        final notifList = ApiJson.listItems(notifRes);
        for (final notif in notifList) {
          final type = notif['type']?.toString();
          if (type != 'dm_call' && type != 'call') continue;

          final createdAtStr = notif['createdAt']?.toString();
          if (createdAtStr != null) {
            final created = DateTime.tryParse(createdAtStr);
            if (created != null && DateTime.now().difference(created).inSeconds > 50) continue;
          }

          final data = ApiJson.map(notif['data']) ?? const {};
          final actor = ApiJson.map(notif['actor']) ?? const {};
          final callId = ApiJson.pickString(data, ['callId', 'id']) ?? ApiJson.pickString(notif, ['id', '_id']) ?? '';
          if (callId.isEmpty || _selfManagedCallIds.contains(callId)) continue;

          final chatId = ApiJson.pickString(data, ['chatId', 'dmChatId']) ?? '';
          if (chatId.isEmpty) continue;

          final active = await callsRepo.getActiveDmCall(chatId);
          if (active != null && active.id == callId) {
            final callerId = ApiJson.pickString(data, ['callerId']) ?? ApiJson.pickString(actor, ['id', '_id']);
            if (callerId != null && callerId.isNotEmpty && me != null && callerId == me) continue;

            final callerName = ApiJson.pickString(actor, ['displayName', 'username', 'name']) ?? notif['title']?.toString() ?? 'Incoming call';
            final callerAvatar = ApiJson.pickString(actor, ['avatarUrl', 'avatar']);
            _presentPrompt(_DmIncomingPrompt(IncomingCallPayload(
              callId: callId,
              callType: active.callType,
              chatId: chatId,
              peerName: callerName,
              peerUserId: callerId,
              callerAvatar: callerAvatar,
            )));
            return;
          }
        }
      } catch (_) {}

      final repo = ChatsRepository();
      final chats = await repo.listChats(limit: 5);
      for (final chat in chats) {
        if (!mounted || _prompt != null) break;
        if (chat.id.isEmpty) continue;
        final CallSession? active;
        try {
          active = await callsRepo.getActiveDmCall(chat.id);
        } catch (_) {
          continue;
        }
        if (active == null || active.id.isEmpty) continue;
        if (_selfManagedCallIds.contains(active.id)) continue;
        if (_handledGroupCallIds.contains(active.id)) continue;
        final caller = active.peerUserId;
        if (caller != null && caller.isNotEmpty && me != null && caller == me) continue;
        _presentPrompt(_DmIncomingPrompt(IncomingCallPayload(
          callId: active.id,
          callType: active.callType,
          chatId: chat.id,
          peerName: chat.otherUser?.displayName ?? chat.otherUser?.username ?? 'Incoming call',
          peerUserId: chat.otherUser?.id,
          callerAvatar: chat.otherUser?.avatarUrl,
        )));
        break;
      }
    } catch (_) {
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _activeCallPollTimer?.cancel();
    XLiveSocketClient.instance.removeListener(_onSocketClientChanged);
    _dmIncomingSub?.cancel();
    _groupStartedSub?.cancel();
    super.dispose();
  }

  void _presentPrompt(_IncomingPrompt prompt) {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!mounted) return;
    setState(() => _prompt = prompt);
  }

  void _dismiss() => setState(() => _prompt = null);

  void _showOverlayError(Object error) {
    final ctx = rootNavigatorContext;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(content: Text(friendlyApiMessage(error))),
    );
  }

  Future<void> _pushRootRoute(Route<void> route) async {
    final navigator = rootNavigator;
    if (navigator == null) {
      _showOverlayError('Unable to open call screen');
      return;
    }
    await navigator.push(route);
  }

  Future<void> _acceptDm(IncomingCallPayload payload) async {
    _selfManagedCallIds.add(payload.callId);
    _dismiss();
    try {
      final session = await CallsRepository().acceptCall(payload.callId);
      XLiveSocketClient.instance.emitDmCallAccept(payload.callId);
      final chatId = (payload.chatId?.isNotEmpty == true) ? payload.chatId! : (session.chatId ?? '');
      await _pushRootRoute(
        MaterialPageRoute<void>(
          builder: (_) => DmCallScreen(
            chatId: chatId,
            peerName: payload.peerName ?? 'Call',
            callId: payload.callId,
            isIncoming: true,
            callType: payload.callType,
            initialCredentials: session.credentials,
          ),
        ),
      );
    } catch (e) {
      _showOverlayError(e);
    }
  }

  Future<void> _declineDm(IncomingCallPayload payload) async {
    _selfManagedCallIds.add(payload.callId);
    _dismiss();
    try {
      await CallsRepository().declineCall(payload.callId);
      XLiveSocketClient.instance.emitDmCallDecline(payload.callId);
    } catch (_) {}
  }

  Future<void> _joinGroup(GroupCallEventPayload payload) async {
    _handledGroupCallIds.add(payload.callId);
    _dismiss();
    try {
      final session = await CallsRepository().joinGroupCall(payload.callId);
      XLiveSocketClient.instance.emitGroupCallJoin(payload.callId);
      await _pushRootRoute(
        MaterialPageRoute<void>(
          builder: (_) => GroupCallScreen(
            groupId: payload.groupId,
            groupName: payload.groupName ?? 'Group call',
            callId: payload.callId,
            isIncoming: true,
            isHost: false,
            callType: payload.callType,
            initialCredentials: session.credentials,
          ),
        ),
      );
    } catch (e) {
      _showOverlayError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prompt = _prompt;
    return Stack(
      children: [
        widget.child,
        if (prompt != null)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black54,
                alignment: Alignment.topCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: switch (prompt) {
                      _DmIncomingPrompt(:final payload) => _IncomingCallCard(
                          title: 'Incoming ${payload.callType == CallMediaType.video ? "video" : "audio"} call',
                          subtitle: '${payload.peerName ?? "Someone"} is calling you',
                          avatarUrl: payload.callerAvatar,
                          onDecline: () => _declineDm(payload),
                          onAccept: () => _acceptDm(payload),
                          acceptLabel: 'Accept',
                        ),
                      _GroupIncomingPrompt(:final payload) => _IncomingCallCard(
                          title: payload.groupName ?? 'Group call',
                          subtitle: payload.callType == CallMediaType.video ? 'Group video call' : 'Group audio call',
                          onDecline: () {
                            _handledGroupCallIds.add(payload.callId);
                            _dismiss();
                          },
                          onAccept: () => _joinGroup(payload),
                          acceptLabel: 'Join',
                        ),
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _IncomingCallCard extends StatelessWidget {
  const _IncomingCallCard({
    required this.title,
    required this.subtitle,
    required this.onDecline,
    required this.onAccept,
    required this.acceptLabel,
    this.avatarUrl,
  });

  final String title;
  final String subtitle;
  final VoidCallback onDecline;
  final VoidCallback onAccept;
  final String acceptLabel;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _black,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (avatarUrl != null && avatarUrl!.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Image.network(
                  avatarUrl!,
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: [_purple, _sky]),
                    ),
                    child: const Icon(Icons.call_rounded, color: Colors.white, size: 34),
                  ),
                ),
              )
            else
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [_purple, _sky]),
                ),
                child: const Icon(Icons.call_rounded, color: Colors.white, size: 34),
              ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22)),
            const SizedBox(height: 6),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60, fontSize: 15)),
            const SizedBox(height: 28),
            Row(
              children: [
                Expanded(
                  child: _CallCircleButton(
                    icon: Icons.call_end_rounded,
                    label: 'Decline',
                    color: _red,
                    onTap: onDecline,
                  ),
                ),
                const SizedBox(width: 28),
                Expanded(
                  child: _CallCircleButton(
                    icon: Icons.call_rounded,
                    label: acceptLabel,
                    color: const Color(0xFF34C759),
                    onTap: onAccept,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CallCircleButton extends StatelessWidget {
  const _CallCircleButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(width: 64, height: 64, child: Icon(icon, color: Colors.white, size: 28)),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class DmCallScreen extends StatefulWidget {
  const DmCallScreen({
    super.key,
    required this.chatId,
    required this.peerName,
    this.callId,
    required this.isIncoming,
    required this.callType,
    this.initialCredentials,
  });

  final String chatId;
  final String peerName;
  final String? callId;
  final bool isIncoming;
  final CallMediaType callType;
  final AgoraStreamToken? initialCredentials;

  @override
  State<DmCallScreen> createState() => _DmCallScreenState();
}

class _DmCallScreenState extends State<DmCallScreen> {
  final _callsRepo = CallsRepository();
  String? _callId;
  AgoraStreamToken? _credentials;
  bool _loading = true;
  String? _error;
  bool _ending = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _connected = false;
  String _status = 'Connecting…';
  RtcEngine? _engine;
  StreamSubscription<Map<String, dynamic>>? _acceptedSub;
  StreamSubscription<Map<String, dynamic>>? _declinedSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;

  @override
  void initState() {
    super.initState();
    _callId = widget.callId;
    _status = widget.isIncoming ? 'Connecting…' : 'Ringing…';
    final socket = XLiveSocketClient.instance;
    _acceptedSub = socket.onDmCallAccepted.listen((data) {
      if (!_matchesCall(data)) return;
      if (mounted && !widget.isIncoming && !_connected) setState(() => _status = 'Connecting…');
    });
    _declinedSub = socket.onDmCallDeclined.listen(_popIfSameCall);
    _endedSub = socket.onDmCallEnded.listen(_popIfSameCall);
    _bootstrap();
  }

  void _onRemoteCountChanged(int count) {
    if (!mounted) return;
    setState(() {
      _connected = count > 0;
      _status = count > 0 ? 'Connected' : (widget.isIncoming ? 'Connecting…' : 'Ringing…');
    });
  }

  bool _matchesCall(Map<String, dynamic> data) {
    final call = data['call'] is Map ? data['call'] as Map<String, dynamic> : data;
    final id = call['callId']?.toString() ?? call['id']?.toString() ?? data['callId']?.toString();
    if (id == null || id.isEmpty) return true;
    return id == _callId;
  }

  void _popIfSameCall(Map<String, dynamic> data) {
    if (!_matchesCall(data)) return;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final initial = widget.initialCredentials;
      if (initial != null && initial.token.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _callId = widget.callId;
          _credentials = initial;
          _loading = false;
          _status = widget.isIncoming ? 'Connecting…' : 'Ringing…';
        });
        return;
      }
      var callId = _callId ?? '';
      CallSession? session;
      if (callId.isEmpty) {
        session = await _callsRepo.startDmCall(chatId: widget.chatId, callType: widget.callType);
        callId = session.id;
        XLiveSocketClient.instance.emitDmCallStart(
          chatId: widget.chatId,
          callType: callMediaTypeToApi(widget.callType),
          callId: callId,
        );
      }
      if (callId.isEmpty) {
        throw ApiException('Call unavailable');
      }
      AgoraStreamToken? cred = session?.credentials;
      if (widget.isIncoming) {
        session = await _callsRepo.acceptCall(callId);
        cred = session.credentials;
        XLiveSocketClient.instance.emitDmCallAccept(callId);
      }
      if (cred == null || cred.token.isEmpty) {
        cred = await _callsRepo.getToken(callId);
      }
      if (!mounted) return;
      setState(() {
        _callId = callId;
        _credentials = cred;
        _loading = false;
        _status = widget.isIncoming ? 'Connecting…' : 'Ringing…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _toggleMute() async {
    final callId = _callId;
    if (callId == null) return;
    final next = !_muted;
    setState(() => _muted = next);
    await _engine?.muteLocalAudioStream(next);
    try {
      await _callsRepo.updateDmCallMedia(callId, muted: next);
    } catch (_) {}
  }

  Future<void> _toggleCamera() async {
    if (widget.callType != CallMediaType.video) return;
    final callId = _callId;
    if (callId == null) return;
    final next = !_cameraOff;
    setState(() => _cameraOff = next);
    await _engine?.muteLocalVideoStream(next);
    if (next) {
      await _engine?.stopPreview();
    } else {
      await _engine?.startPreview();
    }
    try {
      await _callsRepo.updateDmCallMedia(callId, cameraOff: next);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    setState(() => _speakerOn = next);
    await _engine?.setEnableSpeakerphone(next);
  }

  Future<void> _flipCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> _endCall() async {
    if (_ending) return;
    final callId = _callId;
    if (callId == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _ending = true);
    try {
      await _callsRepo.endCall(callId);
      XLiveSocketClient.instance.emitDmCallEnd(callId);
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _acceptedSub?.cancel();
    _declinedSub?.cancel();
    _endedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1028), _black],
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else if (_error != null)
            _CallErrorBody(message: _error!, onRetry: _bootstrap, onClose: () => Navigator.pop(context))
          else if (_credentials == null)
            _CallErrorBody(message: 'Call unavailable', onRetry: _bootstrap, onClose: () => Navigator.pop(context))
          else ...[
            AgoraCallView(
              credentials: _credentials!,
              callType: widget.callType,
              channelFallback: _callId ?? widget.chatId,
              localCameraOff: _cameraOff,
              onEngineReady: (engine) => _engine = engine,
              onRemoteCountChanged: _onRemoteCountChanged,
              fallback: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const UserAvatar(radius: 56, backgroundColor: Color(0xFF2A2038), iconColor: Colors.white54),
                    const SizedBox(height: 24),
                    Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 16)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Text(widget.peerName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: _CallControlBar(
                isVideo: widget.callType == CallMediaType.video,
                muted: _muted,
                cameraOff: _cameraOff,
                speakerOn: _speakerOn,
                onToggleMute: _toggleMute,
                onToggleCamera: _toggleCamera,
                onToggleSpeaker: _toggleSpeaker,
                onFlipCamera: _flipCamera,
                onEnd: _endCall,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class GroupCallScreen extends StatefulWidget {
  const GroupCallScreen({
    super.key,
    required this.groupId,
    required this.groupName,
    this.callId,
    required this.isIncoming,
    required this.isHost,
    this.callType = CallMediaType.video,
    this.initialCredentials,
  });

  final String groupId;
  final String groupName;
  final String? callId;
  final bool isIncoming;
  final bool isHost;
  final CallMediaType callType;
  final AgoraStreamToken? initialCredentials;

  @override
  State<GroupCallScreen> createState() => _GroupCallScreenState();
}

class _GroupCallScreenState extends State<GroupCallScreen> {
  final _callsRepo = CallsRepository();
  String? _callId;
  AgoraStreamToken? _credentials;
  bool _loading = true;
  String? _error;
  bool _ending = false;
  bool _muted = false;
  bool _cameraOff = false;
  bool _speakerOn = true;
  bool _connected = false;
  int _remoteCount = 0;
  bool _hadOthersInCall = false;
  String _status = 'Connecting…';
  RtcEngine? _engine;
  StreamSubscription<Map<String, dynamic>>? _joinedSub;
  StreamSubscription<Map<String, dynamic>>? _leftSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;

  @override
  void initState() {
    super.initState();
    _callId = widget.callId;
    if (widget.callId != null && widget.callId!.isNotEmpty) {
      _selfManagedCallIds.add(widget.callId!);
    }
    _activeSelfGroupCallGroupIds.add(widget.groupId);
    _status = widget.isIncoming ? 'Joining…' : 'Waiting for others…';
    final socket = XLiveSocketClient.instance;
    _joinedSub = socket.onGroupCallJoined.listen(_onGroupJoined);
    _leftSub = socket.onGroupCallLeft.listen(_onGroupLeft);
    _endedSub = socket.onGroupCallEnded.listen(_onGroupEnded);
    _bootstrap();
  }

  void _onRemoteCountChanged(int count) {
    if (!mounted) return;
    if (count > 0) _hadOthersInCall = true;
    if (count == 0 && _hadOthersInCall && !_ending) {
      _leaveCall();
      return;
    }
    setState(() {
      _connected = count > 0;
      _remoteCount = count;
      _status = count > 0
          ? '${count + 1} in call'
          : (widget.isHost ? 'Waiting for others…' : 'Connecting…');
    });
  }

  void _onGroupJoined(Map<String, dynamic> data) {
    final payload = GroupCallEventPayload.fromJson(data);
    if (payload.groupId != widget.groupId) return;
    if (payload.callId.isNotEmpty && payload.callId != _callId) return;
    if (!mounted || _connected) return;
    setState(() => _status = 'Connecting…');
  }

  void _onGroupLeft(Map<String, dynamic> data) {
    final payload = GroupCallEventPayload.fromJson(data);
    if (payload.groupId != widget.groupId) return;
    if (payload.callId.isNotEmpty && payload.callId != _callId) return;
  }

  void _onGroupEnded(Map<String, dynamic> data) {
    final payload = GroupCallEventPayload.fromJson(data);
    if (payload.groupId != widget.groupId) return;
    if (payload.callId.isNotEmpty && payload.callId != _callId) return;
    if (mounted) Navigator.pop(context);
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final initial = widget.initialCredentials;
      if (initial != null && initial.token.isNotEmpty) {
        if (!mounted) return;
        setState(() {
          _callId = widget.callId;
          _credentials = initial;
          _loading = false;
          _status = widget.isHost ? 'Waiting for others…' : 'Connecting…';
        });
        return;
      }
      var callId = _callId ?? '';
      CallSession? session;
      if (!widget.isIncoming && callId.isEmpty) {
        session = await _callsRepo.startGroupCall(groupId: widget.groupId, callType: widget.callType);
        callId = session.id;
        XLiveSocketClient.instance.emitGroupCallStart(
          groupId: widget.groupId,
          callId: callId,
          callType: callMediaTypeToApi(widget.callType),
        );
      }
      if (callId.isEmpty) {
        throw ApiException('Call unavailable');
      }
      AgoraStreamToken? cred = session?.credentials;
      if (cred == null || cred.token.isEmpty) {
        session = await _callsRepo.joinGroupCall(callId);
        cred = session.credentials;
      }
      if (cred == null || cred.token.isEmpty) {
        cred = await _callsRepo.getToken(callId);
      }
      XLiveSocketClient.instance.emitGroupCallJoin(callId);
      _selfManagedCallIds.add(callId);
      if (!mounted) return;
      setState(() {
        _callId = callId;
        _credentials = cred;
        _loading = false;
        _status = widget.isHost ? 'Waiting for others…' : 'Connecting…';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _toggleMute() async {
    final callId = _callId;
    if (callId == null) return;
    final next = !_muted;
    setState(() => _muted = next);
    await _engine?.muteLocalAudioStream(next);
    try {
      await _callsRepo.updateGroupCallMedia(callId, muted: next);
    } catch (_) {}
  }

  Future<void> _toggleCamera() async {
    if (widget.callType != CallMediaType.video) return;
    final callId = _callId;
    if (callId == null) return;
    final next = !_cameraOff;
    setState(() => _cameraOff = next);
    await _engine?.muteLocalVideoStream(next);
    if (next) {
      await _engine?.stopPreview();
    } else {
      await _engine?.startPreview();
    }
    try {
      await _callsRepo.updateGroupCallMedia(callId, cameraOff: next);
    } catch (_) {}
  }

  Future<void> _toggleSpeaker() async {
    final next = !_speakerOn;
    setState(() => _speakerOn = next);
    await _engine?.setEnableSpeakerphone(next);
  }

  Future<void> _flipCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> _leaveCall() async {
    if (_ending) return;
    final callId = _callId;
    if (callId == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() => _ending = true);
    try {
      if (widget.isHost) {
        await _callsRepo.endGroupCall(callId);
        XLiveSocketClient.instance.emitGroupCallEnd(callId);
      } else {
        await _callsRepo.leaveGroupCall(callId);
        XLiveSocketClient.instance.emitGroupCallLeave(callId);
      }
    } catch (_) {}
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    final id = _callId;
    if (id != null && id.isNotEmpty) _selfManagedCallIds.remove(id);
    _activeSelfGroupCallGroupIds.remove(widget.groupId);
    _joinedSub?.cancel();
    _leftSub?.cancel();
    _endedSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF141428), _black],
              ),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          else if (_error != null)
            _CallErrorBody(message: _error!, onRetry: _bootstrap, onClose: () => Navigator.pop(context))
          else if (_credentials == null)
            _CallErrorBody(message: 'Call unavailable', onRetry: _bootstrap, onClose: () => Navigator.pop(context))
          else ...[
            AgoraCallView(
              credentials: _credentials!,
              callType: widget.callType,
              channelFallback: _callId ?? widget.groupId,
              isGroup: true,
              localCameraOff: _cameraOff,
              onEngineReady: (engine) => _engine = engine,
              onRemoteCountChanged: _onRemoteCountChanged,
              fallback: widget.callType == CallMediaType.audio
                  ? _GroupAudioStage(participantCount: _remoteCount + 1)
                  : const SizedBox.shrink(),
            ),
            Positioned(
              top: MediaQuery.paddingOf(context).top + 12,
              left: 20,
              right: 20,
              child: Column(
                children: [
                  Text(widget.groupName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(_status, style: const TextStyle(color: Colors.white54, fontSize: 14)),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + 28,
              child: _CallControlBar(
                isVideo: widget.callType == CallMediaType.video,
                muted: _muted,
                cameraOff: _cameraOff,
                speakerOn: _speakerOn,
                onToggleMute: _toggleMute,
                onToggleCamera: _toggleCamera,
                onToggleSpeaker: _toggleSpeaker,
                onFlipCamera: _flipCamera,
                onEnd: _leaveCall,
                endLabel: widget.isHost ? 'End' : 'Leave',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupAudioStage extends StatelessWidget {
  const _GroupAudioStage({
    required this.participantCount,
  });

  final int participantCount;

  @override
  Widget build(BuildContext context) {
    final count = participantCount.clamp(1, 12);
    final columns = count <= 1 ? 1 : (count <= 4 ? 2 : 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 96, 20, 140),
      child: GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          for (var i = 0; i < count; i++)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: [_purple, _sky]),
                  ),
                  child: Icon(i == 0 ? Icons.person_rounded : Icons.person_outline_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(height: 8),
                Text(i == 0 ? 'You' : 'Member', style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
        ],
      ),
    );
  }
}

class _CallControlBar extends StatelessWidget {
  const _CallControlBar({
    required this.isVideo,
    required this.muted,
    required this.cameraOff,
    required this.speakerOn,
    required this.onToggleMute,
    required this.onToggleCamera,
    required this.onToggleSpeaker,
    required this.onFlipCamera,
    required this.onEnd,
    this.endLabel = 'End',
  });

  final bool isVideo;
  final bool muted;
  final bool cameraOff;
  final bool speakerOn;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleSpeaker;
  final VoidCallback onFlipCamera;
  final VoidCallback onEnd;
  final String endLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ControlChip(
          icon: muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          label: muted ? 'Unmute' : 'Mute',
          active: !muted,
          onTap: onToggleMute,
        ),
        const SizedBox(width: 16),
        if (isVideo) ...[
          _ControlChip(
            icon: cameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
            label: cameraOff ? 'Camera' : 'Camera',
            active: !cameraOff,
            onTap: onToggleCamera,
          ),
          const SizedBox(width: 16),
          _ControlChip(
            icon: Icons.flip_camera_ios_rounded,
            label: 'Flip',
            active: true,
            onTap: onFlipCamera,
          ),
          const SizedBox(width: 16),
        ],
        _ControlChip(
          icon: speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
          label: speakerOn ? 'Speaker' : 'Earpiece',
          active: speakerOn,
          onTap: onToggleSpeaker,
        ),
        const SizedBox(width: 16),
        Column(
          children: [
            Material(
              color: _red,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onEnd,
                child: const SizedBox(width: 60, height: 60, child: Icon(Icons.call_end_rounded, color: Colors.white, size: 28)),
              ),
            ),
            const SizedBox(height: 6),
            Text(endLabel, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
      ],
    );
  }
}

class _ControlChip extends StatelessWidget {
  const _ControlChip({required this.icon, required this.onTap, this.label, this.active = true});

  final IconData icon;
  final VoidCallback onTap;
  final String? label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Material(
          color: active ? Colors.white.withValues(alpha: 0.16) : Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 54,
              height: 54,
              child: Icon(icon, color: active ? Colors.white : _black, size: 24),
            ),
          ),
        ),
        if (label != null) ...[
          const SizedBox(height: 6),
          Text(label!, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ],
    );
  }
}

class _CallErrorBody extends StatelessWidget {
  const _CallErrorBody({required this.message, required this.onRetry, required this.onClose});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
            TextButton(onPressed: onClose, child: const Text('Close')),
          ],
        ),
      ),
    );
  }
}
