import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../chats/models/chat_api_models.dart';
import '../gifts/gifts_repository.dart';
import '../gifts/models/gift_models.dart';
import '../users/users_repository.dart';
import 'models/stream_models.dart';

class StreamsRepository {
  StreamsRepository({
    ApiClient? client,
    GiftsRepository? giftsRepo,
    UsersRepository? usersRepo,
  })  : _client = client ?? ApiClient(),
        _giftsRepo = giftsRepo ?? GiftsRepository(),
        _usersRepo = usersRepo ?? UsersRepository();

  final ApiClient _client;
  final GiftsRepository _giftsRepo;
  final UsersRepository _usersRepo;

  Future<LiveStream> createStream({
    required String title,
    String? caption,
    String visibility = 'public',
    String chatPolicy = 'everyone',
    String joinPolicy = 'everyone',
    int? durationMinutes,
    List<String> inviteUserIds = const [],
    bool captionsEnabled = true,
    String? captionSourceLanguage,
    bool saveEnabled = true,
  }) async {
    final allowedChat = chatPolicy == 'followers' ? 'followers' : 'everyone';
    final allowedJoin = (joinPolicy == 'followers' || joinPolicy == 'subscribers') ? joinPolicy : 'everyone';
    final body = <String, dynamic>{
      'title': title,
      'caption': caption ?? '',
      'visibility': visibility,
      'chatPolicy': allowedChat,
      'joinPolicy': allowedJoin,
      'inviteUserIds': inviteUserIds,
      'captionsEnabled': captionsEnabled,
      'saveEnabled': saveEnabled,
      'durationMinutes': (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 60,
    };
    if (captionSourceLanguage != null && captionSourceLanguage.trim().isNotEmpty) {
      body['captionSourceLanguage'] = captionSourceLanguage.trim();
    }
    final json = await _client.apiPost('/api/x-live/streams', body: body);
    return LiveStream.fromJson(ApiJson.dataMap(json));
  }

  Future<LiveStream> startStream(String streamId) async {
    final json = await _client.apiPost('/api/x-live/streams/$streamId/start');
    return LiveStream.fromJson(ApiJson.dataMap(json));
  }

  Future<LiveStream> endStream(String streamId) async {
    final json = await _client.apiPost('/api/x-live/streams/$streamId/end');
    return LiveStream.fromJson(ApiJson.dataMap(json));
  }

  Future<List<LiveStream>> listLive({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/streams/live',
      query: {'page': '$page', 'limit': '$limit'},
      auth: false,
    );
    return ApiJson.listItems(json).map(LiveStream.fromJson).where((s) => s.id.isNotEmpty && s.isLive).toList();
  }

  Future<List<LiveStream>> listReplays({
    int page = 1,
    int limit = 20,
    bool mine = false,
    String? userId,
  }) async {
    final query = <String, String>{
      'page': '$page',
      'limit': '$limit',
    };
    if (mine) query['mine'] = 'true';
    if (userId != null && userId.isNotEmpty) query['userId'] = userId;
    final json = await _client.apiGet(
      '/api/x-live/streams/replays',
      query: query,
      auth: mine,
    );
    return ApiJson.listItems(json).map(LiveStream.fromJson).where((s) => s.id.isNotEmpty).toList();
  }

  Future<List<LiveStream>> listMyReplays({int page = 1, int limit = 20}) {
    return listReplays(page: page, limit: limit, mine: true);
  }

  Future<LiveStream> getStream(String streamId) async {
    final json = await _client.apiGet('/api/x-live/streams/$streamId', auth: false);
    return LiveStream.fromJson(ApiJson.dataMap(json));
  }

  Future<StreamReplayDetail> getReplay(String streamId) async {
    final json = await _client.apiGet('/api/x-live/streams/$streamId/replay');
    return StreamReplayDetail.fromJson(json);
  }

  Future<StreamTranscriptDoc> getTranscript(String streamId) async {
    final json = await _client.apiGet('/api/x-live/streams/$streamId/transcript');
    return StreamTranscriptDoc.fromJson(json);
  }

  Future<StreamReplayDetail> uploadReplay({
    required String streamId,
    required String filePath,
    required String filename,
  }) async {
    final json = await _client.apiUploadMultipartFile(
      '/api/x-live/streams/$streamId/replay',
      fieldName: 'file',
      filePath: filePath,
      filename: filename,
    );
    final data = ApiJson.dataMap(json);
    return StreamReplayDetail(
      streamId: ApiJson.pickString(data, ['streamId']) ?? streamId,
      saveEnabled: true,
      replaySaved: true,
      replayUrl: ApiJson.pickString(data, ['replayUrl']),
      thumbnailUrl: ApiJson.pickString(data, ['thumbnailUrl']),
      recordingStatus: ApiJson.pickString(data, ['status', 'recordingStatus']) ?? 'ready',
      transcriptSaved: ApiJson.boolValue(data['transcriptSaved']),
    );
  }

  Future<LiveStream> discardSave(String streamId) async {
    final json = await _client.apiDelete('/api/x-live/streams/$streamId/save');
    return LiveStream.fromJson(ApiJson.dataMap(json));
  }

  Future<AgoraStreamToken> getToken(String streamId, {required String role}) async {
    final json = await _client.apiGet(
      '/api/x-live/streams/$streamId/token',
      query: {'role': role},
    );
    return AgoraStreamToken.fromJson(json);
  }

  Future<List<Map<String, dynamic>>> listStreamChat(String streamId, {int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/streams/$streamId/chat',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json);
  }

  Future<List<StreamGiftRecord>> giftHistory(String streamId, {int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/streams/$streamId/gifts',
      query: {'page': '$page', 'limit': '$limit'},
    );
    final rows = ApiJson.listItems(json).map(StreamGiftRecord.fromJson).where((g) => g.id.isNotEmpty).toList();
    return _enrichStreamGifts(rows);
  }

  Future<List<StreamGiftRecord>> _enrichStreamGifts(List<StreamGiftRecord> rows) async {
    if (rows.isEmpty) return rows;
    List<GiftCatalogItem> catalog = const [];
    try {
      catalog = await _giftsRepo.getCatalog();
    } catch (_) {}
    final byGiftId = {for (final g in catalog) g.id: g};
    final nameCache = <String, String>{};

    Future<String> resolveSender(String? senderId, String? fallback) async {
      final existing = fallback?.trim();
      if (existing != null && existing.isNotEmpty && existing != 'Viewer') return existing;
      final id = senderId?.trim();
      if (id == null || id.isEmpty) return existing?.isNotEmpty == true ? existing! : 'Viewer';
      final cached = nameCache[id];
      if (cached != null) return cached;
      try {
        final user = await _usersRepo.getUser(id);
        final name = user.effectiveDisplayName.trim();
        if (name.isNotEmpty && name != 'User') {
          nameCache[id] = name;
          return name;
        }
      } catch (_) {}
      nameCache[id] = existing?.isNotEmpty == true ? existing! : 'Viewer';
      return nameCache[id]!;
    }

    final out = <StreamGiftRecord>[];
    for (final row in rows) {
      final catalogGift = row.giftId == null ? null : byGiftId[row.giftId];
      final giftName = (catalogGift?.name.trim().isNotEmpty == true)
          ? catalogGift!.name
          : (row.giftName?.trim().isNotEmpty == true ? row.giftName : 'Gift');
      final senderName = await resolveSender(row.senderId, row.senderName);
      final qty = row.quantity <= 0 ? 1 : row.quantity;
      final catalogCoins = (catalogGift?.price ?? 0) * qty;
      out.add(
        row.copyWith(
          giftName: giftName,
          iconUrl: catalogGift?.iconUrl ?? row.iconUrl,
          senderName: senderName,
          points: row.points > 0 ? row.points : catalogCoins,
        ),
      );
    }
    return out;
  }

  Future<List<StreamInviteCandidate>> inviteCandidates(
    String streamId, {
    String source = 'followers',
    String? q,
    int page = 1,
    int limit = 20,
  }) async {
    final query = <String, String>{
      'source': source,
      'page': '$page',
      'limit': '$limit',
    };
    final search = q?.trim();
    if (search != null && search.isNotEmpty) query['q'] = search;
    final json = await _client.apiGet(
      '/api/x-live/streams/$streamId/invite-candidates',
      query: query,
    );
    return ApiJson.listItems(json).map(StreamInviteCandidate.fromJson).where((u) => u.id.isNotEmpty).toList();
  }

  Future<StreamInvite> sendInvite(
    String streamId,
    String userId, {
    String? role,
    int? earningsSplitPercent,
  }) async {
    final body = <String, dynamic>{'userId': userId};
    final roleValue = role?.trim();
    if (roleValue != null && roleValue.isNotEmpty) body['role'] = roleValue;
    if (earningsSplitPercent != null && earningsSplitPercent > 0) {
      body['earningsSplitPercent'] = earningsSplitPercent;
    }
    final json = await _client.apiPost('/api/x-live/streams/$streamId/invites', body: body);
    return StreamInvite.fromJson(ApiJson.dataMap(json));
  }

  Future<StreamInvite> redialInvite(
    String streamId,
    String userId, {
    String? role,
    int? earningsSplitPercent,
  }) {
    return sendInvite(
      streamId,
      userId,
      role: role,
      earningsSplitPercent: earningsSplitPercent,
    );
  }

  Future<StreamCohostsInfo> getCohosts(String streamId) async {
    final json = await _client.apiGet('/api/x-live/streams/$streamId/cohosts');
    return StreamCohostsInfo.fromJson(json);
  }

  Future<List<StreamInvite>> myInvites({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/streams/invites/mine',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(StreamInvite.fromJson).where((i) => i.id.isNotEmpty).toList();
  }

  Future<void> acceptInvite(String inviteId) async {
    await _client.apiPost('/api/x-live/streams/invites/$inviteId/accept');
  }

  Future<void> declineInvite(String inviteId) async {
    await _client.apiPost('/api/x-live/streams/invites/$inviteId/decline');
  }

  Future<List<StreamInvite>> listStreamInvites(String streamId, {int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/streams/$streamId/invites',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(StreamInvite.fromJson).where((i) => i.id.isNotEmpty).toList();
  }

  Future<void> cancelInvite(String inviteId) async {
    await _client.apiDelete('/api/x-live/streams/invites/$inviteId');
  }

  Future<void> removeCohost(String streamId, String userId) async {
    await _client.apiDelete('/api/x-live/streams/$streamId/cohosts/$userId');
  }

  Future<LiveStream> createPrivateStream({
    required String title,
    String? caption,
    String chatPolicy = 'everyone',
    String joinPolicy = 'everyone',
    int? durationMinutes,
    List<String> inviteUserIds = const [],
    double? pricePerMinute,
    bool captionsEnabled = true,
    bool saveEnabled = true,
    bool subscribersOnly = false,
  }) async {
    final allowedChat = chatPolicy == 'followers' ? 'followers' : 'everyone';
    final allowedJoin = subscribersOnly
        ? 'subscribers'
        : (joinPolicy == 'followers' || joinPolicy == 'subscribers' ? joinPolicy : 'everyone');
    final body = <String, dynamic>{
      'title': title,
      'caption': caption ?? '',
      'visibility': 'private',
      'chatPolicy': allowedChat,
      'joinPolicy': allowedJoin,
      'inviteUserIds': inviteUserIds,
      'captionsEnabled': captionsEnabled,
      'saveEnabled': saveEnabled,
      'durationMinutes': (durationMinutes != null && durationMinutes > 0) ? durationMinutes : 60,
    };
    if (pricePerMinute != null) body['pricePerMinute'] = pricePerMinute;
    final json = await _client.apiPost('/api/x-live/streams', body: body);
    return LiveStream.fromJson(ApiJson.dataMap(json));
  }

  Future<ChatMessage> uploadStreamChatFile({
    required String streamId,
    required String filePath,
    required String filename,
    String? content,
    String mediaType = 'document',
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final fields = <String, String>{
      'filename': filename,
      'mediaType': mediaType,
    };
    if (content != null && content.trim().isNotEmpty) fields['content'] = content.trim();
    final json = await _client.apiUploadMultipartFile(
      '/api/x-live/streams/$streamId/chat/upload',
      fieldName: 'file',
      filePath: filePath,
      filename: filename,
      fields: fields,
      onSendProgress: onSendProgress,
    );
    return ChatMessage.fromJson(ApiJson.dataMap(json), currentUserId: AuthSession.instance.user?.id);
  }

  Future<LiveStream> createPrivateSubscriberStream({
    required String title,
    String? caption,
    String chatPolicy = 'everyone',
    int? durationMinutes,
    List<String> inviteUserIds = const [],
    double? pricePerMinute,
    bool captionsEnabled = true,
    bool saveEnabled = true,
  }) {
    return createPrivateStream(
      title: title,
      caption: caption,
      chatPolicy: chatPolicy,
      joinPolicy: 'subscribers',
      durationMinutes: durationMinutes,
      inviteUserIds: inviteUserIds,
      pricePerMinute: pricePerMinute,
      captionsEnabled: captionsEnabled,
      saveEnabled: saveEnabled,
      subscribersOnly: true,
    );
  }
}
