import 'package:flutter/material.dart';

import '../../core/widgets/user_avatar.dart';
import 'chat_theme.dart';
import 'expandable_chat_text.dart';
import 'group_thread_models.dart';
import 'reply_quote_bar.dart';

class GroupWelcomeHeader extends StatelessWidget {
  const GroupWelcomeHeader({super.key, required this.groupName, required this.avatarUrl});

  final String groupName;
  final String avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          GroupAvatar(radius: 40, imageUrl: avatarUrl.isEmpty ? null : avatarUrl),
          const SizedBox(height: 16),
          Text('Welcome to', textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ChatTheme.black, height: 1.2)),
          Text(groupName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: ChatTheme.black, height: 1.2)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Chat, react and enjoy your experience on the group',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class GroupSystemEvent extends StatelessWidget {
  const GroupSystemEvent({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(fontSize: 13, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class OutgoingThreadBubble extends StatelessWidget {
  const OutgoingThreadBubble({
    super.key,
    required this.text,
    required this.timeLabel,
    this.replySnippet,
    this.onReplyTap,
  });

  final String text;
  final String timeLabel;
  final String? replySnippet;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: ChatTheme.purple, borderRadius: BorderRadius.circular(20).copyWith(bottomRight: const Radius.circular(6))),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (replySnippet != null)
                ReplyQuoteBar(label: 'Replied: $replySnippet', dense: true, onTap: onReplyTap),
              ExpandableChatText(
                text: text,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.35),
                linkColor: Colors.white,
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.done_all_rounded, size: 16, color: ChatTheme.purpleDeep),
            const SizedBox(width: 4),
            Text(timeLabel, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }
}

class IncomingThreadTextBubble extends StatelessWidget {
  const IncomingThreadTextBubble({
    super.key,
    required this.text,
    required this.time,
    required this.avatarUrl,
    this.senderName,
    this.senderColor,
    this.replySnippet,
    this.onReplyTap,
  });

  final String text;
  final String time;
  final String avatarUrl;
  final String? senderName;
  final Color? senderColor;
  final String? replySnippet;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final name = senderName?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(radius: 16, imageUrl: avatarUrl.isEmpty ? null : avatarUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(4)),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (name != null && name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: senderColor ?? ChatTheme.purpleDeep,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    if (replySnippet != null)
                      ReplyQuoteBar(label: replySnippet!, onTap: onReplyTap),
                    ExpandableChatText(
                      text: text,
                      style: const TextStyle(fontSize: 15, height: 1.35, color: ChatTheme.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class IncomingImageThreadBubble extends StatelessWidget {
  const IncomingImageThreadBubble({
    super.key,
    required this.imageUrl,
    required this.time,
    required this.avatarUrl,
    required this.reactions,
    this.senderName,
    this.senderColor,
    this.caption,
    this.replySnippet,
    this.onReactionTap,
    this.onReplyTap,
  });

  final String imageUrl;
  final String time;
  final String avatarUrl;
  final List<ReactionCount> reactions;
  final String? senderName;
  final Color? senderColor;
  final String? caption;
  final String? replySnippet;
  final VoidCallback? onReactionTap;
  final VoidCallback? onReplyTap;

  static const _kRingLight = 'https://images.unsplash.com/photo-1598387993441-a364f854c3e1?w=800&q=80';

  @override
  Widget build(BuildContext context) {
    final url = imageUrl.isEmpty ? _kRingLight : imageUrl;
    final name = senderName?.trim();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        UserAvatar(radius: 16, imageUrl: avatarUrl.isEmpty ? null : avatarUrl),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (name != null && name.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: senderColor ?? ChatTheme.purpleDeep,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                    if (replySnippet != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                        child: ReplyQuoteBar(label: replySnippet!, onTap: onReplyTap),
                      ),
                    AspectRatio(
                      aspectRatio: 4 / 3,
                      child: Image.network(url, fit: BoxFit.cover),
                    ),
                    if (reactions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: reactions
                              .map(
                                (r) => Material(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(999),
                                  child: InkWell(
                                    onTap: onReactionTap,
                                    borderRadius: BorderRadius.circular(999),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      child: Text('${r.emoji} ${r.count}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    if (caption != null && caption!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(caption!, style: const TextStyle(fontSize: 15, height: 1.35)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(time, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
