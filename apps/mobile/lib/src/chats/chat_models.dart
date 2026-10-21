class ChatDmPreview {
  const ChatDmPreview({
    required this.name,
    required this.avatarUrl,
    required this.preview,
    this.dateLabel,
    this.timeLabel,
    this.unread,
    this.chatId,
    this.peerUserId,
    this.isLive = false,
  });

  final String name;
  final String avatarUrl;
  final String preview;
  final String? dateLabel;
  final String? timeLabel;
  final int? unread;
  final String? chatId;
  final String? peerUserId;
  final bool isLive;

  ChatDmPreview copyWith({String? preview, String? timeLabel, bool? isLive}) {
    return ChatDmPreview(
      name: name,
      avatarUrl: avatarUrl,
      preview: preview ?? this.preview,
      dateLabel: dateLabel,
      timeLabel: timeLabel ?? this.timeLabel,
      unread: unread,
      chatId: chatId,
      peerUserId: peerUserId,
      isLive: isLive ?? this.isLive,
    );
  }
}

class ChatGroupPreview {
  const ChatGroupPreview({
    required this.name,
    required this.avatarUrl,
    required this.preview,
    this.timeLabel,
    this.unread,
    this.groupId,
    this.chatId,
    this.memberCount,
  });

  final String name;
  final String avatarUrl;
  final String preview;
  final String? timeLabel;
  final int? unread;
  final String? groupId;
  final String? chatId;
  final int? memberCount;

  ChatGroupPreview copyWith({String? preview, String? timeLabel}) {
    return ChatGroupPreview(
      name: name,
      avatarUrl: avatarUrl,
      preview: preview ?? this.preview,
      timeLabel: timeLabel ?? this.timeLabel,
      unread: unread,
      groupId: groupId,
      chatId: chatId,
      memberCount: memberCount,
    );
  }
}

class SuggestedCreatorRow {
  const SuggestedCreatorRow({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.subtitle,
    required this.actionKind,
    this.callPricePerMin,
    this.isLive = false,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final String subtitle;
  final SuggestedActionKind actionKind;
  final int? callPricePerMin;
  final bool isLive;
}

enum SuggestedActionKind { callPerMin, sayHi }

class ExploreGroupRow {
  const ExploreGroupRow({required this.name, required this.avatarUrl, required this.followers, this.groupId});

  final String name;
  final String avatarUrl;
  final int followers;
  final String? groupId;
}
