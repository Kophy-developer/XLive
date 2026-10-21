import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/media/media_url.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/chats/models/chat_api_models.dart';
import 'chat_album.dart';
import 'chat_emoji.dart';
import 'chat_theme.dart';
import 'voice_note_bubble.dart';
import 'chat_media_viewer.dart';
import 'expandable_chat_text.dart';
import 'reply_quote_bar.dart';

class ChatComposerBar extends StatefulWidget {
  const ChatComposerBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.hintText = 'Say something...',
    this.replyingLabel,
    this.onCancelReply,
    this.onAttach,
    this.onSendSticker,
    this.onSendVoice,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final String hintText;
  final String? replyingLabel;
  final VoidCallback? onCancelReply;
  final VoidCallback? onAttach;
  final ValueChanged<String>? onSendSticker;
  final void Function(String path, int durationSeconds)? onSendVoice;

  @override
  State<ChatComposerBar> createState() => _ChatComposerBarState();
}

class _ChatComposerBarState extends State<ChatComposerBar> {
  final _focus = FocusNode();
  bool _showPanel = false;
  bool _hasText = false;

  AudioRecorder? _recorder;
  bool _recording = false;
  bool _busyRecording = false;
  int _recordSeconds = 0;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _recordTimer?.cancel();
    _recorder?.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    if (_busyRecording) return;
    setState(() => _busyRecording = true);
    try {
      final recorder = AudioRecorder();
      final hasPerm = await recorder.hasPermission();
      if (!hasPerm) {
        await recorder.dispose();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone access required')));
        }
        return;
      }
      if (!mounted) {
        await recorder.dispose();
        return;
      }
      FocusScope.of(context).unfocus();
      if (_showPanel) setState(() => _showPanel = false);
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1), path: path);
      _recorder = recorder;
      _recordSeconds = 0;
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordSeconds++);
      });
      if (mounted) setState(() => _recording = true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not start recording: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    final recorder = _recorder;
    _recorder = null;
    if (mounted) setState(() => _recording = false);
    if (recorder != null) {
      try {
        final path = await recorder.stop();
        if (path != null) {
          final f = File(path);
          if (await f.exists()) await f.delete();
        }
      } catch (_) {}
      await recorder.dispose();
    }
  }

  Future<void> _stopAndSend() async {
    _recordTimer?.cancel();
    final recorder = _recorder;
    _recorder = null;
    final seconds = _recordSeconds;
    if (mounted) setState(() => _recording = false);
    if (recorder == null) return;
    String? path;
    try {
      path = await recorder.stop();
    } catch (_) {}
    await recorder.dispose();
    if (path == null || path.isEmpty) return;
    if (seconds < 1) {
      final f = File(path);
      if (await f.exists()) await f.delete();
      return;
    }
    widget.onSendVoice?.call(path, seconds);
  }

  String _fmtRecord(int s) {
    final m = (s ~/ 60).toString();
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _togglePanel() {
    if (!_showPanel) FocusScope.of(context).unfocus();
    setState(() => _showPanel = !_showPanel);
  }

  void _insertEmoji(String emoji) {
    final c = widget.controller;
    final sel = c.selection;
    final text = c.text;
    if (sel.isValid && sel.start >= 0) {
      final newText = text.replaceRange(sel.start, sel.end, emoji);
      c.value = TextEditingValue(text: newText, selection: TextSelection.collapsed(offset: sel.start + emoji.length));
    } else {
      c.text = text + emoji;
      c.selection = TextSelection.collapsed(offset: c.text.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, 8 + (_showPanel ? 0 : MediaQuery.paddingOf(context).bottom)),
      decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFE8E8E8)))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.replyingLabel != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Row(
                children: [
                  Container(width: 3, height: 36, decoration: const BoxDecoration(color: ChatTheme.purple, borderRadius: BorderRadius.all(Radius.circular(2)))),
                  const SizedBox(width: 10),
                  Expanded(child: Text(widget.replyingLabel!, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade800))),
                  IconButton(
                    onPressed: widget.onCancelReply,
                    icon: Icon(Icons.close_rounded, size: 20, color: Colors.grey.shade600),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  ),
                ],
              ),
            ),
          ],
          if (_recording)
            _RecordingBar(
              seconds: _recordSeconds,
              label: _fmtRecord(_recordSeconds),
              onCancel: _cancelRecording,
              onSend: _stopAndSend,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _CircleIconButton(
                  icon: _showPanel ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                  onTap: _togglePanel,
                ),
                if (widget.onAttach != null) ...[
                  const SizedBox(width: 4),
                  _CircleIconButton(icon: Icons.add_circle_outline_rounded, onTap: widget.onAttach!),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    onTap: () {
                      if (_showPanel) setState(() => _showPanel = false);
                    },
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 15),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: const BorderSide(color: ChatTheme.purple, width: 1.2)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Material(
                  color: ChatTheme.purple,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: (!_hasText && widget.onSendVoice != null) ? _startRecording : widget.onSend,
                    child: SizedBox(
                      width: 46,
                      height: 46,
                      child: Icon(
                        (!_hasText && widget.onSendVoice != null) ? Icons.mic_rounded : Icons.send_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_showPanel)
            EmojiStickerPanel(
              onEmoji: _insertEmoji,
              onSticker: widget.onSendSticker == null
                  ? null
                  : (s) {
                      widget.onSendSticker!(s);
                      setState(() => _showPanel = false);
                    },
              bottomInset: MediaQuery.paddingOf(context).bottom,
            ),
        ],
      ),
    );
  }
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.seconds,
    required this.label,
    required this.onCancel,
    required this.onSend,
  });

  final int seconds;
  final String label;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onCancel,
          icon: Icon(Icons.delete_outline_rounded, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              children: [
                const _PulsingDot(),
                const SizedBox(width: 10),
                Text('Recording…', style: TextStyle(color: Colors.grey.shade700, fontSize: 14)),
                const Spacer(),
                Text(label, style: const TextStyle(color: ChatTheme.black, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Material(
          color: ChatTheme.purple,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onSend,
            child: const SizedBox(width: 46, height: 46, child: Icon(Icons.send_rounded, color: Colors.white, size: 22)),
          ),
        ),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.3, end: 1).animate(_c),
      child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: Color(0xFFFF3B5C), shape: BoxShape.circle)),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 40, height: 46, child: Icon(icon, color: Colors.grey.shade600, size: 26)),
      ),
    );
  }
}

class _ReactionChips extends StatelessWidget {
  const _ReactionChips({required this.reactions, required this.onTap, this.alignEnd = false});

  final List<MessageReaction> reactions;
  final ValueChanged<String> onTap;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        alignment: alignEnd ? WrapAlignment.end : WrapAlignment.start,
        children: [
          for (final r in reactions)
            GestureDetector(
              onTap: () => onTap(r.emoji),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: r.mine ? ChatTheme.purple.withValues(alpha: 0.14) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: r.mine ? ChatTheme.purple.withValues(alpha: 0.5) : Colors.grey.shade300),
                ),
                child: Text('${r.emoji}${r.count > 1 ? ' ${r.count}' : ''}', style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

bool isStickerText(String text) {
  final t = text.trim();
  if (t.isEmpty || t.runes.length > 3) return false;
  final emojiRange = RegExp(r'^[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{200D}]+$', unicode: true);
  return emojiRange.hasMatch(t);
}

Widget _bubbleMedia(String url, {required bool sticker, VoidCallback? onTap}) {
  if (sticker) {
    return Image.network(url, width: 120, height: 120, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox());
  }
  final image = ClipRRect(
    borderRadius: BorderRadius.circular(14),
    child: Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(width: 180, height: 120, color: Colors.grey.shade200, child: const Icon(Icons.broken_image_rounded, color: Colors.grey)),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : Container(width: 180, height: 120, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
    ),
  );
  if (onTap == null) return image;
  return GestureDetector(onTap: onTap, child: image);
}

class ChatBubbleMediaCollage extends StatelessWidget {
  const ChatBubbleMediaCollage({
    super.key,
    required this.items,
    required this.maxWidth,
    this.overlayCaption,
  });

  final List<ChatAlbumMediaItem> items;
  final double maxWidth;
  final String? overlayCaption;

  void _open(BuildContext context, int index) {
    final urls = [for (final i in items) i.url];
    final first = items[index];
    if (first.isVideo && items.length == 1) {
      openChatVideoViewer(context, first.url);
      return;
    }
    openChatImageViewer(context, first.url, gallery: urls, initialIndex: index);
  }

  Widget _cell(BuildContext context, ChatAlbumMediaItem item, int index, {String? moreLabel}) {
    return GestureDetector(
      onTap: () => _open(context, index),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item.isVideo)
            Container(
              color: Colors.black87,
              child: const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 36)),
            )
          else
            Image.network(
              item.url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(color: Colors.grey.shade300, child: const Icon(Icons.broken_image_rounded)),
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : Container(color: Colors.grey.shade200, child: const Center(child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          if (item.isVideo && moreLabel == null)
            const Positioned(
              left: 8,
              bottom: 8,
              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
            ),
          if (moreLabel != null)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Text(moreLabel, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    if (items.length == 1) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _cell(context, items.first, 0),
              if (overlayCaption != null && overlayCaption!.trim().isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 36, 12, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000000)],
                        ),
                      ),
                      child: Text(
                        overlayCaption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }

    final visible = items.take(4).toList();
    final extra = items.length - visible.length;
    return SizedBox(
      width: maxWidth,
      child: AspectRatio(
        aspectRatio: 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (visible.length == 2)
                Row(
                  children: [
                    Expanded(child: _cell(context, visible[0], 0)),
                    const SizedBox(width: 2),
                    Expanded(child: _cell(context, visible[1], 1)),
                  ],
                )
              else if (visible.length == 3)
                Row(
                  children: [
                    Expanded(child: _cell(context, visible[0], 0)),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Column(
                        children: [
                          Expanded(child: _cell(context, visible[1], 1)),
                          const SizedBox(height: 2),
                          Expanded(child: _cell(context, visible[2], 2)),
                        ],
                      ),
                    ),
                  ],
                )
              else
                Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _cell(context, visible[0], 0)),
                          const SizedBox(width: 2),
                          Expanded(child: _cell(context, visible[1], 1)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _cell(context, visible[2], 2)),
                          const SizedBox(width: 2),
                          Expanded(
                            child: _cell(
                              context,
                              visible[3],
                              3,
                              moreLabel: extra > 0 ? '+${extra + 1}' : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (overlayCaption != null && overlayCaption!.trim().isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 40, 12, 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0xB3000000)],
                        ),
                      ),
                      child: Text(
                        overlayCaption!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, height: 1.25),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BubbleTimeMeta extends StatelessWidget {
  const _BubbleTimeMeta({
    required this.timeLabel,
    this.edited = false,
    this.showReadReceipt = false,
    this.onAccent = false,
    this.onMedia = false,
  });

  final String timeLabel;
  final bool edited;
  final bool showReadReceipt;
  final bool onAccent;
  final bool onMedia;

  @override
  Widget build(BuildContext context) {
    final Color timeColor;
    if (onMedia) {
      timeColor = Colors.white.withValues(alpha: 0.95);
    } else if (onAccent) {
      timeColor = Colors.white.withValues(alpha: 0.72);
    } else {
      timeColor = const Color(0xFF8E8E93);
    }
    final checkColor = onMedia || onAccent ? Colors.white.withValues(alpha: 0.9) : ChatTheme.purpleDeep;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (edited) ...[
          Text(
            'edited',
            style: TextStyle(
              fontSize: 10,
              height: 1,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
              color: timeColor.withValues(alpha: onMedia ? 0.85 : (onAccent ? 0.65 : 0.85)),
            ),
          ),
          const SizedBox(width: 4),
        ],
        Text(
          timeLabel,
          style: TextStyle(
            fontSize: 11,
            height: 1,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.15,
            color: timeColor,
          ),
        ),
        if (showReadReceipt) ...[
          const SizedBox(width: 3),
          Icon(Icons.done_all_rounded, size: 14, color: checkColor),
        ],
      ],
    );
  }
}

class _MediaTimeOverlay extends StatelessWidget {
  const _MediaTimeOverlay({
    required this.timeLabel,
    this.edited = false,
    this.showReadReceipt = false,
  });

  final String timeLabel;
  final bool edited;
  final bool showReadReceipt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: _BubbleTimeMeta(
        timeLabel: timeLabel,
        edited: edited,
        showReadReceipt: showReadReceipt,
        onMedia: true,
      ),
    );
  }
}

class _EmbeddedTextBody extends StatelessWidget {
  const _EmbeddedTextBody({
    required this.text,
    required this.timeLabel,
    required this.onAccent,
    this.edited = false,
    this.showReadReceipt = false,
    this.quote,
    this.onReplyTap,
  });

  final String text;
  final String timeLabel;
  final bool onAccent;
  final bool edited;
  final bool showReadReceipt;
  final String? quote;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final fg = onAccent ? Colors.white : ChatTheme.black;
    final linkColor = onAccent ? Colors.white : ChatTheme.purpleDeep;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (quote != null && quote!.isNotEmpty)
          ReplyQuoteBar(label: quote!, dense: onAccent, onTap: onReplyTap),
        ExpandableChatText(
          text: text,
          style: TextStyle(color: fg, fontSize: 15.5, height: 1.32, letterSpacing: -0.15),
          linkColor: linkColor,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: _BubbleTimeMeta(
            timeLabel: timeLabel,
            edited: edited,
            showReadReceipt: showReadReceipt,
            onAccent: onAccent,
          ),
        ),
      ],
    );
  }
}

Widget _wrapMediaWithTimestamp({
  required Widget child,
  required String timeLabel,
  bool edited = false,
  bool showReadReceipt = false,
  required double maxWidth,
}) {
  final showMeta = timeLabel.trim().isNotEmpty;
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: showMeta
        ? ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              children: [
                child,
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 28, 8, 8),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.18),
                            Colors.transparent,
                          ],
                          stops: const [0, 0.45, 1],
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: _MediaTimeOverlay(
                          timeLabel: timeLabel,
                          edited: edited,
                          showReadReceipt: showReadReceipt,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        : child,
  );
}

class ChatDocumentBubble extends StatelessWidget {
  const ChatDocumentBubble({
    super.key,
    required this.url,
    this.name,
    required this.mine,
    required this.timeLabel,
    this.showReadReceipt = false,
    this.edited = false,
  });

  final String url;
  final String? name;
  final bool mine;
  final String timeLabel;
  final bool showReadReceipt;
  final bool edited;

  String get _displayName {
    final explicit = name?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final clean = url.split('?').first;
    final last = clean.split(Platform.pathSeparator).last;
    return last.isEmpty ? 'Document' : last;
  }

  String get _extension {
    final dn = _displayName.toLowerCase();
    final dot = dn.lastIndexOf('.');
    if (dot >= 0 && dot < dn.length - 1) {
      return dn.substring(dot + 1).toUpperCase();
    }
    return 'DOC';
  }

  Future<void> _open(BuildContext context) async {
    final resolved = resolveMediaUrl(url);
    if (resolved.isEmpty) return;
    final ext = _extension.toUpperCase();
    if (['JPG', 'JPEG', 'PNG', 'WEBP', 'GIF'].contains(ext)) {
      openChatImageViewer(context, resolved);
      return;
    }
    try {
      final uri = Uri.parse(resolved);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    final bgColor = mine ? ChatTheme.purple : const Color(0xFFF3F4F6);
    final textColor = mine ? Colors.white : const Color(0xFF0A0A0A);
    final subColor = mine ? Colors.white70 : Colors.black54;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _open(context),
      child: Container(
        constraints: BoxConstraints(maxWidth: maxW),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: mine ? const Radius.circular(5) : const Radius.circular(16),
            bottomLeft: mine ? const Radius.circular(16) : const Radius.circular(5),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: mine ? Colors.white.withValues(alpha: 0.18) : ChatTheme.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _extension,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: mine ? Colors.white : ChatTheme.purple,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Tap to view / download',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: subColor),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_downward_rounded,
                  size: 20,
                  color: mine ? Colors.white70 : Colors.black45,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (edited) ...[
                    Text('edited', style: TextStyle(fontSize: 10, color: subColor)),
                    const SizedBox(width: 4),
                  ],
                  Text(timeLabel, style: TextStyle(fontSize: 11, color: subColor, fontWeight: FontWeight.w500)),
                  if (mine && showReadReceipt) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.done_all_rounded, size: 14, color: subColor),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SentMessageBubble extends StatelessWidget {
  const SentMessageBubble({
    super.key,
    required this.text,
    required this.timeLabel,
    this.showReadReceipt = true,
    this.imageUrl,
    this.imageUrls,
    this.albumMedia,
    this.audioUrl,
    this.videoUrl,
    this.documentUrl,
    this.documentName,
    this.isSticker = false,
    this.reactions = const [],
    this.onReactionTap,
    this.edited = false,
    this.replySnippet,
    this.onReplyTap,
  });

  final String text;
  final String timeLabel;
  final bool showReadReceipt;
  final String? imageUrl;
  final List<String>? imageUrls;
  final List<ChatAlbumMediaItem>? albumMedia;
  final String? audioUrl;
  final String? videoUrl;
  final String? documentUrl;
  final String? documentName;
  final bool isSticker;
  final List<MessageReaction> reactions;
  final ValueChanged<String>? onReactionTap;
  final bool edited;
  final String? replySnippet;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final slides = <ChatAlbumMediaItem>[
      if (albumMedia != null)
        ...albumMedia!
      else ...[
        if (imageUrls != null)
          for (final u in imageUrls!)
            if (u.trim().isNotEmpty) ChatAlbumMediaItem(url: u.trim())
        else if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          ChatAlbumMediaItem(url: imageUrl!.trim()),
        if ((albumMedia == null || albumMedia!.isEmpty) &&
            (imageUrls == null || imageUrls!.isEmpty) &&
            (imageUrl == null || imageUrl!.trim().isEmpty) &&
            videoUrl != null &&
            videoUrl!.trim().isNotEmpty)
          ChatAlbumMediaItem(url: videoUrl!.trim(), isVideo: true),
      ],
    ];
    final hasImage = slides.any((s) => !s.isVideo);
    final hasVideo = slides.any((s) => s.isVideo) || (videoUrl != null && videoUrl!.isNotEmpty && slides.isEmpty);
    final hasAudio = audioUrl != null && audioUrl!.isNotEmpty;
    final stickerText = slides.isEmpty && !hasVideo && !hasAudio && isStickerText(text);
    final quote = replySnippet?.trim();
    final hasQuote = quote != null && quote.isNotEmpty;
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    final mediaMaxW = MediaQuery.sizeOf(context).width * (slides.length > 1 ? 0.72 : 0.64);
    final captionText = text.trim();
    final caption = captionText.isNotEmpty && !isStickerText(text);
    final overlayCaption = null;
    final belowCaption = caption && slides.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (documentUrl != null && documentUrl!.isNotEmpty) ...[
          if (hasQuote)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: ChatTheme.purple,
                  borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(6)),
                ),
                child: ReplyQuoteBar(label: quote, dense: true, onTap: onReplyTap),
              ),
            ),
          ChatDocumentBubble(
            url: documentUrl!,
            name: documentName ?? (captionText.isNotEmpty ? captionText : null),
            mine: true,
            timeLabel: timeLabel,
            showReadReceipt: showReadReceipt,
            edited: edited,
          ),
        ] else if (hasAudio) ...[
          if (hasQuote)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                decoration: BoxDecoration(
                  color: ChatTheme.purple,
                  borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(6)),
                ),
                child: ReplyQuoteBar(label: quote, dense: true, onTap: onReplyTap),
              ),
            ),
          VoiceNoteBubble(
            url: audioUrl!,
            mine: true,
            timeLabel: timeLabel,
            edited: edited,
            showReadReceipt: showReadReceipt,
          ),
        ] else if (hasVideo || hasImage || slides.isNotEmpty) ...[
          if (hasQuote)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Container(
                padding: const EdgeInsets.fromLTRB(12, 10, 10, 8),
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: ChatTheme.purple,
                  borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(6)),
                ),
                child: ReplyQuoteBar(label: quote, dense: true, onTap: onReplyTap),
              ),
            ),
          if (isSticker && slides.length == 1 && !slides.first.isVideo)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _bubbleMedia(slides.first.url, sticker: true, onTap: () => openChatImageViewer(context, slides.first.url)),
                const SizedBox(height: 4),
                _BubbleTimeMeta(
                  timeLabel: timeLabel,
                  edited: edited,
                  showReadReceipt: showReadReceipt,
                  onAccent: false,
                ),
              ],
            )
          else if (belowCaption)
            Container(
              constraints: BoxConstraints(maxWidth: mediaMaxW),
              decoration: BoxDecoration(
                color: ChatTheme.purple,
                borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(5)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: (slides.length == 1 && slides.first.isVideo)
                          ? ChatVideoBubble(url: slides.first.url, mine: true)
                          : ChatBubbleMediaCollage(
                              items: slides.isNotEmpty
                                  ? slides
                                  : [
                                      if (videoUrl != null && videoUrl!.isNotEmpty)
                                        ChatAlbumMediaItem(url: videoUrl!, isVideo: true),
                                    ],
                              maxWidth: mediaMaxW,
                              overlayCaption: null,
                            ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                    child: _EmbeddedTextBody(
                      text: text,
                      timeLabel: timeLabel,
                      onAccent: true,
                      edited: edited,
                      showReadReceipt: showReadReceipt,
                    ),
                  ),
                ],
              ),
            )
          else if (slides.length == 1 && slides.first.isVideo && overlayCaption == null)
            _wrapMediaWithTimestamp(
              maxWidth: mediaMaxW,
              timeLabel: timeLabel,
              edited: edited,
              showReadReceipt: showReadReceipt,
              child: ChatVideoBubble(url: slides.first.url, mine: true),
            )
          else
            _wrapMediaWithTimestamp(
              maxWidth: mediaMaxW,
              timeLabel: timeLabel,
              edited: edited,
              showReadReceipt: showReadReceipt,
              child: ChatBubbleMediaCollage(
                items: slides.isNotEmpty
                    ? slides
                    : [
                        if (videoUrl != null && videoUrl!.isNotEmpty)
                          ChatAlbumMediaItem(url: videoUrl!, isVideo: true),
                      ],
                maxWidth: mediaMaxW,
                overlayCaption: overlayCaption,
              ),
            ),
        ] else if (stickerText)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(text, style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 2),
              _BubbleTimeMeta(
                timeLabel: timeLabel,
                edited: edited,
                showReadReceipt: showReadReceipt,
              ),
            ],
          )
        else
          Container(
            constraints: BoxConstraints(maxWidth: maxW),
            padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
            decoration: BoxDecoration(
              color: ChatTheme.purple,
              borderRadius: BorderRadius.circular(18).copyWith(bottomRight: const Radius.circular(5)),
              boxShadow: [
                BoxShadow(
                  color: ChatTheme.purple.withValues(alpha: 0.18),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _EmbeddedTextBody(
              text: text,
              timeLabel: timeLabel,
              onAccent: true,
              edited: edited,
              showReadReceipt: showReadReceipt,
              quote: hasQuote ? quote : null,
              onReplyTap: onReplyTap,
            ),
          ),
        if (reactions.isNotEmpty && onReactionTap != null)
          _ReactionChips(reactions: reactions, onTap: onReactionTap!, alignEnd: true),
      ],
    );
  }
}

class ReceivedMessageBubble extends StatelessWidget {
  const ReceivedMessageBubble({
    super.key,
    required this.text,
    required this.timeLabel,
    required this.avatarUrl,
    this.senderName,
    this.senderColor,
    this.imageUrl,
    this.imageUrls,
    this.albumMedia,
    this.audioUrl,
    this.videoUrl,
    this.documentUrl,
    this.documentName,
    this.isSticker = false,
    this.reactions = const [],
    this.onReactionTap,
    this.onAvatarTap,
    this.edited = false,
    this.replySnippet,
    this.onReplyTap,
  });

  final String text;
  final String timeLabel;
  final String avatarUrl;
  final String? senderName;
  final Color? senderColor;
  final String? imageUrl;
  final List<String>? imageUrls;
  final List<ChatAlbumMediaItem>? albumMedia;
  final String? audioUrl;
  final String? videoUrl;
  final String? documentUrl;
  final String? documentName;
  final bool isSticker;
  final List<MessageReaction> reactions;
  final ValueChanged<String>? onReactionTap;
  final VoidCallback? onAvatarTap;
  final bool edited;
  final String? replySnippet;
  final VoidCallback? onReplyTap;

  @override
  Widget build(BuildContext context) {
    final slides = <ChatAlbumMediaItem>[
      if (albumMedia != null)
        ...albumMedia!
      else ...[
        if (imageUrls != null)
          for (final u in imageUrls!)
            if (u.trim().isNotEmpty) ChatAlbumMediaItem(url: u.trim())
        else if (imageUrl != null && imageUrl!.trim().isNotEmpty)
          ChatAlbumMediaItem(url: imageUrl!.trim()),
        if ((albumMedia == null || albumMedia!.isEmpty) &&
            (imageUrls == null || imageUrls!.isEmpty) &&
            (imageUrl == null || imageUrl!.trim().isEmpty) &&
            videoUrl != null &&
            videoUrl!.trim().isNotEmpty)
          ChatAlbumMediaItem(url: videoUrl!.trim(), isVideo: true),
      ],
    ];
    final hasImage = slides.any((s) => !s.isVideo);
    final hasVideo = slides.any((s) => s.isVideo) || (videoUrl != null && videoUrl!.isNotEmpty && slides.isEmpty);
    final hasAudio = audioUrl != null && audioUrl!.isNotEmpty;
    final stickerText = slides.isEmpty && !hasVideo && !hasAudio && isStickerText(text);
    final quote = replySnippet?.trim();
    final hasQuote = quote != null && quote.isNotEmpty;
    final maxW = MediaQuery.sizeOf(context).width * 0.72;
    final mediaMaxW = MediaQuery.sizeOf(context).width * (slides.length > 1 ? 0.72 : 0.64);
    final captionText = text.trim();
    final caption = captionText.isNotEmpty && !isStickerText(text);
    final overlayCaption = null;
    final belowCaption = caption && slides.isNotEmpty;
    final name = senderName?.trim();
    final showName = name != null && name.isNotEmpty;
    final nameColor = senderColor ?? ChatTheme.purpleDeep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: UserAvatar(radius: 16, imageUrl: avatarUrl.isEmpty ? null : avatarUrl),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (documentUrl != null && documentUrl!.isNotEmpty) ...[
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nameColor, letterSpacing: -0.1),
                    ),
                  ),
                if (hasQuote) ReplyQuoteBar(label: quote, onTap: onReplyTap),
                ChatDocumentBubble(
                  url: documentUrl!,
                  name: documentName ?? (captionText.isNotEmpty ? captionText : null),
                  mine: false,
                  timeLabel: timeLabel,
                  showReadReceipt: false,
                  edited: edited,
                ),
              ] else if (hasAudio) ...[
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nameColor, letterSpacing: -0.1),
                    ),
                  ),
                if (hasQuote) ReplyQuoteBar(label: quote, onTap: onReplyTap),
                VoiceNoteBubble(
                  url: audioUrl!,
                  mine: false,
                  timeLabel: timeLabel,
                  edited: edited,
                ),
              ] else if (hasVideo || hasImage || slides.isNotEmpty) ...[
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nameColor, letterSpacing: -0.1),
                    ),
                  ),
                if (hasQuote) ReplyQuoteBar(label: quote, onTap: onReplyTap),
                if (isSticker && slides.length == 1 && !slides.first.isVideo)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bubbleMedia(slides.first.url, sticker: true, onTap: () => openChatImageViewer(context, slides.first.url)),
                      const SizedBox(height: 4),
                      _BubbleTimeMeta(timeLabel: timeLabel, edited: edited),
                    ],
                  )
                else if (belowCaption)
                  Container(
                    constraints: BoxConstraints(maxWidth: mediaMaxW),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: const Radius.circular(5)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(3, 3, 3, 0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: (slides.length == 1 && slides.first.isVideo)
                                ? ChatVideoBubble(url: slides.first.url, mine: false)
                                : ChatBubbleMediaCollage(
                                    items: slides.isNotEmpty
                                        ? slides
                                        : [
                                            if (videoUrl != null && videoUrl!.isNotEmpty)
                                              ChatAlbumMediaItem(url: videoUrl!, isVideo: true),
                                          ],
                                    maxWidth: mediaMaxW,
                                    overlayCaption: null,
                                  ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                          child: _EmbeddedTextBody(
                            text: text,
                            timeLabel: timeLabel,
                            onAccent: false,
                            edited: edited,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (slides.length == 1 && slides.first.isVideo && overlayCaption == null)
                  _wrapMediaWithTimestamp(
                    maxWidth: mediaMaxW,
                    timeLabel: timeLabel,
                    edited: edited,
                    child: ChatVideoBubble(url: slides.first.url, mine: false),
                  )
                else
                  _wrapMediaWithTimestamp(
                    maxWidth: mediaMaxW,
                    timeLabel: timeLabel,
                    edited: edited,
                    child: ChatBubbleMediaCollage(
                      items: slides.isNotEmpty
                          ? slides
                          : [
                              if (videoUrl != null && videoUrl!.isNotEmpty)
                                ChatAlbumMediaItem(url: videoUrl!, isVideo: true),
                            ],
                      maxWidth: mediaMaxW,
                      overlayCaption: overlayCaption,
                    ),
                  ),
              ] else if (stickerText)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showName)
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nameColor, letterSpacing: -0.1),
                        ),
                      ),
                    Text(text, style: const TextStyle(fontSize: 52)),
                    const SizedBox(height: 2),
                    _BubbleTimeMeta(timeLabel: timeLabel, edited: edited),
                  ],
                )
              else
                Container(
                  constraints: BoxConstraints(maxWidth: maxW),
                  padding: const EdgeInsets.fromLTRB(12, 8, 10, 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18).copyWith(bottomLeft: const Radius.circular(5)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showName)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: nameColor, letterSpacing: -0.1),
                          ),
                        ),
                      _EmbeddedTextBody(
                        text: text,
                        timeLabel: timeLabel,
                        onAccent: false,
                        edited: edited,
                        quote: hasQuote ? quote : null,
                        onReplyTap: onReplyTap,
                      ),
                    ],
                  ),
                ),
              if (reactions.isNotEmpty && onReactionTap != null)
                _ReactionChips(reactions: reactions, onTap: onReactionTap!),
            ],
          ),
        ),
      ],
    );
  }
}
