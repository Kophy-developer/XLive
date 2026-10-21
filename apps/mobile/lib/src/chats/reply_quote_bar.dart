import 'package:flutter/material.dart';

import 'chat_theme.dart';

class ReplyQuoteBar extends StatelessWidget {
  const ReplyQuoteBar({
    super.key,
    required this.label,
    this.dense = false,
    this.onTap,
  });

  final String label;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bar = Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: dense ? 10 : 12, vertical: dense ? 8 : 10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: dense ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: dense ? Colors.white70 : ChatTheme.purple, width: 3)),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: dense ? 12 : 13,
          color: dense ? Colors.white.withValues(alpha: 0.95) : Colors.grey.shade800,
          height: 1.25,
        ),
      ),
    );
    if (onTap == null) return bar;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: bar,
      ),
    );
  }
}
