import 'package:flutter/foundation.dart';

enum GroupThreadRowKind { outgoingText, incomingText, incomingImage, system }

@immutable
class ReactionCount {
  const ReactionCount(this.emoji, this.count);
  final String emoji;
  final int count;
}

@immutable
class GroupThreadMessage {
  const GroupThreadMessage._({
    required this.id,
    required this.kind,
    this.bodyText,
    this.time = '',
    this.avatarUrl,
    this.senderName,
    this.senderId,
    this.imageUrl,
    this.reactions = const [],
    this.replySnippet,
    this.systemText,
  });

  factory GroupThreadMessage.outgoing({
    required String id,
    required String text,
    required String time,
    String? replySnippet,
  }) {
    return GroupThreadMessage._(
      id: id,
      kind: GroupThreadRowKind.outgoingText,
      bodyText: text,
      time: time,
      replySnippet: replySnippet,
    );
  }

  factory GroupThreadMessage.incomingText({
    required String id,
    required String text,
    required String time,
    required String avatarUrl,
    String? senderName,
    String? senderId,
    String? replySnippet,
  }) {
    return GroupThreadMessage._(
      id: id,
      kind: GroupThreadRowKind.incomingText,
      bodyText: text,
      time: time,
      avatarUrl: avatarUrl,
      senderName: senderName,
      senderId: senderId,
      replySnippet: replySnippet,
    );
  }

  factory GroupThreadMessage.incomingImage({
    required String id,
    required String imageUrl,
    required String time,
    required String avatarUrl,
    String? senderName,
    String? senderId,
    List<ReactionCount> reactions = const [],
    String? caption,
    String? replySnippet,
  }) {
    return GroupThreadMessage._(
      id: id,
      kind: GroupThreadRowKind.incomingImage,
      imageUrl: imageUrl,
      time: time,
      avatarUrl: avatarUrl,
      senderName: senderName,
      senderId: senderId,
      reactions: reactions,
      bodyText: caption,
      replySnippet: replySnippet,
    );
  }

  factory GroupThreadMessage.system({required String id, required String text}) {
    return GroupThreadMessage._(id: id, kind: GroupThreadRowKind.system, systemText: text);
  }

  final String id;
  final GroupThreadRowKind kind;
  final String? bodyText;
  final String time;
  final String? avatarUrl;
  final String? senderName;
  final String? senderId;
  final String? imageUrl;
  final List<ReactionCount> reactions;
  final String? replySnippet;
  final String? systemText;
}
