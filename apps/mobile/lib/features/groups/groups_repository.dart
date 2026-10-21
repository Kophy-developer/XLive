import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../calls/calls_repository.dart';
import '../calls/models/call_models.dart';
import '../chats/message_upload.dart';
import '../chats/models/chat_api_models.dart';
import 'group_join_marker.dart';
import 'models/group_models.dart';

class GroupsRepository {
  GroupsRepository({ApiClient? client, CallsRepository? callsRepository})
      : _client = client ?? ApiClient(),
        _calls = callsRepository ?? CallsRepository(client: client);

  final ApiClient _client;
  final CallsRepository _calls;
  final Map<String, DateTime> _markerSinceCache = {};

  Future<List<GroupSummary>> listMyGroups({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet('/api/x-live/groups', query: {'page': '$page', 'limit': '$limit'});
    return ApiJson.listItems(json).map(GroupSummary.fromJson).where((g) => g.id.isNotEmpty).toList();
  }

  Future<List<GroupSummary>> discoverGroups({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet('/api/x-live/groups/discover', query: {'page': '$page', 'limit': '$limit'});
    return ApiJson.listItems(json).map(GroupSummary.fromJson).where((g) => g.id.isNotEmpty).toList();
  }

  Future<GroupSummary> createGroup({
    required String name,
    String? description,
    String joinPolicy = 'everyone',
    bool membersCanChat = true,
  }) async {
    final json = await _client.apiPost(
      '/api/x-live/groups',
      body: {
        'name': name,
        'description': description ?? '',
        'iconUrl': '',
        'joinPolicy': joinPolicy,
        'membersCanChat': membersCanChat,
      },
    );
    final group = GroupSummary.fromJson(ApiJson.dataMap(json));
    if (group.id.isNotEmpty) {
      await plantJoinMarker(group.id);
    }
    return group;
  }

  Future<GroupSummary> getGroup(String groupId) async {
    final json = await _client.apiGet('/api/x-live/groups/$groupId');
    return GroupSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<GroupSummary> updateGroup(
    String groupId, {
    String? name,
    String? description,
    String? joinPolicy,
    bool? membersCanChat,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (description != null) body['description'] = description;
    if (joinPolicy != null) body['joinPolicy'] = joinPolicy;
    if (membersCanChat != null) body['membersCanChat'] = membersCanChat;
    final json = await _client.apiPatch('/api/x-live/groups/$groupId', body: body);
    return GroupSummary.fromJson(ApiJson.dataMap(json));
  }

  Future<void> deleteGroup(String groupId) async {
    await _client.apiDelete('/api/x-live/groups/$groupId');
    _markerSinceCache.remove(groupId);
  }

  Future<GroupSummary> joinGroup(String groupId) async {
    await _client.apiPost('/api/x-live/groups/$groupId/join');
    await plantJoinMarker(groupId);
    return getGroup(groupId);
  }

  Future<String?> joinByInviteCode(String inviteCode) async {
    final json = await _client.apiGet('/api/x-live/groups/join/$inviteCode');
    final data = ApiJson.dataMap(json);
    final groupId = ApiJson.pickString(data, ['groupId', 'id', '_id']) ??
        ApiJson.pickString(ApiJson.map(data['group']) ?? const {}, ['id', '_id', 'groupId']);
    if (groupId != null && groupId.isNotEmpty) {
      await plantJoinMarker(groupId);
    }
    return groupId;
  }

  Future<void> plantJoinMarker(String groupId) async {
    final content = GroupJoinMarker.myContent;
    if (content == null || groupId.isEmpty) return;
    try {
      final existing = await _findMyJoinMarker(groupId);
      if (existing != null) {
        final at = existing.createdAt?.toUtc();
        if (at != null) _markerSinceCache[groupId] = at;
        return;
      }
      final planted = await sendGroupMessage(groupId, content: content);
      final at = planted.createdAt?.toUtc() ?? DateTime.now().toUtc();
      _markerSinceCache[groupId] = at;
    } catch (_) {}
  }

  Future<DateTime?> resolveVisibleSince(String groupId, {List<ChatMessage>? page}) async {
    final cached = _markerSinceCache[groupId];
    if (cached != null) return cached;
    final marker = await _findMyJoinMarker(groupId, inPage: page);
    final at = marker?.createdAt?.toUtc();
    if (at != null) _markerSinceCache[groupId] = at;
    return at;
  }

  Future<ChatMessage?> _findMyJoinMarker(String groupId, {List<ChatMessage>? inPage}) async {
    if (inPage != null) {
      for (final m in inPage) {
        if (GroupJoinMarker.isMyMarker(m)) return m;
      }
    }
    final query = GroupJoinMarker.searchQuery;
    if (query == null) return null;
    try {
      final hits = await _searchChatRaw(groupId, query: query, limit: 20);
      for (final m in hits) {
        if (GroupJoinMarker.isMyMarker(m)) return m;
      }
    } catch (_) {}
    if (inPage == null) {
      try {
        final page = await _fetchMessagesRaw(groupId, limit: 50);
        for (final m in page) {
          if (GroupJoinMarker.isMyMarker(m)) return m;
        }
      } catch (_) {}
    }
    return null;
  }

  List<ChatMessage> _applyJoinVisibility(List<ChatMessage> items, DateTime? since) {
    return items.where((m) {
      if (GroupJoinMarker.isMarker(m)) return false;
      if (since == null) return true;
      final created = m.createdAt?.toUtc();
      if (created == null) return true;
      return !created.isBefore(since);
    }).toList();
  }

  Future<List<ChatMessage>> _fetchMessagesRaw(String groupId, {int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/groups/$groupId/chat/messages',
      query: {'page': '$page', 'limit': '$limit'},
    );
    final userId = AuthSession.instance.user?.id;
    return ApiJson.listItems(json)
        .map((item) => ChatMessage.fromJson(item, chatId: groupId, currentUserId: userId))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  Future<List<ChatMessage>> _searchChatRaw(
    String groupId, {
    required String query,
    int page = 1,
    int limit = 50,
  }) async {
    final json = await _client.apiGet(
      '/api/x-live/groups/$groupId/chat/search',
      query: {'q': query, 'page': '$page', 'limit': '$limit'},
    );
    final userId = AuthSession.instance.user?.id;
    return ApiJson.listItems(json)
        .map((item) => ChatMessage.fromJson(item, chatId: groupId, currentUserId: userId))
        .where((m) => m.id.isNotEmpty)
        .toList();
  }

  Future<List<ChatMessage>> getGroupMessages(String groupId, {int page = 1, int limit = 50}) async {
    final items = await _fetchMessagesRaw(groupId, page: page, limit: limit);
    final since = await resolveVisibleSince(groupId, page: items);
    return _applyJoinVisibility(items, since);
  }

  Future<ChatMessage> sendGroupMessage(
    String groupId, {
    required String content,
    String? replyToMessageId,
  }) async {
    final body = <String, dynamic>{'content': content};
    if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
      body['replyToMessageId'] = replyToMessageId;
    }
    final json = await _client.apiPost('/api/x-live/groups/$groupId/chat/messages', body: body);
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: groupId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> uploadMessage(
    String groupId, {
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
      '/api/x-live/groups/$groupId/chat/messages/upload',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      fields: fields,
      onSendProgress: onSendProgress,
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: groupId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> uploadMessageFile(
    String groupId, {
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
      '/api/x-live/groups/$groupId/chat/messages/upload',
      fieldName: 'file',
      filePath: filePath,
      filename: filename,
      fields: fields,
      onSendProgress: onSendProgress,
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: groupId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> editMessage(String groupId, String messageId, {required String content}) async {
    final json = await _client.apiPatch(
      '/api/x-live/groups/$groupId/chat/messages/$messageId',
      body: {'content': content},
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: groupId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<void> deleteMessage(String groupId, String messageId) async {
    await _client.apiDelete('/api/x-live/groups/$groupId/chat/messages/$messageId');
  }

  Future<ChatMessage> addReaction(String groupId, String messageId, {required String emoji}) async {
    final json = await _client.apiPost(
      '/api/x-live/groups/$groupId/chat/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: groupId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<ChatMessage> removeReaction(String groupId, String messageId, {required String emoji}) async {
    final json = await _client.apiDelete(
      '/api/x-live/groups/$groupId/chat/messages/$messageId/reactions',
      body: {'emoji': emoji},
    );
    final data = ApiJson.dataMap(json);
    return ChatMessage.fromJson(data, chatId: groupId, currentUserId: AuthSession.instance.user?.id);
  }

  Future<Map<String, List<MessageReaction>>> getReactions(String groupId) async {
    final json = await _client.apiGet('/api/x-live/groups/$groupId/chat/reactions');
    return parseReactionMap(json, AuthSession.instance.user?.id);
  }

  Future<List<ChatMessage>> searchChat(
    String groupId, {
    required String query,
    int page = 1,
    int limit = 50,
  }) async {
    final items = await _searchChatRaw(groupId, query: query, page: page, limit: limit);
    final since = await resolveVisibleSince(groupId);
    return _applyJoinVisibility(items, since);
  }

  Future<void> markGroupRead(String groupId) async {
    await _client.apiPost('/api/x-live/groups/$groupId/chat/read');
  }

  Future<List<GroupMember>> listMembers(String groupId, {int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/groups/$groupId/members',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(GroupMember.fromJson).where((m) => m.id.isNotEmpty).toList();
  }

  Future<GroupMember> addMember(String groupId, String userId) async {
    final json = await _client.apiPost('/api/x-live/groups/$groupId/members', body: {'userId': userId});
    return GroupMember.fromJson(ApiJson.dataMap(json));
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _client.apiDelete('/api/x-live/groups/$groupId/members/$userId');
  }

  Future<GroupMember> updateMemberRole(String groupId, String userId, {required String role}) async {
    final json = await _client.apiPatch(
      '/api/x-live/groups/$groupId/members/$userId',
      body: {'role': role},
    );
    return GroupMember.fromJson(ApiJson.dataMap(json));
  }

  Future<void> transferOwnership(String groupId, {required String userId}) async {
    await _client.apiPost('/api/x-live/groups/$groupId/transfer-ownership', body: {'userId': userId});
  }

  Future<String> regenerateInvite(String groupId) async {
    final json = await _client.apiPost('/api/x-live/groups/$groupId/invite/regenerate');
    return ApiJson.pickString(ApiJson.dataMap(json), ['inviteCode', 'code']) ?? '';
  }

  Future<void> reportGroup(String groupId, {required String reason}) async {
    await _client.apiPost('/api/x-live/groups/$groupId/report', body: {'reason': reason});
  }

  Future<void> reportMessage(String groupId, String messageId, {required String reason}) async {
    await _client.apiPost(
      '/api/x-live/groups/$groupId/chat/messages/$messageId/report',
      body: {'reason': reason},
    );
  }

  Future<void> leaveGroup(String groupId) async {
    await _client.apiPost('/api/x-live/groups/$groupId/leave');
    _markerSinceCache.remove(groupId);
  }

  Future<CallSession> startGroupCall({
    required String groupId,
    CallMediaType callType = CallMediaType.video,
  }) =>
      _calls.startGroupCall(groupId: groupId, callType: callType);

  Future<CallSession?> getActiveGroupCall(String groupId) => _calls.getActiveGroupCall(groupId);

  Future<CallSession> joinGroupCall(String callId) => _calls.joinGroupCall(callId);

  Future<void> leaveGroupCall(String callId) => _calls.leaveGroupCall(callId);

  Future<void> endGroupCall(String callId) => _calls.endGroupCall(callId);

  Future<CallSession> updateGroupCallMedia(
    String callId, {
    bool? muted,
    bool? cameraOff,
  }) =>
      _calls.updateGroupCallMedia(callId, muted: muted, cameraOff: cameraOff);
}
