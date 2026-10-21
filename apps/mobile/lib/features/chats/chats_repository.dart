import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../calls/calls_repository.dart';
import '../calls/models/call_models.dart';
import 'message_upload.dart';
import 'models/chat_api_models.dart';

class ChatsRepository {
  ChatsRepository({ApiClient? client, CallsRepository? callsRepository})
      : _client = client ?? ApiClient(),
        _calls = callsRepository ?? CallsRepository(client: client);

  final ApiClient _client;
  final CallsRepository _calls;

  Future<List<ChatThread>> listChats({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet('/api/x-live/chats', query: {'page': '$page', 'limit': '$limit'});
    return ApiJson.listItems(json).map(ChatThread.fromJson).where((t) => t.id.isNotEmpty).toList();
  }

  Future<UnreadSummary> unreadSummary() async {
    final json = await _client.apiGet('/api/x-live/chats/unread/summary');
    return UnreadSummary.fromJson(json);
  }

  Future<ChatThread> createDm(String participantId) async {
    final json = await _client.apiPost('/api/x-live/chats/dm', body: {'participantId': participantId});
    final data = ApiJson.dataMap(json);
    return ChatThread.fromJson(data);
  }

  Future<List<ChatMessage>> getMessages(String chatId, {int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/chats/$chatId/messages',
      query: {'page': '$page', 'limit': '$limit'},
    );
    final userId = AuthSession.instance.user?.id;
    return ApiJson.listItems(json)
        .map((item) => ChatMessage.fromJson(item, chatId: chatId, currentUserId: userId))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  Future<ChatMessage> sendMessage(
    String chatId, {
    required String content,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      body['replyToMessageId'] = replyToMessageId;
    }
    final json = await _client.apiPost('/api/x-live/chats/$chatId/messages', body: body);
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: chatId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> uploadMessage(
    String chatId, {
    required List<int> bytes,
    required String filename,
    String? content,
    String? mediaType,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final fields = buildChatUploadFields(
      filename: filename,
      content: content,
      mediaType: mediaType,
      replyToMessageId: replyToMessageId,
    );
    final json = await _client.apiUploadMultipart(
      '/api/x-live/chats/$chatId/messages/upload',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      fields: fields,
      onSendProgress: onSendProgress,
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: chatId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> uploadMessageFile(
    String chatId, {
    required String filePath,
    required String filename,
    String? content,
    String? mediaType,
    String? replyToMessageId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final fields = buildChatUploadFields(
      filename: filename,
      content: content,
      mediaType: mediaType,
      replyToMessageId: replyToMessageId,
    );
    final json = await _client.apiUploadMultipartFile(
      '/api/x-live/chats/$chatId/messages/upload',
      fieldName: 'file',
      filePath: filePath,
      filename: filename,
      fields: fields,
      onSendProgress: onSendProgress,
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: chatId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> editMessage(String chatId, String messageId, {required String content}) async {
    final json = await _client.apiPatch(
      '/api/x-live/chats/$chatId/messages/$messageId',
      body: {'content': content},
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: chatId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<void> deleteMessage(String chatId, String messageId) async {
    await _client.apiDelete('/api/x-live/chats/$chatId/messages/$messageId');
  }

  Future<ChatMessage> addReaction(String chatId, String messageId, {required String emoji}) async {
    final json = await _client.apiPost(
      '/api/x-live/chats/$chatId/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: chatId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> removeReaction(String chatId, String messageId, {required String emoji}) async {
    final json = await _client.apiDelete(
      '/api/x-live/chats/$chatId/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: chatId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<Map<String, List<MessageReaction>>> getReactions(String chatId) async {
    final json = await _client.apiGet('/api/x-live/chats/$chatId/reactions');
    return parseReactionMap(json, AuthSession.instance.user?.id);
  }

  Future<List<ChatMessage>> searchChat(String chatId, {required String query}) async {
    final needle = query.trim();
    if (needle.isEmpty) return const [];
    try {
      final json = await _client.apiGet(
        '/api/x-live/chats/$chatId/search',
        query: {'q': needle, 'page': '1', 'limit': '50'},
      );
      final userId = AuthSession.instance.user?.id;
      final hits = ApiJson.listItems(json)
          .map((item) => ChatMessage.fromJson(item, chatId: chatId, currentUserId: userId))
          .where((m) => m.id.isNotEmpty)
          .toList();
      if (hits.isNotEmpty) return hits;
    } catch (_) {}
    final hits = <ChatMessage>[];
    final seen = <String>{};
    final lower = needle.toLowerCase();
    for (var page = 1; page <= 8; page++) {
      final batch = await getMessages(chatId, page: page, limit: 50);
      for (final m in batch) {
        final text = (m.content ?? '').toLowerCase();
        if (text.contains(lower) && seen.add(m.id)) hits.add(m);
      }
      if (batch.length < 50) break;
    }
    return hits;
  }

  Future<void> markRead(String chatId) async {
    await _client.apiPost('/api/x-live/chats/$chatId/read');
  }

  Future<CallSession> startDmCall({
    required String chatId,
    required CallMediaType callType,
  }) =>
      _calls.startDmCall(chatId: chatId, callType: callType);

  Future<CallSession?> getActiveDmCall(String chatId) => _calls.getActiveDmCall(chatId);

  Future<CallSession> acceptCall(String callId) => _calls.acceptCall(callId);

  Future<void> declineCall(String callId) => _calls.declineCall(callId);

  Future<void> endCall(String callId) => _calls.endCall(callId);

  Future<CallSession> updateCallMedia(
    String callId, {
    bool? muted,
    bool? cameraOff,
  }) =>
      _calls.updateDmCallMedia(callId, muted: muted, cameraOff: cameraOff);
}
