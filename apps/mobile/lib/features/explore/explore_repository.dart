import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../chats/models/chat_api_models.dart';
import '../hashtags/hashtags_repository.dart';
import '../streams/models/stream_models.dart';
import '../users/models/user_models.dart';

class ExploreSearchHit {
  const ExploreSearchHit({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.thumbnailUrl,
    this.creatorId,
    this.creatorName,
    this.isLive = false,
    this.isImage = false,
  });

  final String id;
  final String kind;
  final String title;
  final String? subtitle;
  final String? thumbnailUrl;
  final String? creatorId;
  final String? creatorName;
  final bool isLive;
  final bool isImage;
}

class ExploreSearchResult {
  const ExploreSearchResult({
    this.users = const [],
    this.videos = const [],
    this.clips = const [],
    this.streams = const [],
    this.hashtags = const [],
    this.groups = const [],
  });

  final List<XLiveUser> users;
  final List<ExploreSearchHit> videos;
  final List<ExploreSearchHit> clips;
  final List<ExploreSearchHit> streams;
  final List<HashtagItem> hashtags;
  final List<GroupSummary> groups;

  bool get isEmpty =>
      users.isEmpty &&
      videos.isEmpty &&
      clips.isEmpty &&
      streams.isEmpty &&
      hashtags.isEmpty &&
      groups.isEmpty;
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw is! List) return const [];
  return raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
}

class ExploreRepository {
  ExploreRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<ExploreSearchResult> search(String query, {int limit = 12}) async {
    final q = query.trim();
    if (q.isEmpty) return const ExploreSearchResult();
    final json = await _client.apiGet(
      '/api/x-live/explore/search',
      query: {'q': q, 'limit': '$limit'},
      auth: false,
    );
    final data = ApiJson.dataMap(json);
    final users = _maps(data['users']).map(XLiveUser.fromJson).where((u) => u.id.isNotEmpty).toList();
    final hashtags = _maps(data['hashtags']).map(HashtagItem.fromJson).where((h) => h.tag.isNotEmpty).toList();
    final groups = _maps(data['groups']).map(GroupSummary.fromJson).where((g) => g.id.isNotEmpty).toList();
    final videos = _maps(data['videos']).map(_hitFromMedia).where((h) => h.id.isNotEmpty).toList();
    final clips = _maps(data['clips']).map((m) => _hitFromMedia(m, kind: 'clip')).where((h) => h.id.isNotEmpty).toList();
    final streams = _maps(data['streams']).map(_hitFromStream).where((h) => h.id.isNotEmpty).toList();
    return ExploreSearchResult(
      users: users,
      videos: videos,
      clips: clips,
      streams: streams,
      hashtags: hashtags,
      groups: groups,
    );
  }

  ExploreSearchHit _hitFromMedia(Map<String, dynamic> json, {String kind = 'video'}) {
    final user = ApiJson.map(json['user']) ?? ApiJson.map(json['creator']) ?? ApiJson.map(json['host']);
    final mediaType = (ApiJson.pickString(json, ['mediaType', 'type']) ?? '').toLowerCase();
    return ExploreSearchHit(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      kind: kind,
      title: ApiJson.pickString(json, ['caption', 'title', 'name']) ?? 'Untitled',
      subtitle: user == null
          ? ApiJson.pickString(json, ['creatorName', 'username'])
          : ApiJson.pickString(user, ['displayName', 'username', 'name']),
      thumbnailUrl: ApiJson.pickString(json, ['thumbnailUrl', 'mediaUrl', 'previewUrl', 'coverUrl']),
      creatorId: user == null
          ? ApiJson.pickString(json, ['userId', 'creatorId', 'hostId'])
          : ApiJson.pickString(user, ['id', '_id']),
      creatorName: user == null
          ? ApiJson.pickString(json, ['creatorName', 'username'])
          : ApiJson.pickString(user, ['displayName', 'username', 'name']),
      isImage: mediaType.contains('image') || mediaType.contains('photo'),
    );
  }

  ExploreSearchHit _hitFromStream(Map<String, dynamic> json) {
    final stream = LiveStream.fromJson(json);
    final schedule = ApiJson.map(json['schedule']);
    final duration = schedule == null
        ? ApiJson.pickInt(json, ['durationMinutes'])
        : ApiJson.pickInt(schedule, ['durationMinutes']);
    final status = (stream.status ?? '').toLowerCase();
    return ExploreSearchHit(
      id: stream.id,
      kind: 'stream',
      title: stream.title,
      subtitle: [
        if (stream.hostName != null && stream.hostName!.isNotEmpty) stream.hostName!,
        if (duration > 0) '${duration}m',
        if (status.isNotEmpty) status,
      ].join(' · '),
      thumbnailUrl: stream.thumbnailUrl ?? stream.hostAvatarUrl,
      creatorId: stream.hostId,
      creatorName: stream.hostName,
      isLive: stream.isLive,
    );
  }
}
