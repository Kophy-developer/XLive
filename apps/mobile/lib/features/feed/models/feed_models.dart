import '../../../core/network/api_json.dart';

enum FeedContentType { video, clip, stream, unknown }

class FeedItem {
  const FeedItem({
    required this.id,
    required this.type,
    required this.title,
    this.thumbnailUrl,
    this.mediaType,
    this.viewCount = 0,
    this.likeCount = 0,
    this.points = 0,
    this.isNew = false,
    this.creatorId,
    this.creatorName,
    this.creatorAvatarUrl,
    this.commentCount = 0,
    this.status,
    this.createdAt,
    this.accessAllowed = true,
    this.needsPurchase = false,
    this.needsUnlock = false,
    this.unlockPrice = 0,
    this.saveCount = 0,
    this.albumSlides = const [],
    this.creatorIsLive = false,
  });

  final String id;
  final FeedContentType type;
  final String title;
  final String? thumbnailUrl;
  final String? mediaType;
  final int viewCount;
  final int likeCount;
  final int points;
  final bool isNew;
  final String? creatorId;
  final String? creatorName;
  final String? creatorAvatarUrl;
  final int commentCount;
  final String? status;
  final DateTime? createdAt;
  final bool accessAllowed;
  final bool needsPurchase;
  final bool needsUnlock;
  final int unlockPrice;
  final int saveCount;
  final List<FeedItem> albumSlides;
  final bool creatorIsLive;

  bool get isLocked => !accessAllowed || needsPurchase || needsUnlock;

  bool get isImage => mediaType?.toLowerCase() == 'image';

  bool get isAlbum => albumSlides.length > 1;

  bool get isStreamLive {
    if (type != FeedContentType.stream) return false;
    final value = status?.toLowerCase() ?? '';
    if (value == 'live' || value == 'started' || value == 'active' || value == 'broadcasting') {
      return true;
    }
    if (value.isEmpty) return true;
    return false;
  }

  bool get isSavedOrEndedStream {
    if (type != FeedContentType.stream) return false;
    final value = status?.toLowerCase() ?? '';
    return value != 'live' && value != 'started' && value != 'active' && value != 'broadcasting';
  }

  String get targetType => switch (type) {
        FeedContentType.clip => 'clip',
        FeedContentType.stream => 'stream',
        _ => 'video',
      };

  String get displayName {
    final name = creatorName?.trim();
    final caption = title.trim();
    if (name != null && name.isNotEmpty && name != caption && name != 'Untitled') return name;
    return 'Creator';
  }

  FeedItem withDisplayTitle(String displayTitle) {
    return copyWith(title: displayTitle);
  }

  FeedItem copyWithAlbumSlides(List<FeedItem> slides) {
    var nextTitle = title;
    for (final slide in slides) {
      final text = slide.title.trim();
      if (text.isNotEmpty && text != 'Untitled') {
        nextTitle = text;
        break;
      }
    }
    return copyWith(albumSlides: slides, title: slides.isEmpty ? title : nextTitle);
  }

  FeedItem copyWith({
    String? title,
    String? creatorName,
    String? creatorAvatarUrl,
    String? thumbnailUrl,
    DateTime? createdAt,
    bool? accessAllowed,
    bool? needsPurchase,
    bool? needsUnlock,
    int? unlockPrice,
    int? saveCount,
    int? commentCount,
    int? likeCount,
    List<FeedItem>? albumSlides,
    bool? creatorIsLive,
  }) {
    return FeedItem(
      id: id,
      type: type,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mediaType: mediaType,
      viewCount: viewCount,
      likeCount: likeCount ?? this.likeCount,
      points: points,
      isNew: isNew,
      creatorId: creatorId,
      creatorName: creatorName ?? this.creatorName,
      creatorAvatarUrl: creatorAvatarUrl ?? this.creatorAvatarUrl,
      commentCount: commentCount ?? this.commentCount,
      status: status,
      createdAt: createdAt ?? this.createdAt,
      accessAllowed: accessAllowed ?? this.accessAllowed,
      needsPurchase: needsPurchase ?? this.needsPurchase,
      needsUnlock: needsUnlock ?? this.needsUnlock,
      unlockPrice: unlockPrice ?? this.unlockPrice,
      saveCount: saveCount ?? this.saveCount,
      albumSlides: albumSlides ?? this.albumSlides,
      creatorIsLive: creatorIsLive ?? this.creatorIsLive,
    );
  }

  factory FeedItem.fromJson(Map<String, dynamic> json) {
    final normalized = _normalizeFeedJson(json);
    final stream = ApiJson.map(normalized['stream']);
    final creator = ApiJson.map(normalized['creator']) ??
        ApiJson.map(normalized['user']) ??
        ApiJson.map(normalized['author']) ??
        ApiJson.map(normalized['owner']) ??
        ApiJson.map(normalized['host']) ??
        (stream == null ? null : ApiJson.map(stream['creator']) ?? ApiJson.map(stream['host']) ?? ApiJson.map(stream['user']));
    final typeRaw = ApiJson.string(normalized['feedType']) ??
        ApiJson.string(normalized['type']) ??
        ApiJson.string(normalized['contentType']) ??
        ApiJson.string(normalized['targetType']) ??
        ApiJson.string(normalized['kind']) ??
        (stream == null ? null : ApiJson.string(stream['type']));
    final status = ApiJson.pickString(normalized, ['status', 'state']) ??
        (stream == null ? null : ApiJson.pickString(stream, ['status', 'state']));
    var viewCount = ApiJson.pickMetricInt(normalized, ['viewCount', 'views', 'viewerCount', 'watchCount']);
    if (viewCount == 0) {
      viewCount = ApiJson.pickMetricInt(json, ['viewCount', 'views', 'viewerCount', 'watchCount']);
    }
    if (viewCount == 0 && stream != null) {
      viewCount = ApiJson.pickMetricInt(stream, ['viewCount', 'views', 'viewerCount', 'watchCount']);
    }
    var points = ApiJson.pickInt(normalized, ['points', 'giftPoints', 'earnedPoints', 'coinCount']);
    if (points == 0 && stream != null) {
      points = ApiJson.pickInt(stream, ['points', 'giftPoints', 'earnedPoints', 'coinCount']);
    }
    final mediaType = ApiJson.pickString(normalized, ['mediaType', 'media_type']);
    final thumbnailUrl = _pickThumbnail(normalized, stream);
    final titleRaw = ApiJson.pickString(normalized, ['title', 'name']) ??
        (stream == null ? null : ApiJson.pickString(stream, ['title', 'name']));
    final captionRaw = ApiJson.pickString(normalized, ['caption', 'description']) ??
        (stream == null ? null : ApiJson.pickString(stream, ['caption', 'description']));
    final title = () {
      if (titleRaw != null && titleRaw.contains('xlive_album:')) return titleRaw;
      if (captionRaw != null && captionRaw.contains('xlive_album:')) return captionRaw;
      return titleRaw ?? captionRaw ?? 'Untitled';
    }();
    final access = ApiJson.map(json['access']) ?? ApiJson.map(normalized['access']);
    var unlockPrice = ApiJson.pickInt(normalized, ['unlockPrice', 'price', 'amount']);
    if (unlockPrice == 0 && access != null) {
      unlockPrice = ApiJson.pickInt(access, ['unlockPrice', 'price']);
    }
    final allowed = access == null
        ? unlockPrice <= 0
        : ApiJson.boolValue(access['allowed'], fallback: true);
    final needsPurchase = access != null
        ? ApiJson.boolValue(access['needsPurchase'])
        : unlockPrice > 0;
    final needsUnlockFlag = access != null
        ? ApiJson.boolValue(access['needsUnlock'])
        : unlockPrice > 0;
    final createdRaw = ApiJson.pickString(normalized, ['createdAt', 'created_at', 'postedAt', 'publishedAt']) ??
        ApiJson.pickString(json, ['createdAt', 'created_at', 'postedAt', 'publishedAt']) ??
        (stream == null ? null : ApiJson.pickString(stream, ['createdAt', 'startedAt', 'postedAt']));
    var saveCount = ApiJson.pickMetricInt(normalized, ['saveCount', 'savesCount', 'bookmarkCount', 'favoritesCount']);
    if (saveCount == 0) {
      saveCount = ApiJson.pickMetricInt(json, ['saveCount', 'savesCount', 'bookmarkCount']);
    }
    return FeedItem(
      id: ApiJson.pickString(normalized, ['id', '_id', 'streamId']) ??
          (stream == null ? null : ApiJson.pickString(stream, ['id', '_id', 'streamId'])) ??
          '',
      type: _parseType(typeRaw, normalized),
      title: title,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      viewCount: viewCount,
      likeCount: ApiJson.pickMetricInt(normalized, ['likeCount', 'likes', 'totalLikes']),
      points: points,
      isNew: ApiJson.boolValue(normalized['isNew']) || ApiJson.boolValue(normalized['new']),
      creatorId: ApiJson.pickString(creator ?? const {}, ['id', '_id']) ??
          ApiJson.pickString(normalized, ['creatorId', 'userId', 'ownerId', 'hostId']) ??
          ApiJson.pickString(json, ['creatorId', 'userId', 'ownerId', 'hostId']),
      creatorName: ApiJson.pickString(creator ?? const {}, ['username', 'handle']) ??
          ApiJson.pickString(normalized, ['username', 'handle', 'creatorUsername', 'hostUsername']) ??
          ApiJson.pickString(json, ['username', 'handle', 'creatorUsername', 'hostUsername']) ??
          ApiJson.pickString(creator ?? const {}, ['displayName', 'name']) ??
          ApiJson.pickString(normalized, ['creatorName', 'hostName']) ??
          ApiJson.pickString(json, ['creatorName', 'hostName']),
      creatorAvatarUrl: ApiJson.pickString(creator ?? const {}, ['avatarUrl', 'avatar']) ??
          ApiJson.pickString(normalized, ['creatorAvatarUrl', 'avatarUrl', 'avatar', 'hostAvatarUrl']) ??
          ApiJson.pickString(json, ['creatorAvatarUrl', 'avatarUrl', 'avatar', 'hostAvatarUrl']),
      commentCount: ApiJson.pickMetricInt(normalized, ['commentCount', 'comments', 'totalComments']),
      status: status,
      createdAt: DateTime.tryParse(createdRaw ?? ''),
      accessAllowed: allowed,
      needsPurchase: needsPurchase,
      needsUnlock: needsUnlockFlag || needsPurchase || !allowed,
      unlockPrice: unlockPrice,
      saveCount: saveCount,
    );
  }

  static Map<String, dynamic> _normalizeFeedJson(Map<String, dynamic> json) {
    final payload = ApiJson.map(json['data']) ??
        ApiJson.map(json['video']) ??
        ApiJson.map(json['clip']) ??
        ApiJson.map(json['post']) ??
        ApiJson.map(json['stream']);
    if (payload == null) return json;
    final merged = Map<String, dynamic>.from(payload);
    for (final key in ['caption', 'title', 'mediaType', 'thumbnailUrl', 'url', 'mediaUrl']) {
      if (merged[key] == null && json[key] != null) merged[key] = json[key];
    }
    final wrapperId = ApiJson.pickString(json, ['id', '_id']);
    if (wrapperId != null && ApiJson.pickString(merged, ['id', '_id']) == null) {
      merged['id'] = wrapperId;
    }
    final wrapperType = ApiJson.string(json['type']);
    if (wrapperType != null) merged['feedType'] = wrapperType;
    final access = ApiJson.map(json['access']);
    if (access != null) merged['access'] = access;
    return merged;
  }

  static String? _pickThumbnail(Map<String, dynamic> json, Map<String, dynamic>? stream) {
    final keys = ['thumbnailUrl', 'thumbnail', 'coverUrl', 'coverImage', 'previewUrl', 'posterUrl', 'imageUrl', 'url', 'mediaUrl'];
    final direct = ApiJson.pickString(json, keys);
    if (direct != null) return direct;
    if (stream == null) return null;
    return ApiJson.pickString(stream, keys);
  }

  static FeedContentType _parseType(String? raw, Map<String, dynamic> json) {
    final status = ApiJson.pickString(json, ['status'])?.toLowerCase();
    if (status == 'live' ||
        status == 'started' ||
        status == 'active' ||
        status == 'broadcasting') {
      if (json['hostId'] != null || json['agoraChannel'] != null) {
        return FeedContentType.stream;
      }
    }
    final value = raw?.toLowerCase() ?? '';
    if (value.contains('clip')) return FeedContentType.clip;
    if (value.contains('stream') || value.contains('live')) return FeedContentType.stream;
    if (value.contains('video') || value.contains('post') || value.contains('reel') || value.contains('image')) {
      return FeedContentType.video;
    }
    if (json['streamId'] != null || json['isLive'] == true || json['live'] == true) {
      return FeedContentType.stream;
    }
    if (json['clipId'] != null) return FeedContentType.clip;
    return FeedContentType.video;
  }
}
