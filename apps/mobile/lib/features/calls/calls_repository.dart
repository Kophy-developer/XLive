import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_json.dart';
import '../streams/models/stream_models.dart';
import 'models/call_models.dart';

class CallsRepository {
  CallsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;
  final Map<String, AgoraStreamToken> _tokenCache = {};

  Future<CallSession> startDmCall({
    required String chatId,
    required CallMediaType callType,
  }) async {
    final json = await _client.apiPost(
      '/api/x-live/chats/$chatId/calls',
      body: {'type': callMediaTypeToApi(callType)},
    );
    return _cacheSession(ApiJson.dataMap(json));
  }

  Future<CallSession?> getActiveDmCall(String chatId) async {
    final json = await _client.apiGet('/api/x-live/chats/$chatId/calls/active');
    final data = ApiJson.dataMap(json);
    if (data.isEmpty) return null;
    final session = CallSession.fromJson(data);
    if (session.id.isEmpty) return null;
    return _cacheSession(data);
  }

  Future<CallSession> acceptCall(String callId) async {
    final json = await _client.apiPost('/api/x-live/chats/calls/$callId/accept');
    return _cacheSession(ApiJson.dataMap(json));
  }

  Future<void> declineCall(String callId) async {
    await _client.apiPost('/api/x-live/chats/calls/$callId/decline');
    _tokenCache.remove(callId);
  }

  Future<void> endCall(String callId) async {
    await _client.apiPost('/api/x-live/chats/calls/$callId/end');
    _tokenCache.remove(callId);
  }

  Future<CallSession> updateDmCallMedia(
    String callId, {
    bool? muted,
    bool? cameraOff,
  }) async {
    final body = <String, dynamic>{};
    if (muted != null) body['muted'] = muted;
    if (cameraOff != null) body['cameraOff'] = cameraOff;
    final json = await _client.apiPatch('/api/x-live/chats/calls/$callId/media', body: body);
    return _cacheSession(ApiJson.dataMap(json));
  }

  Future<CallSession> startGroupCall({
    required String groupId,
    CallMediaType callType = CallMediaType.video,
  }) async {
    final json = await _client.apiPost(
      '/api/x-live/groups/$groupId/calls',
      body: {'type': callMediaTypeToApi(callType)},
    );
    return _cacheSession(ApiJson.dataMap(json));
  }

  Future<CallSession?> getActiveGroupCall(String groupId) async {
    final json = await _client.apiGet('/api/x-live/groups/$groupId/calls/active');
    final data = ApiJson.dataMap(json);
    if (data.isEmpty) return null;
    final session = CallSession.fromJson(data);
    if (session.id.isEmpty) return null;
    return _cacheSession(data);
  }

  Future<CallSession> joinGroupCall(String callId) async {
    final json = await _client.apiPost('/api/x-live/groups/calls/$callId/join');
    return _cacheSession(ApiJson.dataMap(json));
  }

  Future<void> leaveGroupCall(String callId) async {
    await _client.apiPost('/api/x-live/groups/calls/$callId/leave');
    _tokenCache.remove(callId);
  }

  Future<void> endGroupCall(String callId) async {
    await _client.apiPost('/api/x-live/groups/calls/$callId/end');
    _tokenCache.remove(callId);
  }

  Future<CallSession> updateGroupCallMedia(
    String callId, {
    bool? muted,
    bool? cameraOff,
  }) async {
    final body = <String, dynamic>{};
    if (muted != null) body['muted'] = muted;
    if (cameraOff != null) body['cameraOff'] = cameraOff;
    final json = await _client.apiPatch('/api/x-live/groups/calls/$callId/media', body: body);
    return _cacheSession(ApiJson.dataMap(json));
  }

  Future<AgoraStreamToken> getToken(String callId) async {
    final cached = _tokenCache[callId];
    if (cached != null && cached.token.isNotEmpty) return cached;
    throw ApiException('Call token unavailable', statusCode: 404);
  }

  CallSession _cacheSession(Map<String, dynamic> data) {
    final session = CallSession.fromJson(data);
    final cred = session.credentials;
    if (session.id.isNotEmpty && cred != null && cred.token.isNotEmpty) {
      _tokenCache[session.id] = cred;
    }
    return session;
  }
}
