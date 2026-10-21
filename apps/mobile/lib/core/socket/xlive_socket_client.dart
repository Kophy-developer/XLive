import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config/api_config.dart';
import '../session/session_store.dart';

class XLiveSocketClient extends ChangeNotifier {
  XLiveSocketClient._({ApiConfig config = ApiConfig.staging, SessionStore? sessionStore})
      : _config = config,
        _session = sessionStore ?? SessionStore();

  static final XLiveSocketClient instance = XLiveSocketClient._();

  final ApiConfig _config;
  final SessionStore _session;
  io.Socket? _socket;
  bool _connected = false;
  String? _userId;

  final _xliveConnectedController = StreamController<Map<String, dynamic>>.broadcast();
  final _xliveErrorController = StreamController<Map<String, dynamic>>.broadcast();
  final _connectErrorController = StreamController<Map<String, dynamic>>.broadcast();
  final _userPresenceChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamViewersController = StreamController<Map<String, dynamic>>.broadcast();
  final _viewerCountController = StreamController<Map<String, dynamic>>.broadcast();
  final _viewerRemovedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamChatMessageController = StreamController<Map<String, dynamic>>.broadcast();
  final _giftSentController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamTranscriptController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamTranscriptHistoryController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamBillingTickController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamViewerMutedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamViewerUnmutedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamTalkBackGrantedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamTalkBackRevokedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamInviteIncomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamInviteAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamInviteDeclinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageEditedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _messageReactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _unreadUpdatedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupMembersChangedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupMessageReceivedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupMessageEditedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupMessageDeletedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupMessageReactionController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmCallIncomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmCallAcceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmCallDeclinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmCallEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _dmCallEventController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupCallStartedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupCallJoinedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupCallLeftController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupCallEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _groupCallMediaStateController = StreamController<Map<String, dynamic>>.broadcast();
  final _notificationCreatedController = StreamController<Map<String, dynamic>>.broadcast();

  bool get isConnected => _connected;
  String? get userId => _userId;

  Stream<Map<String, dynamic>> get onXliveConnected => _xliveConnectedController.stream;
  Stream<Map<String, dynamic>> get onXliveError => _xliveErrorController.stream;
  Stream<Map<String, dynamic>> get onConnectError => _connectErrorController.stream;
  Stream<Map<String, dynamic>> get onUserPresenceChanged => _userPresenceChangedController.stream;
  Stream<Map<String, dynamic>> get onStreamViewers => _streamViewersController.stream;
  Stream<Map<String, dynamic>> get onViewerCount => _viewerCountController.stream;
  Stream<Map<String, dynamic>> get onViewerRemoved => _viewerRemovedController.stream;
  Stream<Map<String, dynamic>> get onStreamEnded => _streamEndedController.stream;
  Stream<Map<String, dynamic>> get onStreamChatMessage => _streamChatMessageController.stream;
  Stream<Map<String, dynamic>> get onGiftSent => _giftSentController.stream;
  Stream<Map<String, dynamic>> get onStreamTranscript => _streamTranscriptController.stream;
  Stream<Map<String, dynamic>> get onStreamTranscriptHistory => _streamTranscriptHistoryController.stream;
  Stream<Map<String, dynamic>> get onStreamBillingTick => _streamBillingTickController.stream;
  Stream<Map<String, dynamic>> get onStreamViewerMuted => _streamViewerMutedController.stream;
  Stream<Map<String, dynamic>> get onStreamViewerUnmuted => _streamViewerUnmutedController.stream;
  Stream<Map<String, dynamic>> get onStreamTalkBackGranted => _streamTalkBackGrantedController.stream;
  Stream<Map<String, dynamic>> get onStreamTalkBackRevoked => _streamTalkBackRevokedController.stream;
  Stream<Map<String, dynamic>> get onStreamInviteIncoming => _streamInviteIncomingController.stream;
  Stream<Map<String, dynamic>> get onStreamInviteAccepted => _streamInviteAcceptedController.stream;
  Stream<Map<String, dynamic>> get onStreamInviteDeclined => _streamInviteDeclinedController.stream;
  Stream<Map<String, dynamic>> get onDmMessage => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMessageReceived => _messageReceivedController.stream;
  Stream<Map<String, dynamic>> get onMessageEdited => _messageEditedController.stream;
  Stream<Map<String, dynamic>> get onMessageDeleted => _messageDeletedController.stream;
  Stream<Map<String, dynamic>> get onMessageReaction => _messageReactionController.stream;
  Stream<Map<String, dynamic>> get onUnreadUpdated => _unreadUpdatedController.stream;
  Stream<Map<String, dynamic>> get onGroupMembersChanged => _groupMembersChangedController.stream;
  Stream<Map<String, dynamic>> get onGroupMessage => _groupMessageReceivedController.stream;
  Stream<Map<String, dynamic>> get onGroupMessageReceived => _groupMessageReceivedController.stream;
  Stream<Map<String, dynamic>> get onGroupMessageEdited => _groupMessageEditedController.stream;
  Stream<Map<String, dynamic>> get onGroupMessageDeleted => _groupMessageDeletedController.stream;
  Stream<Map<String, dynamic>> get onGroupMessageReaction => _groupMessageReactionController.stream;
  Stream<Map<String, dynamic>> get onDmCallIncoming => _dmCallIncomingController.stream;
  Stream<Map<String, dynamic>> get onDmCallAccepted => _dmCallAcceptedController.stream;
  Stream<Map<String, dynamic>> get onDmCallDeclined => _dmCallDeclinedController.stream;
  Stream<Map<String, dynamic>> get onDmCallEnded => _dmCallEndedController.stream;
  Stream<Map<String, dynamic>> get onDmCallEvent => _dmCallEventController.stream;
  Stream<Map<String, dynamic>> get onGroupCallStarted => _groupCallStartedController.stream;
  Stream<Map<String, dynamic>> get onGroupCallJoined => _groupCallJoinedController.stream;
  Stream<Map<String, dynamic>> get onGroupCallLeft => _groupCallLeftController.stream;
  Stream<Map<String, dynamic>> get onGroupCallEnded => _groupCallEndedController.stream;
  Stream<Map<String, dynamic>> get onGroupCallMediaState => _groupCallMediaStateController.stream;
  Stream<Map<String, dynamic>> get onNotificationCreated => _notificationCreatedController.stream;
  Stream<Map<String, dynamic>> get onStreamGift => _giftSentController.stream;
  Stream<Map<String, dynamic>> get onStreamViewerCount => _viewerCountController.stream;

  String? _lastJwt;

  Future<void> connectIfSignedIn() async {
    final jwt = await _session.readJwt();
    if (jwt == null || jwt.isEmpty) {
      disconnect();
      return;
    }
    if (_socket != null && _connected && _lastJwt == jwt) {
      return;
    }
    await connect(jwt);
  }

  Future<void> connect(String jwt) async {
    disconnect();
    _lastJwt = jwt;
    final socket = io.io(
      _config.apiBaseUrl,
      io.OptionBuilder()
          .setTransports(['websocket', 'polling'])
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setAuth({'token': jwt})
          .setExtraHeaders({'Authorization': 'Bearer $jwt'})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      _connected = true;
      notifyListeners();
    });

    socket.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    socket.onConnectError((error) {
      _connected = false;
      _connectErrorController.add({
        'message': error?.toString() ?? 'Connection failed',
      });
      notifyListeners();
    });

    _bind(socket, 'xlive_connected', _xliveConnectedController, onData: (map) {
      final id = map['userId']?.toString();
      if (id != null && id.isNotEmpty) _userId = id;
      notifyListeners();
    });
    _bind(socket, 'xlive_error', _xliveErrorController);
    _bind(socket, 'user_presence_changed', _userPresenceChangedController);
    _bind(socket, 'stream_viewers', _streamViewersController);
    _bind(socket, 'viewer_count', _viewerCountController);
    _bind(socket, 'viewer_count_updated', _viewerCountController);
    _bind(socket, 'stream_viewer_count', _viewerCountController);
    _bind(socket, 'viewer_removed', _viewerRemovedController);
    _bind(socket, 'stream_ended', _streamEndedController);
    _bind(socket, 'stream_chat_message', _streamChatMessageController);
    _bind(socket, 'gift_sent', _giftSentController);
    _bind(socket, 'gift_received', _giftSentController);
    _bind(socket, 'stream_gift_received', _giftSentController);
    _bind(socket, 'stream_transcript', _streamTranscriptController);
    _bind(socket, 'stream_transcript_history', _streamTranscriptHistoryController);
    _bind(socket, 'stream:billingTick', _streamBillingTickController);
    _bind(socket, 'stream:viewerMuted', _streamViewerMutedController);
    _bind(socket, 'stream:viewerUnmuted', _streamViewerUnmutedController);
    _bind(socket, 'stream:talkBackGranted', _streamTalkBackGrantedController);
    _bind(socket, 'stream:talkBackRevoked', _streamTalkBackRevokedController);
    _bind(socket, 'stream_invite_incoming', _streamInviteIncomingController);
    _bind(socket, 'stream_invite_accepted', _streamInviteAcceptedController);
    _bind(socket, 'stream_invite_declined', _streamInviteDeclinedController);
    _bind(socket, 'message_received', _messageReceivedController);
    _bind(socket, 'message_edited', _messageEditedController);
    _bind(socket, 'message_deleted', _messageDeletedController);
    _bind(socket, 'message_reaction', _messageReactionController);
    _bind(socket, 'unread_updated', _unreadUpdatedController);
    _bind(socket, 'group_members_changed', _groupMembersChangedController);
    _bind(socket, 'group_message_received', _groupMessageReceivedController);
    _bind(socket, 'group_message_edited', _groupMessageEditedController);
    _bind(socket, 'group_message_deleted', _groupMessageDeletedController);
    _bind(socket, 'group_message_reaction', _groupMessageReactionController);
    _bind(socket, 'dm_call_incoming', _dmCallIncomingController);
    _bind(socket, 'dm_call_accepted', _dmCallAcceptedController, forward: _dmCallEventController, eventName: 'dm_call_accepted');
    _bind(socket, 'dm_call_declined', _dmCallDeclinedController, forward: _dmCallEventController, eventName: 'dm_call_declined');
    _bind(socket, 'dm_call_ended', _dmCallEndedController, forward: _dmCallEventController, eventName: 'dm_call_ended');
    _bind(socket, 'group_call_started', _groupCallStartedController);
    _bind(socket, 'group_call_joined', _groupCallJoinedController);
    _bind(socket, 'group_call_left', _groupCallLeftController);
    _bind(socket, 'group_call_ended', _groupCallEndedController);
    _bind(socket, 'group_call_media_state', _groupCallMediaStateController);
    _bind(socket, 'notification_created', _notificationCreatedController, onData: (map) {
      final notif = (map['notification'] is Map) ? map['notification'] as Map : map;
      final notifType = notif['type']?.toString();
      final notifData = (notif['data'] is Map) ? notif['data'] as Map : const {};
      if (notifType == 'dm_call' || notifData['type'] == 'dm_call') {
        final actor = (notif['actor'] is Map) ? notif['actor'] as Map : const {};
        final callId = (notifData['callId'] ?? notifData['id'] ?? '').toString();
        if (callId.isNotEmpty) {
          _dmCallIncomingController.add({
            'call': {
              'id': callId,
              'callId': callId,
              'chatId': notifData['chatId'],
              'type': notifData['callType'] ?? notifData['type'] ?? 'audio',
              'callerId': notifData['callerId'] ?? actor['id'] ?? actor['_id'],
            },
            'chatId': notifData['chatId'],
            'callerId': notifData['callerId'] ?? actor['id'] ?? actor['_id'],
            'callerName': actor['displayName'] ?? actor['username'] ?? notif['title'],
            'callerAvatarUrl': actor['avatarUrl'],
          });
        }
      }
    });

    socket.connect();
  }

  void _bind(
    io.Socket socket,
    String event,
    StreamController<Map<String, dynamic>> controller, {
    void Function(Map<String, dynamic> map)? onData,
    StreamController<Map<String, dynamic>>? forward,
    String? eventName,
  }) {
    socket.on(event, (data) {
      final dynamic raw = (data is List && data.isNotEmpty) ? data.first : data;
      if (raw is! Map) return;
      final map = Map<String, dynamic>.from(raw);
      controller.add(map);
      if (forward != null) {
        forward.add({...map, if (eventName != null) 'event': eventName});
      }
      onData?.call(map);
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
    _connected = false;
    _userId = null;
    _lastJwt = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> emitWithAck(String event, Map<String, dynamic> payload) async {
    final socket = _socket;
    if (socket == null || !socket.connected) {
      return {'ok': false, 'error': 'Not connected'};
    }
    try {
      final ack = await socket.emitWithAckAsync(event, payload);
      if (ack is Map) return Map<String, dynamic>.from(ack);
      return {'ok': false, 'error': 'Invalid ack'};
    } catch (e) {
      return {'ok': false, 'error': e.toString()};
    }
  }

  Future<bool> joinStream(String streamId) async {
    final ack = await emitWithAck('join_stream', {'streamId': streamId});
    return ack['ok'] == true;
  }

  Future<bool> leaveStream(String streamId, {int? durationSeconds, int? chargedCoins}) async {
    final payload = <String, dynamic>{'streamId': streamId};
    if (durationSeconds != null) payload['durationSeconds'] = durationSeconds;
    if (chargedCoins != null) payload['chargedCoins'] = chargedCoins;
    final ack = await emitWithAck('leave_stream', payload);
    return ack['ok'] == true;
  }

  Future<bool> endStream(String streamId) async {
    final ack = await emitWithAck('end_stream', {'streamId': streamId});
    return ack['ok'] == true;
  }

  Future<bool> removeViewer({required String streamId, required String userId}) async {
    final ack = await emitWithAck('remove_viewer', {'streamId': streamId, 'userId': userId});
    return ack['ok'] == true;
  }

  Future<bool> joinGroup(String groupId) async {
    final ack = await emitWithAck('join_group', {'groupId': groupId});
    return ack['ok'] == true;
  }

  Future<bool> leaveGroup(String groupId) async {
    final ack = await emitWithAck('leave_group', {'groupId': groupId});
    return ack['ok'] == true;
  }

  Future<bool> joinGroupChat(String groupId) async {
    final ack = await emitWithAck('join_group_chat', {'groupId': groupId});
    return ack['ok'] == true;
  }

  Future<bool> leaveGroupChat(String groupId) async {
    return leaveGroup(groupId);
  }

  Future<bool> muteViewer({required String streamId, required String userId}) async {
    final ack = await emitWithAck('stream:muteViewer', {'streamId': streamId, 'userId': userId});
    return ack['ok'] == true;
  }

  Future<bool> unmuteViewer({required String streamId, required String userId}) async {
    final ack = await emitWithAck('stream:unmuteViewer', {'streamId': streamId, 'userId': userId});
    return ack['ok'] == true;
  }

  Future<bool> grantTalkBack({required String streamId, required String userId}) async {
    final ack = await emitWithAck('stream:grantTalkBack', {'streamId': streamId, 'userId': userId});
    return ack['ok'] == true;
  }

  Future<bool> revokeTalkBack({required String streamId, required String userId}) async {
    final ack = await emitWithAck('stream:revokeTalkBack', {'streamId': streamId, 'userId': userId});
    return ack['ok'] == true;
  }

  Future<void> requestStreamViewers(String streamId) async {
    await emitWithAck('stream:getViewers', {'streamId': streamId});
  }

  void sendMessage({
    required String chatId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
  }) {
    final payload = <String, dynamic>{'chatId': chatId, 'content': content};
    if (mediaUrl != null && mediaUrl.isNotEmpty) payload['mediaUrl'] = mediaUrl;
    if (mediaType != null && mediaType.isNotEmpty) payload['mediaType'] = mediaType;
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      payload['replyToMessageId'] = replyToMessageId;
    }
    _socket?.emit('send_message', payload);
  }

  void sendDmMessage({
    required String chatId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
  }) =>
      sendMessage(
        chatId: chatId,
        content: content,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyToMessageId: replyToMessageId,
      );

  void groupChatMessage({
    required String groupId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
  }) {
    final payload = <String, dynamic>{'groupId': groupId, 'content': content};
    if (mediaUrl != null && mediaUrl.isNotEmpty) payload['mediaUrl'] = mediaUrl;
    if (mediaType != null && mediaType.isNotEmpty) payload['mediaType'] = mediaType;
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      payload['replyToMessageId'] = replyToMessageId;
    }
    _socket?.emit('group_chat_message', payload);
  }

  void sendGroupChatMessage({
    required String groupId,
    required String content,
    String? mediaUrl,
    String? mediaType,
    String? replyToMessageId,
  }) =>
      groupChatMessage(
        groupId: groupId,
        content: content,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
        replyToMessageId: replyToMessageId,
      );

  void streamChatMessage({
    required String streamId,
    required String content,
    String? mediaUrl,
    String? mediaType,
  }) {
    final payload = <String, dynamic>{'streamId': streamId, 'content': content};
    if (mediaUrl != null && mediaUrl.isNotEmpty) payload['mediaUrl'] = mediaUrl;
    if (mediaType != null && mediaType.isNotEmpty) payload['mediaType'] = mediaType;
    _socket?.emit('stream_chat_message', payload);
  }

  void sendStreamChatMessage({
    required String streamId,
    required String content,
    String? mediaUrl,
    String? mediaType,
  }) =>
      streamChatMessage(
        streamId: streamId,
        content: content,
        mediaUrl: mediaUrl,
        mediaType: mediaType,
      );

  void emitStreamTranscriptChunk({
    required String streamId,
    required String segmentId,
    required String text,
    String? sourceLang,
    bool? isFinal,
    int? timestamp,
  }) {
    final cleaned = _sanitizeCaptionText(text);
    if (cleaned.isEmpty) return;
    final payload = <String, dynamic>{
      'streamId': streamId,
      'segmentId': segmentId,
      'text': cleaned,
    };
    if (sourceLang != null && sourceLang.isNotEmpty) payload['sourceLang'] = sourceLang;
    if (isFinal != null) payload['isFinal'] = isFinal;
    if (timestamp != null) payload['timestamp'] = timestamp;
    _socket?.emit('stream_transcript_chunk', payload);
  }

  static String _sanitizeCaptionText(String raw) {
    final stripped = raw.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '').trim();
    if (stripped.isEmpty) return '';
    if (stripped.length <= 500) return stripped;
    return stripped.substring(0, 500);
  }

  void giftSent({required String streamId, required String giftId, int quantity = 1}) {
    _socket?.emit('gift_sent', {'streamId': streamId, 'giftId': giftId, 'quantity': quantity});
  }

  void sendGift({required String streamId, required String giftId, int quantity = 1}) =>
      giftSent(streamId: streamId, giftId: giftId, quantity: quantity);

  void emitDmCallStart({
    required String chatId,
    required String callType,
    String? callId,
    String? calleeId,
    String? callerName,
    String? callerAvatar,
  }) {
    _socket?.emit('dm_call_start', {
      'chatId': chatId,
      'callType': callType,
      'type': callType,
      if (callId != null) ...{'callId': callId, 'id': callId},
      if (calleeId != null) ...{'calleeId': calleeId, 'recipientId': calleeId, 'toUserId': calleeId},
      if (callerName != null) ...{'callerName': callerName, 'peerName': callerName},
      if (callerAvatar != null) ...{'callerAvatar': callerAvatar, 'callerAvatarUrl': callerAvatar, 'avatarUrl': callerAvatar},
    });
  }

  void emitDmCallAccept(String callId) {
    _socket?.emit('dm_call_accept', {'callId': callId});
  }

  void emitDmCallDecline(String callId) {
    _socket?.emit('dm_call_decline', {'callId': callId});
  }

  void emitDmCallEnd(String callId) {
    _socket?.emit('dm_call_end', {'callId': callId});
  }

  void emitGroupCallStart({
    required String groupId,
    String? callId,
    String? callType,
  }) {
    _socket?.emit('group_call_start', {
      'groupId': groupId,
      if (callId != null) 'callId': callId,
      if (callType != null) 'callType': callType,
    });
  }

  void emitGroupCallJoin(String callId) {
    _socket?.emit('group_call_join', {'callId': callId});
  }

  void emitGroupCallLeave(String callId) {
    _socket?.emit('group_call_leave', {'callId': callId});
  }

  void emitGroupCallEnd(String callId) {
    _socket?.emit('group_call_end', {'callId': callId});
  }
}
