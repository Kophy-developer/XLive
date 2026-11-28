import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/utils/safe_text.dart';
import 'chat_theme.dart';

export '../../core/network/chat_message_limits.dart';

const kChatReadMoreThreshold = 700;

class ExpandableChatText extends StatefulWidget {
  const ExpandableChatText({
    super.key,
    required this.text,
    required this.style,
    this.linkColor,
    this.threshold = kChatReadMoreThreshold,
  });

  final String text;
  final TextStyle style;
  final Color? linkColor;
  final int threshold;

  @override
  State<ExpandableChatText> createState() => _ExpandableChatTextState();
}

class _ExpandableChatTextState extends State<ExpandableChatText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final text = widget.text;
    final needsFold = text.runes.length > widget.threshold;
    if (!needsFold || _expanded) {
      if (!needsFold) {
        return Text(text, style: widget.style);
      }
      final linkColor = widget.linkColor ?? ChatTheme.purpleDeep;
      return Text.rich(
        TextSpan(
          style: widget.style,
          children: [
            TextSpan(text: text),
            TextSpan(text: ' '),
            TextSpan(
              text: 'Read less',
              style: widget.style.copyWith(color: linkColor, fontWeight: FontWeight.w700),
              recognizer: TapGestureRecognizer()..onTap = () => setState(() => _expanded = false),
            ),
          ],
        ),
      );
    }

    final clipped = truncateSafely(text, widget.threshold, ellipsis: '').trimRight();
    final linkColor = widget.linkColor ?? ChatTheme.purpleDeep;
    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          TextSpan(text: '$clipped… '),
          TextSpan(
            text: 'Read more',
            style: widget.style.copyWith(color: linkColor, fontWeight: FontWeight.w700),
            recognizer: TapGestureRecognizer()..onTap = () => setState(() => _expanded = true),
          ),
        ],
      ),
    );
  }
}
