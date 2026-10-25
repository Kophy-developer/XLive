import '../../../core/network/api_json.dart';
import '../chat_media_kind.dart';

class ChatPeer {
  const ChatPeer({
    required this.id,
    this.username,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? avatarUrl;

  String get name => displayName ?? username ?? 'User';

  factory ChatPeer.fromJson(Map<String, dynamic> json) {
    return ChatPeer(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      username: ApiJson.pickString(json, ['username', 'handle']),
      displayName: ApiJson.pickString(json, ['displayName', 'name']),
      avatarUrl: ApiJson.pickString(json, ['avatarUrl', 'avatar']),
    );
  }
}

class ChatThread {
  const ChatThread({
    required this.id,
    this.preview,
    this.timeLabel,
    this.unread = 0,
    this.otherUser,
    this.lastMessageAt,
  });

  final String id;
  final String? preview;
  final String? timeLabel;
  final int unread;
  final ChatPeer? otherUser;
  final DateTime? lastMessageAt;

  factory ChatThread.fromJson(Map<String, dynamic> json) {
    final other = ApiJson.map(json['otherUser']) ?? ApiJson.map(json['participant']) ?? ApiJson.map(json['peer']);
    final last = ApiJson.map(json['lastMessage']);
    final preview = ApiJson.pickString(json, ['preview', 'lastMessagePreview']) ??
        (last == null ? null : ApiJson.pickString(last, ['content', 'text', 'body']));
    final createdAt = parseFlexibleDate(
          json['lastMessageAt'] ??
              json['updatedAt'] ??
              json['createdAt'] ??
              (last == null ? null : (last['createdAt'] ?? last['timestamp'] ?? last['sentAt'])));
    return ChatThread(
      id: ApiJson.pickString(json, ['id', '_id', 'chatId']) ?? '',
      preview: preview,
      timeLabel: createdAt == null ? null : _formatTimeLabel(createdAt),
      unread: ApiJson.pickInt(json, ['unreadCount', 'unread']),
      otherUser: other == null ? null : ChatPeer.fromJson(other),
      lastMessageAt: createdAt,
    );
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed != null) return parsed;
    final asInt = int.tryParse(raw);
    if (asInt == null) return null;
    if (asInt > 9999999999) {
      return DateTime.fromMillisecondsSinceEpoch(asInt, isUtc: true);
    }
    return DateTime.fromMillisecondsSinceEpoch(asInt * 1000, isUtc: true);
  }

  static DateTime? parseFlexibleDate(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is num) {
      final n = raw.toInt();
      if (n > 9999999999) return DateTime.fromMillisecondsSinceEpoch(n, isUtc: true);
      return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
    }
    return _parseDate(raw.toString());
  }

  static String _formatTimeLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
      final m = local.minute.toString().padLeft(2, '0');
      final ap = local.hour >= 12 ? 'PM' : 'AM';
      return '$h:$m $ap';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}';
  }
}

Map<String, List<MessageReaction>> parseReactionMap(Map<String, dynamic> json, String? currentUserId) {
  final data = ApiJson.dataMap(json);
  final src = ApiJson.map(data['reactions']) ?? data;
  final out = <String, List<MessageReaction>>{};
  src.forEach((key, value) {
    if (key == 'data' || key == 'reactions') return;
    if (value is! List && value is! Map) return;
    final list = ChatMessage.parseReactions(value, currentUserId);
    if (list.isNotEmpty) out[key.toString()] = list;
  });
  return out;
}

class MessageReaction {
  const MessageReaction({required this.emoji, this.count = 1, this.mine = false});

  final String emoji;
  final int count;
  final bool mine;

  MessageReaction copyWith({int? count, bool? mine}) =>
      MessageReaction(emoji: emoji, count: count ?? this.count, mine: mine ?? this.mine);
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.chatId,
    this.content,
    this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.createdAt,
    this.isMine = false,
    this.mediaUrl,
    this.mediaType,
    this.reactions = const [],
    this.editedAt,
    this.replyToMessageId,
    this.replyToContent,
    this.replyToSenderName,
  });

  final String id;
  final String chatId;
  final String? content;
  final String? senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final DateTime? createdAt;
  final bool isMine;
  final String? mediaUrl;
  final String? mediaType;
  final List<MessageReaction> reactions;
  final DateTime? editedAt;
  final String? replyToMessageId;
  final String? replyToContent;
  final String? replyToSenderName;

  bool get isEdited => editedAt != null;

  String? get replySnippet {
    final body = replyToContent?.trim();
    final name = replyToSenderName?.trim();
    if ((body == null || body.isEmpty) && (name == null || name.isEmpty)) return null;
    if (body == null || body.isEmpty) return name;
    if (name == null || name.isEmpty) return body;
    return '$name: $body';
  }

  ChatMessage copyWith({
    List<MessageReaction>? reactions,
    String? senderAvatarUrl,
    String? content,
    DateTime? editedAt,
    String? mediaUrl,
    String? mediaType,
  }) {
    return ChatMessage(
      id: id,
      chatId: chatId,
      content: content ?? this.content,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      createdAt: createdAt,
      isMine: isMine,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      mediaType: mediaType ?? this.mediaType,
      reactions: reactions ?? this.reactions,
      editedAt: editedAt ?? this.editedAt,
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );
  }

  bool get hasMedia => mediaUrl != null && mediaUrl!.isNotEmpty;

  String? get resolvedMediaKind => resolveChatMediaKind(mediaType, mediaUrl);

  bool get isImage {
    final kind = resolvedMediaKind;
    return kind == 'image' || kind == 'sticker';
  }

  bool get isSticker => resolvedMediaKind == 'sticker';

  bool get isAudio {
    final kind = resolvedMediaKind;
    return kind == 'audio' || kind == 'voice';
  }

  bool get isVideo => resolvedMediaKind == 'video';

  bool get isDocument => resolvedMediaKind == 'document';

  String get timeLabel {
    final date = createdAt;
    if (date == null) return '';
    final local = date.toLocal();
    final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
    final m = local.minute.toString().padLeft(2, '0');
    final ap = local.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ap';
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? chatId, String? currentUserId}) {
    final payload = ApiJson.map(json['message']) ??
        ApiJson.map(json['data']) ??
        json;
    final sender = ApiJson.map(payload['sender']) ??
        ApiJson.map(payload['author']) ??
        ApiJson.map(payload['user']) ??
        ApiJson.map(json['sender']) ??
        ApiJson.map(json['author']) ??
        ApiJson.map(json['user']);
    final senderId = sender == null
        ? (ApiJson.pickString(payload, ['senderId', 'userId', 'authorId']) ??
            ApiJson.pickString(json, ['senderId', 'userId', 'authorId']))
        : ApiJson.pickString(sender, ['id', '_id']);
    final replyNested = ApiJson.map(payload['replyToMessage']) ??
        ApiJson.map(payload['replyTo']) ??
        ApiJson.map(payload['repliedMessage']) ??
        ApiJson.map(payload['parentMessage']) ??
        ApiJson.map(json['replyToMessage']) ??
        ApiJson.map(json['replyTo']);
    final replyToMessageId = ApiJson.pickString(payload, ['replyToMessageId', 'replyToId', 'parentMessageId']) ??
        ApiJson.pickString(json, ['replyToMessageId', 'replyToId', 'parentMessageId']) ??
        (replyNested == null ? null : ApiJson.pickString(replyNested, ['id', '_id']));
    String? replyToContent = ApiJson.pickString(payload, ['replyToContent', 'replyContent', 'replySnippet']) ??
        ApiJson.pickString(json, ['replyToContent', 'replyContent', 'replySnippet']);
    String? replyToSenderName = ApiJson.pickString(payload, ['replyToSenderName', 'replySenderName']) ??
        ApiJson.pickString(json, ['replyToSenderName', 'replySenderName']);
    if (replyNested != null) {
      replyToContent ??= ApiJson.pickString(replyNested, ['content', 'text', 'body']);
      final replySender =
          ApiJson.map(replyNested['sender']) ?? ApiJson.map(replyNested['author']) ?? ApiJson.map(replyNested['user']);
      replyToSenderName ??= replySender == null
          ? ApiJson.pickString(replyNested, ['senderName'])
          : ApiJson.pickString(replySender, ['displayName', 'username', 'name']);
      if (replyToContent == null || replyToContent.trim().isEmpty) {
        final nestedMediaType = ApiJson.pickString(replyNested, ['mediaType', 'type', 'attachmentType']) ?? '';
        final nestedMediaUrl = ApiJson.pickString(replyNested, ['mediaUrl', 'url', 'attachmentUrl', 'fileUrl']) ?? '';
        final lower = '${nestedMediaType.toLowerCase()} ${nestedMediaUrl.toLowerCase()}';
        if (lower.contains('audio') || lower.contains('voice') || lower.contains('.m4a') || lower.contains('.mp3')) {
          replyToContent = 'Voice note';
        } else if (lower.contains('video') || lower.contains('.mp4') || lower.contains('.mov')) {
          replyToContent = 'Video';
        } else if (nestedMediaUrl.isNotEmpty || lower.contains('image') || lower.contains('photo') || lower.contains('sticker')) {
          replyToContent = 'Photo';
        }
      }
    }
    final attachment = ApiJson.map(payload['attachment']) ??
        ApiJson.map(payload['file']) ??
        ApiJson.map(payload['media']) ??
        ApiJson.map(payload['document']) ??
        ApiJson.map(json['attachment']) ??
        ApiJson.map(json['file']) ??
        ApiJson.map(json['media']);
    final attachments = payload['attachments'] ?? payload['files'] ?? json['attachments'] ?? json['files'];
    final firstAttachment = (attachments is List && attachments.isNotEmpty)
        ? ApiJson.map(attachments.first)
        : null;
    final mediaUrl = ApiJson.pickString(payload, ['mediaUrl', 'url', 'attachmentUrl', 'fileUrl', 'downloadUrl', 'filePath', 'path']) ??
        ApiJson.pickString(json, ['mediaUrl', 'url', 'attachmentUrl', 'fileUrl', 'downloadUrl', 'filePath', 'path']) ??
        (attachment != null ? ApiJson.pickString(attachment, ['url', 'fileUrl', 'mediaUrl', 'downloadUrl', 'path']) : null) ??
        (firstAttachment != null ? ApiJson.pickString(firstAttachment, ['url', 'fileUrl', 'mediaUrl', 'downloadUrl', 'path']) : null);
    final mediaType = resolveChatMediaKind(
      pickChatMediaTypeCandidate(
        mediaType: ApiJson.pickString(payload, ['mediaType']) ?? ApiJson.pickString(json, ['mediaType']),
        attachmentType: ApiJson.pickString(payload, ['attachmentType']) ?? ApiJson.pickString(json, ['attachmentType']),
        fileType: ApiJson.pickString(payload, ['fileType']) ?? ApiJson.pickString(json, ['fileType']),
        mimeType: ApiJson.pickString(payload, ['mimeType']) ??
            ApiJson.pickString(json, ['mimeType']) ??
            (attachment != null ? ApiJson.pickString(attachment, ['mimeType', 'fileType', 'mediaType']) : null) ??
            (firstAttachment != null ? ApiJson.pickString(firstAttachment, ['mimeType', 'fileType', 'mediaType']) : null),
        genericType: ApiJson.pickString(payload, ['type']) ??
            ApiJson.pickString(json, ['type']) ??
            (attachment != null ? ApiJson.pickString(attachment, ['type']) : null) ??
            (firstAttachment != null ? ApiJson.pickString(firstAttachment, ['type']) : null),
      ),
      mediaUrl,
    );
    return ChatMessage(
      id: ApiJson.pickString(payload, ['id', '_id']) ?? ApiJson.pickString(json, ['id', '_id']) ?? '',
      chatId: chatId ?? ApiJson.pickString(payload, ['chatId']) ?? ApiJson.pickString(json, ['chatId']) ?? '',
      content: ApiJson.pickString(payload, ['content', 'text', 'body']) ?? ApiJson.pickString(json, ['content', 'text', 'body']),
      senderId: senderId,
      senderName: sender == null
          ? (ApiJson.pickString(payload, ['senderName']) ?? ApiJson.pickString(json, ['senderName']))
          : ApiJson.pickString(sender, ['displayName', 'username', 'name']),
      senderAvatarUrl: sender == null
          ? (ApiJson.pickString(payload, ['senderAvatarUrl', 'avatarUrl', 'profileImage', 'photoUrl', 'imageUrl']) ??
              ApiJson.pickString(json, ['senderAvatarUrl', 'avatarUrl', 'profileImage', 'photoUrl', 'imageUrl']))
          : ApiJson.pickString(sender, ['avatarUrl', 'avatar', 'profileImage', 'photoUrl', 'imageUrl', 'profilePicture']),
      createdAt: ChatThread.parseFlexibleDate(
            payload['createdAt'] ?? payload['timestamp'] ?? payload['created_at'] ?? payload['sentAt'] ?? payload['updatedAt'] ??
            json['createdAt'] ?? json['timestamp'] ?? json['created_at'] ?? json['sentAt'] ?? json['updatedAt']),
      isMine: currentUserId != null && senderId == currentUserId,
      mediaUrl: mediaUrl,
      mediaType: mediaType,
      reactions: parseReactions(payload['reactions'] ?? json['reactions'], currentUserId),
      editedAt: ChatThread._parseDate(ApiJson.pickString(payload, ['editedAt']) ?? ApiJson.pickString(json, ['editedAt'])),
      replyToMessageId: replyToMessageId,
      replyToContent: replyToContent,
      replyToSenderName: replyToSenderName,
    );
  }

  static List<MessageReaction> parseReactions(Object? raw, String? currentUserId) {
    if (raw == null) return const [];
    if (raw is Map) {
      final out = <MessageReaction>[];
      raw.forEach((key, value) {
        final emoji = key.toString();
        if (emoji.isEmpty) return;
        if (value is num) {
          out.add(MessageReaction(emoji: emoji, count: value.toInt()));
        } else if (value is List) {
          final ids = value.map((e) => e is Map ? ApiJson.pickString(Map<String, dynamic>.from(e), ['id', '_id', 'userId']) : e?.toString()).toList();
          out.add(MessageReaction(emoji: emoji, count: value.length, mine: currentUserId != null && ids.contains(currentUserId)));
        } else if (value is Map) {
          final m = Map<String, dynamic>.from(value);
          out.add(MessageReaction(emoji: emoji, count: ApiJson.pickInt(m, ['count'], fallback: 1), mine: ApiJson.boolValue(m['mine'])));
        }
      });
      return out;
    }
    if (raw is List) {
      final grouped = <String, List<Map<String, dynamic>>>{};
      for (final item in raw) {
        if (item is! Map) continue;
        final m = Map<String, dynamic>.from(item);
        final emoji = ApiJson.pickString(m, ['emoji', 'reaction', 'type']);
        if (emoji == null || emoji.isEmpty) continue;
        grouped.putIfAbsent(emoji, () => []).add(m);
      }
      final out = <MessageReaction>[];
      grouped.forEach((emoji, entries) {
        if (entries.length == 1 && entries.first['count'] != null) {
          final m = entries.first;
          final users = m['users'] ?? m['userIds'];
          var mine = ApiJson.boolValue(m['mine']) || (currentUserId != null && ApiJson.pickString(m, ['userId', 'user', 'id']) == currentUserId);
          if (!mine && users is List && currentUserId != null) {
            mine = users.any((u) => (u is Map ? ApiJson.pickString(Map<String, dynamic>.from(u), ['id', '_id', 'userId']) : u?.toString()) == currentUserId);
          }
          out.add(MessageReaction(emoji: emoji, count: ApiJson.pickInt(m, ['count'], fallback: 1), mine: mine));
        } else {
          final mine = currentUserId != null &&
              entries.any((m) => ApiJson.pickString(m, ['userId', 'user', 'id']) == currentUserId || ApiJson.boolValue(m['mine']));
          out.add(MessageReaction(emoji: emoji, count: entries.length, mine: mine));
        }
      });
      return out;
    }
    return const [];
  }
}

class UnreadSummary {
  const UnreadSummary({this.total = 0, this.dm = 0, this.groups = 0});

  final int total;
  final int dm;
  final int groups;

  factory UnreadSummary.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    return UnreadSummary(
      total: ApiJson.pickInt(data, ['total', 'totalUnread', 'count']),
      dm: ApiJson.pickInt(data, ['dm', 'dmUnread', 'direct']),
      groups: ApiJson.pickInt(data, ['groups', 'groupUnread']),
    );
  }
}

class GroupSummary {
  const GroupSummary({
    required this.id,
    required this.name,
    this.description,
    this.iconUrl,
    this.memberCount = 0,
    this.unread = 0,
    this.preview,
    this.timeLabel,
    this.chatId,
    this.ownerId,
    this.myRole,
    this.joinPolicy = 'everyone',
    this.membersCanChat = true,
    this.onlineCount = 0,
    this.isMember = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? iconUrl;
  final int memberCount;
  final int unread;
  final String? preview;
  final String? timeLabel;
  final String? chatId;
  final String? ownerId;
  final String? myRole;
  final String joinPolicy;
  final bool membersCanChat;
  final int onlineCount;
  final bool isMember;
  final DateTime? createdAt;

  bool get isOwner => myRole == 'owner';

  String get joinPolicyLabel {
    switch (joinPolicy.toLowerCase()) {
      case 'everyone':
        return 'Public';
      case 'followers':
      case 'subscribers':
        return 'Subscribers only';
      case 'invite_only':
        return 'Invite only';
      default:
        if (joinPolicy.isEmpty) return 'Private';
        return joinPolicy[0].toUpperCase() + joinPolicy.substring(1);
    }
  }

  String get roleLabel {
    final role = myRole?.trim();
    if (role == null || role.isEmpty) return isMember ? 'Member' : 'Guest';
    return role[0].toUpperCase() + role.substring(1);
  }

  factory GroupSummary.fromJson(Map<String, dynamic> json) {
    final last = ApiJson.map(json['lastMessage']);
    final preview = ApiJson.pickString(json, ['preview', 'lastMessagePreview']) ??
        (last == null ? null : ApiJson.pickString(last, ['content', 'text']));
    final updated = ChatThread._parseDate(
      ApiJson.pickString(json, ['lastMessageAt', 'updatedAt']) ??
          (last == null ? null : ApiJson.pickString(last, ['createdAt'])),
    );
    final description = ApiJson.pickString(json, ['description', 'about']);
    return GroupSummary(
      id: ApiJson.pickString(json, ['id', '_id', 'groupId']) ?? '',
      name: ApiJson.pickString(json, ['name', 'title']) ?? 'Group',
      description: description,
      iconUrl: ApiJson.pickString(json, ['iconUrl', 'avatarUrl', 'coverUrl']),
      memberCount: ApiJson.pickInt(json, ['memberCount', 'membersCount', 'members']),
      unread: ApiJson.pickInt(json, ['unreadCount', 'unread']),
      preview: preview ?? description,
      timeLabel: updated == null ? null : ChatThread._formatTimeLabel(updated),
      chatId: ApiJson.pickString(json, ['chatId']),
      ownerId: ApiJson.pickString(json, ['ownerId', 'owner', 'createdBy']),
      myRole: ApiJson.pickString(json, ['myRole', 'role']),
      joinPolicy: ApiJson.pickString(json, ['joinPolicy']) ?? 'everyone',
      membersCanChat: json['membersCanChat'] != false,
      onlineCount: ApiJson.pickInt(json, ['onlineCount', 'online']),
      isMember: json['isMember'] != false,
      createdAt: ChatThread._parseDate(ApiJson.pickString(json, ['createdAt'])),
    );
  }
}
