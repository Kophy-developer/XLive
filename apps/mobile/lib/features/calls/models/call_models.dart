import '../../../core/network/api_json.dart';
import '../../streams/models/stream_models.dart';

enum CallMediaType { video, audio }

CallMediaType callMediaTypeFromString(String? raw) {
  if (raw?.toLowerCase() == 'audio') return CallMediaType.audio;
  return CallMediaType.video;
}

String callMediaTypeToApi(CallMediaType type) => type == CallMediaType.audio ? 'audio' : 'video';

class CallSession {
  const CallSession({
    required this.id,
    this.chatId,
    this.groupId,
    this.callType = CallMediaType.video,
    this.peerName,
    this.peerUserId,
    this.calleeId,
    this.isIncoming = false,
    this.credentials,
  });

  final String id;
  final String? chatId;
  final String? groupId;
  final CallMediaType callType;
  final String? peerName;
  final String? peerUserId;
  final String? calleeId;
  final bool isIncoming;
  final AgoraStreamToken? credentials;

  bool get isVideo => callType == CallMediaType.video;

  factory CallSession.fromJson(Map<String, dynamic> json) {
    final cred = ApiJson.map(json['credentials']) ??
        ApiJson.map(json['agora']) ??
        ApiJson.map(json['token']);
    final token = cred == null ? _credentialsFromRoot(json) : AgoraStreamToken.fromJson(cred);
    return CallSession(
      id: ApiJson.pickString(json, ['id', '_id', 'callId']) ?? '',
      chatId: ApiJson.pickString(json, ['chatId', 'dmChatId']),
      groupId: ApiJson.pickString(json, ['groupId']),
      callType: callMediaTypeFromString(ApiJson.pickString(json, ['callType', 'type', 'mediaType'])),
      peerName: ApiJson.pickString(json, ['peerName', 'callerName', 'displayName', 'name']),
      peerUserId: ApiJson.pickString(json, ['peerUserId', 'callerId', 'userId', 'startedBy', 'hostId']),
      calleeId: ApiJson.pickString(json, ['calleeId', 'toUserId', 'recipientId']),
      isIncoming: ApiJson.boolValue(json['isIncoming']) || ApiJson.boolValue(json['incoming']),
      credentials: token,
    );
  }

  static AgoraStreamToken? _credentialsFromRoot(Map<String, dynamic> json) {
    final token = ApiJson.pickString(json, ['token', 'agoraToken', 'rtcToken']);
    if (token == null || token.isEmpty) return null;
    final rawUid = ApiJson.pickString(json, ['uid', 'agoraUid']);
    final parsedUid = rawUid == null ? null : int.tryParse(rawUid);
    return AgoraStreamToken(
      token: token,
      channelName: ApiJson.pickString(json, ['channel', 'channelName', 'channelId', 'agoraChannel']),
      uid: parsedUid,
      userAccount: (parsedUid == null && rawUid != null && rawUid.isNotEmpty) ? rawUid : null,
      appId: ApiJson.pickString(json, ['appId', 'agoraAppId']),
    );
  }
}

class IncomingCallPayload {
  const IncomingCallPayload({
    required this.callId,
    required this.callType,
    this.chatId,
    this.groupId,
    this.peerName,
    this.peerUserId,
    this.callerAvatar,
  });

  final String callId;
  final CallMediaType callType;
  final String? chatId;
  final String? groupId;
  final String? peerName;
  final String? peerUserId;
  final String? callerAvatar;

  factory IncomingCallPayload.fromJson(Map<String, dynamic> json) {
    final call = ApiJson.map(json['call']) ?? json;
    final caller = ApiJson.map(json['caller']) ?? ApiJson.map(call['caller']);
    return IncomingCallPayload(
      callId: ApiJson.pickString(call, ['callId', 'id', '_id']) ?? ApiJson.pickString(json, ['callId', 'id', '_id']) ?? '',
      callType: callMediaTypeFromString(ApiJson.pickString(call, ['callType', 'type', 'mediaType']) ?? ApiJson.pickString(json, ['callType', 'type', 'mediaType'])),
      chatId: ApiJson.pickString(call, ['chatId', 'dmChatId']) ?? ApiJson.pickString(json, ['chatId', 'dmChatId']),
      groupId: ApiJson.pickString(call, ['groupId']) ?? ApiJson.pickString(json, ['groupId']),
      peerName: ApiJson.pickString(call, ['peerName', 'callerName', 'displayName', 'name', 'fromName']) ??
          ApiJson.pickString(json, ['peerName', 'callerName', 'displayName', 'name', 'fromName', 'callerName']) ??
          (caller != null ? ApiJson.pickString(caller, ['displayName', 'name', 'username']) : null),
      peerUserId: ApiJson.pickString(call, ['peerUserId', 'callerId', 'userId', 'fromUserId']) ??
          ApiJson.pickString(json, ['peerUserId', 'callerId', 'userId', 'fromUserId', 'callerId']) ??
          (caller != null ? ApiJson.pickString(caller, ['id', '_id']) : null),
      callerAvatar: ApiJson.pickString(call, ['callerAvatarUrl', 'callerAvatar', 'avatarUrl', 'avatar']) ??
          ApiJson.pickString(json, ['callerAvatarUrl', 'callerAvatar', 'avatarUrl', 'avatar']) ??
          (caller != null ? ApiJson.pickString(caller, ['avatarUrl', 'avatar']) : null),
    );
  }
}

class GroupCallEventPayload {
  const GroupCallEventPayload({
    required this.groupId,
    required this.callId,
    this.callType = CallMediaType.video,
    this.groupName,
    this.callerName,
    this.participantCount = 0,
    this.userId,
    this.credentials,
  });

  final String groupId;
  final String callId;
  final CallMediaType callType;
  final String? groupName;
  final String? callerName;
  final int participantCount;
  final String? userId;
  final AgoraStreamToken? credentials;

  factory GroupCallEventPayload.fromJson(Map<String, dynamic> json) {
    final call = ApiJson.map(json['call']) ?? json;
    final cred = ApiJson.map(call['credentials']) ??
        ApiJson.map(call['agora']) ??
        ApiJson.map(call['token']);
    final token = cred == null ? CallSession._credentialsFromRoot(call) : AgoraStreamToken.fromJson(cred);
    return GroupCallEventPayload(
      groupId: ApiJson.pickString(json, ['groupId']) ?? ApiJson.pickString(call, ['groupId']) ?? '',
      callId: ApiJson.pickString(call, ['callId', 'id', '_id']) ?? '',
      callType: callMediaTypeFromString(ApiJson.pickString(call, ['callType', 'type', 'mediaType'])),
      groupName: ApiJson.pickString(json, ['groupName', 'name', 'title']) ??
          ApiJson.pickString(call, ['groupName', 'name', 'title']),
      callerName: ApiJson.pickString(call, ['callerName', 'peerName', 'displayName', 'hostName', 'name']) ??
          ApiJson.pickString(json, ['callerName', 'peerName', 'displayName', 'hostName']),
      participantCount: ApiJson.pickInt(call, ['participantCount', 'participantsCount', 'participants']) > 0
          ? ApiJson.pickInt(call, ['participantCount', 'participantsCount', 'participants'])
          : ApiJson.pickInt(json, ['participantCount', 'participantsCount', 'participants']),
      userId: ApiJson.pickString(json, ['userId', 'callerId', 'startedBy', 'fromUserId', 'hostId']) ??
          ApiJson.pickString(call, ['userId', 'callerId', 'startedBy', 'fromUserId', 'hostId']),
      credentials: token,
    );
  }
}
