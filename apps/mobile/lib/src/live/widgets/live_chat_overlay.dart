import 'dart:async';

import 'package:flutter/material.dart';

import '../live_theme.dart';

class LiveFloatingComment {
  LiveFloatingComment({
    required this.id,
    required this.sender,
    required this.content,
    this.replyTo,
  });

  final String id;
  final String sender;
  final String content;
  final String? replyTo;
  final DateTime createdAt = DateTime.now();
}

class LiveFloatingComments extends StatefulWidget {
  const LiveFloatingComments({
    super.key,
    required this.comments,
    this.onReply,
    this.onOpen,
    this.isHost = false,
  });

  final List<LiveFloatingComment> comments;
  final void Function(LiveFloatingComment comment)? onReply;
  final VoidCallback? onOpen;
  final bool isHost;

  @override
  State<LiveFloatingComments> createState() => _LiveFloatingCommentsState();
}

class _LiveFloatingCommentsState extends State<LiveFloatingComments> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final visible = widget.comments
        .where((c) => now.difference(c.createdAt) < const Duration(seconds: 4))
        .toList();
    final shown = visible.length > 5 ? visible.sublist(visible.length - 5) : visible;
    if (shown.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: shown.map((c) {
        final opacity = _fadeOpacity(c.createdAt, now);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Opacity(
            opacity: opacity,
            child: GestureDetector(
              onTap: () {
                widget.onOpen?.call();
                if (widget.isHost && widget.onReply != null) widget.onReply!(c);
              },
              child: Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.72),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: LiveTheme.overlay,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: LiveTheme.pillBorder),
                ),
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${c.sender} ',
                        style: const TextStyle(color: LiveTheme.sky, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      if (c.replyTo != null)
                        TextSpan(
                          text: '↩ ${c.replyTo} ',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12),
                        ),
                      TextSpan(
                        text: c.content,
                        style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.25),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  double _fadeOpacity(DateTime created, DateTime now) {
    final elapsed = now.difference(created).inMilliseconds;
    const fadeStart = 2800;
    const fadeEnd = 4000;
    if (elapsed <= fadeStart) return 1;
    if (elapsed >= fadeEnd) return 0;
    return 1 - ((elapsed - fadeStart) / (fadeEnd - fadeStart));
  }
}

class LiveCommentBar extends StatelessWidget {
  const LiveCommentBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.onAttach,
    this.hint = 'Add a comment…',
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onAttach;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.55)],
        ),
      ),
      child: Row(
        children: [
          if (onAttach != null) ...[
            Material(
              color: LiveTheme.pillFill,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAttach,
                child: const SizedBox(
                  width: 44,
                  height: 44,
                  child: Icon(Icons.attach_file_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
                filled: true,
                fillColor: LiveTheme.pillFill,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: LiveTheme.pillBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: LiveTheme.pillBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(999),
                  borderSide: const BorderSide(color: LiveTheme.sky, width: 1.2),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: LiveTheme.purple,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onSend,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveChatHistoryPanel extends StatelessWidget {
  const LiveChatHistoryPanel({
    super.key,
    required this.comments,
    required this.controller,
    required this.onSend,
    required this.onClose,
    this.onAttach,
  });

  final List<LiveFloatingComment> comments;
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onClose;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      child: Column(
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.1),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF111111),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 6, 8),
                    child: Row(
                      children: [
                        const Text('Live chat', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        IconButton(
                          onPressed: onClose,
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white12),
                  Expanded(
                    child: comments.isEmpty
                        ? const Center(
                            child: Text('No comments yet', style: TextStyle(color: Colors.white38, fontSize: 13)),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                            itemCount: comments.length,
                            itemBuilder: (_, i) {
                              final c = comments[i];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CircleAvatar(
                                      radius: 14,
                                      backgroundColor: const Color(0xFF2A2A2A),
                                      child: Text(
                                        c.sender.isNotEmpty ? c.sender[0].toUpperCase() : 'V',
                                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(c.sender, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                                          Text(c.content, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  LiveCommentBar(
                    controller: controller,
                    onSend: onSend,
                    onAttach: onAttach,
                    hint: 'Send a comment…',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
