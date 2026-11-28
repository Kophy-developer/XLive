import '../../../core/network/api_json.dart';
import '../../feed/models/feed_models.dart';

class UserPublicProfile {
  const UserPublicProfile({
    required this.id,
    this.username,
    this.displayName,
    this.bio,
    this.avatarUrl,
    this.followersCount = 0,
    this.followingCount = 0,
    this.clipsCount = 0,
    this.earnedPoints = 0,
    this.isLive = false,
    this.isFollowing = false,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? bio;
  final String? avatarUrl;
  final int followersCount;
  final int followingCount;
  final int clipsCount;
  final int earnedPoints;
  final bool isLive;
  final bool isFollowing;

  String get handle => username == null || username!.isEmpty ? '@user' : '@$username';

  String get name => displayName ?? username ?? 'User';

  factory UserPublicProfile.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final stats = ApiJson.map(data['stats']) ?? data;
    return UserPublicProfile(
      id: ApiJson.pickString(data, ['id', '_id', 'userId']) ?? '',
      username: ApiJson.pickString(data, ['username', 'handle']),
      displayName: ApiJson.pickString(data, ['displayName', 'name']),
      bio: ApiJson.pickString(data, ['bio', 'about']),
      avatarUrl: ApiJson.pickString(data, ['avatarUrl', 'avatar', 'profileImage']),
      followersCount: ApiJson.pickMetricInt(stats, ['followersCount', 'followerCount', 'followers', 'totalFollowers']),
      followingCount: ApiJson.pickMetricInt(stats, ['followingCount', 'following', 'totalFollowing']),
      clipsCount: ApiJson.pickMetricInt(stats, ['clipsCount', 'clipCount', 'clips']),
      earnedPoints: ApiJson.pickMetricInt(stats, ['earnedPoints', 'points', 'earned', 'totalEarned']),
      isLive: ApiJson.boolValue(data['isLive']) || ApiJson.boolValue(data['liveNow']),
      isFollowing: ApiJson.boolValue(data['isFollowing']) || ApiJson.boolValue(data['following']),
    );
  }
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.type,
    required this.title,
    this.thumbnailUrl,
    this.mediaType,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isLocked = false,
    this.creatorId,
    this.creatorName,
    this.createdAt,
    this.albumSlides = const [],
  });

  final String id;
  final FeedContentType type;
  final String title;
  final String? thumbnailUrl;
  final String? mediaType;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final bool isLocked;
  final String? creatorId;
  final String? creatorName;
  final DateTime? createdAt;
  final List<ContentItem> albumSlides;

  bool get isImage => mediaType?.toLowerCase() == 'image';

  bool get isAlbum => albumSlides.length > 1;

  String get targetType => switch (type) {
        FeedContentType.clip => 'clip',
        FeedContentType.stream => 'stream',
        _ => 'video',
      };

  ContentItem copyWith({
    int? viewCount,
    int? likeCount,
    int? commentCount,
    String? title,
    List<ContentItem>? albumSlides,
  }) {
    return ContentItem(
      id: id,
      type: type,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl,
      mediaType: mediaType,
      viewCount: viewCount ?? this.viewCount,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      isLocked: isLocked,
      creatorId: creatorId,
      creatorName: creatorName,
      createdAt: createdAt,
      albumSlides: albumSlides ?? this.albumSlides,
    );
  }

  factory ContentItem.fromJson(Map<String, dynamic> json) {
    final feed = FeedItem.fromJson(json);
    return ContentItem(
      id: feed.id,
      type: feed.type,
      title: feed.title,
      thumbnailUrl: feed.thumbnailUrl,
      mediaType: feed.mediaType,
      viewCount: feed.viewCount,
      likeCount: feed.likeCount,
      commentCount: feed.commentCount,
      isLocked: ApiJson.boolValue(json['isLocked']) || ApiJson.boolValue(json['locked']) || feed.isLocked,
      creatorId: feed.creatorId,
      creatorName: feed.creatorName,
      createdAt: feed.createdAt,
    );
  }
}

class CommentItem {
  const CommentItem({
    required this.id,
    required this.content,
    this.authorId,
    this.authorName,
    this.authorAvatarUrl,
    this.createdAt,
    this.replyCount = 0,
    this.parentId,
    this.replies = const [],
  });

  final String id;
  final String content;
  final String? authorId;
  final String? authorName;
  final String? authorAvatarUrl;
  final DateTime? createdAt;
  final int replyCount;
  final String? parentId;
  final List<CommentItem> replies;

  factory CommentItem.fromJson(Map<String, dynamic> json) {
    final author = ApiJson.map(json['author']) ?? ApiJson.map(json['user']);
    final repliesRaw = json['replies'];
    final replies = repliesRaw is List
        ? repliesRaw.whereType<Map<String, dynamic>>().map(CommentItem.fromJson).toList()
        : const <CommentItem>[];
    return CommentItem(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      content: ApiJson.pickString(json, ['content', 'text', 'body']) ?? '',
      authorId: author == null
          ? ApiJson.pickString(json, ['authorId', 'userId'])
          : ApiJson.pickString(author, ['id', '_id']),
      authorName: author == null
          ? ApiJson.pickString(json, ['authorName', 'username'])
          : ApiJson.pickString(author, ['username', 'displayName', 'name']),
      authorAvatarUrl: author == null
          ? ApiJson.pickString(json, ['authorAvatarUrl', 'avatarUrl'])
          : ApiJson.pickString(author, ['avatarUrl', 'avatar']),
      createdAt: _parseDate(ApiJson.pickString(json, ['createdAt', 'created_at', 'timestamp'])),
      replyCount: ApiJson.pickInt(json, ['replyCount', 'repliesCount']),
      parentId: ApiJson.pickString(json, ['parentId', 'parentCommentId', 'replyToCommentId']),
      replies: replies,
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  String get timeLabel {
    final date = createdAt;
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}min ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class LikeSummary {
  const LikeSummary({this.count = 0, this.likedByMe = false});

  final int count;
  final bool likedByMe;

  factory LikeSummary.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    return LikeSummary(
      count: ApiJson.pickInt(data, ['count', 'likeCount', 'total', 'likes']),
      likedByMe: ApiJson.boolValue(data['likedByMe']) || ApiJson.boolValue(data['liked']) || ApiJson.boolValue(data['isLiked']),
    );
  }
}

class MediaDetail {
  const MediaDetail({
    required this.id,
    required this.type,
    required this.title,
    this.thumbnailUrl,
    this.streamUrl,
    this.mediaType,
    this.viewCount = 0,
    this.likeCount = 0,
    this.commentCount = 0,
    this.soldCount = 0,
    this.isArchived = false,
    this.creatorId,
    this.creatorName,
    this.isFollowingCreator = false,
    this.createdAt,
    this.unlockPrice = 0,
    this.accessAllowed = true,
    this.needsPurchase = false,
    this.needsUnlock = false,
    this.saveCount = 0,
    this.savedByMe = false,
  });

  final String id;
  final FeedContentType type;
  final String title;
  final String? thumbnailUrl;
  final String? streamUrl;
  final String? mediaType;
  final int viewCount;
  final int likeCount;
  final int commentCount;
  final int soldCount;
  final bool isArchived;
  final String? creatorId;
  final String? creatorName;
  final bool isFollowingCreator;
  final DateTime? createdAt;
  final int unlockPrice;
  final bool accessAllowed;
  final bool needsPurchase;
  final bool needsUnlock;
  final int saveCount;
  final bool savedByMe;

  bool get isLocked => !accessAllowed || needsPurchase || needsUnlock;

  bool get isImage {
    final mt = mediaType?.toLowerCase() ?? '';
    if (mt.contains('video')) return false;
    if (mt.contains('image') || mt.contains('photo')) return true;
    final src = '${thumbnailUrl ?? ''} ${streamUrl ?? ''}'.toLowerCase();
    if (src.contains('/video/upload/') || src.contains('.m3u8') || src.contains('.mp4') || src.contains('.mov')) {
      return false;
    }
    if (src.contains('/image/upload/')) return true;
    return RegExp(r'\.(jpe?g|png|webp|gif|heic)(\?|$)').hasMatch(src);
  }

  String get targetType => switch (type) {
        FeedContentType.clip => 'clip',
        FeedContentType.stream => 'stream',
        _ => 'video',
      };

  factory MediaDetail.fromJson(Map<String, dynamic> json, FeedContentType type) {
    final data = ApiJson.dataMap(json);
    final creator = ApiJson.map(data['creator']) ?? ApiJson.map(data['user']);
    final access = ApiJson.map(data['access']) ?? ApiJson.map(json['access']);
    final allowed = access == null ? true : ApiJson.boolValue(access['allowed'], fallback: true);
    final needsPurchase = access != null && ApiJson.boolValue(access['needsPurchase']);
    final needsUnlock = access != null && ApiJson.boolValue(access['needsUnlock']);
    final titleRaw = ApiJson.pickString(data, ['title', 'name']);
    final captionRaw = ApiJson.pickString(data, ['caption', 'description']);
    final title = () {
      if (titleRaw != null && titleRaw.contains('xlive_album:')) return titleRaw;
      if (captionRaw != null && captionRaw.contains('xlive_album:')) return captionRaw;
      return titleRaw ?? captionRaw ?? 'Untitled';
    }();
    return MediaDetail(
      id: ApiJson.pickString(data, ['id', '_id']) ?? '',
      type: type,
      title: title,
      thumbnailUrl: ApiJson.pickString(data, ['thumbnailUrl', 'thumbnail', 'coverUrl', 'previewUrl']),
      streamUrl: allowed
          ? ApiJson.pickString(data, ['url', 'mediaUrl', 'videoUrl', 'streamUrl', 'playbackUrl', 'fileUrl'])
          : null,
      mediaType: ApiJson.pickString(data, ['mediaType', 'mimeType', 'contentType']),
      viewCount: ApiJson.pickMetricInt(data, ['viewCount', 'views', 'viewerCount']),
      likeCount: ApiJson.pickMetricInt(data, ['likeCount', 'likes']),
      commentCount: ApiJson.pickMetricInt(data, ['commentCount', 'comments']),
      soldCount: ApiJson.pickInt(data, ['soldCount', 'sold', 'editionsSold']),
      isArchived: ApiJson.boolValue(data['isArchived']) || ApiJson.boolValue(data['archived']),
      creatorId: ApiJson.pickString(creator ?? const {}, ['id', '_id']) ??
          ApiJson.pickString(data, ['creatorId', 'userId', 'ownerId', 'hostId']),
      creatorName: ApiJson.pickString(creator ?? const {}, ['displayName', 'username', 'name']) ??
          ApiJson.pickString(data, ['creatorName', 'username', 'displayName', 'hostName']),
      isFollowingCreator: creator == null ? false : ApiJson.boolValue(creator['isFollowing']),
      createdAt: DateTime.tryParse(ApiJson.pickString(data, ['createdAt', 'postedAt', 'publishedAt']) ?? ''),
      unlockPrice: ApiJson.pickInt(data, ['unlockPrice', 'price', 'amount']),
      accessAllowed: allowed,
      needsPurchase: needsPurchase,
      needsUnlock: needsUnlock || needsPurchase || !allowed,
      saveCount: ApiJson.pickMetricInt(data, ['saveCount', 'savesCount', 'bookmarkCount']),
      savedByMe: ApiJson.boolValue(data['savedByMe']) || ApiJson.boolValue(data['isSaved']),
    );
  }
}
