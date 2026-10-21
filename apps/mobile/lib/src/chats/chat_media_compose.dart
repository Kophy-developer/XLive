import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'chat_album.dart';
import 'chat_theme.dart';

class ChatMediaComposeResult {
  const ChatMediaComposeResult({required this.path, required this.isVideo, this.caption});

  final String path;
  final bool isVideo;
  final String? caption;
}

Future<ChatMediaComposeResult?> openChatMediaCompose(
  BuildContext context, {
  required String path,
  required bool isVideo,
}) {
  return Navigator.push<ChatMediaComposeResult>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChatMediaComposeScreen(path: path, isVideo: isVideo),
    ),
  );
}

Future<List<ChatMediaComposeResult>?> openChatMediaComposeBatch(
  BuildContext context, {
  required List<({String path, bool isVideo})> items,
}) {
  if (items.isEmpty) return Future.value(null);
  if (items.length == 1) {
    return openChatMediaCompose(context, path: items.first.path, isVideo: items.first.isVideo)
        .then((r) => r == null ? null : [r]);
  }
  return Navigator.push<List<ChatMediaComposeResult>>(
    context,
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => ChatMediaComposeBatchScreen(items: items),
    ),
  );
}

class ChatMediaComposeScreen extends StatefulWidget {
  const ChatMediaComposeScreen({super.key, required this.path, required this.isVideo});

  final String path;
  final bool isVideo;

  @override
  State<ChatMediaComposeScreen> createState() => _ChatMediaComposeScreenState();
}

class _ChatMediaComposeScreenState extends State<ChatMediaComposeScreen> {
  final _caption = TextEditingController();
  VideoPlayerController? _player;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(File(widget.path));
    _player = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    _player?.dispose();
    super.dispose();
  }

  void _send() {
    Navigator.pop(
      context,
      ChatMediaComposeResult(
        path: widget.path,
        isVideo: widget.isVideo,
        caption: _caption.text.trim().isEmpty ? null : _caption.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    widget.isVideo ? 'Send video' : 'Send photo',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: widget.isVideo
                      ? (_ready && _player != null && _player!.value.isInitialized
                          ? Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.contain,
                                  child: SizedBox(
                                    width: _player!.value.size.width,
                                    height: _player!.value.size.height,
                                    child: VideoPlayer(_player!),
                                  ),
                                ),
                                Center(
                                  child: IconButton(
                                    onPressed: () {
                                      if (_player!.value.isPlaying) {
                                        _player!.pause();
                                      } else {
                                        _player!.play();
                                      }
                                      setState(() {});
                                    },
                                    icon: Icon(
                                      _player!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                                      color: Colors.white70,
                                      size: 64,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(child: CircularProgressIndicator(color: Colors.white)))
                      : Image.file(File(widget.path), fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _caption,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Add a caption…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: ChatTheme.purple,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _send,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChatMediaComposeBatchScreen extends StatefulWidget {
  const ChatMediaComposeBatchScreen({super.key, required this.items});

  final List<({String path, bool isVideo})> items;

  @override
  State<ChatMediaComposeBatchScreen> createState() => _ChatMediaComposeBatchScreenState();
}

class _ChatMediaComposeBatchScreenState extends State<ChatMediaComposeBatchScreen> {
  late final PageController _pageController;
  late final List<TextEditingController> _captions;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _captions = List.generate(widget.items.length, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final c in _captions) {
      c.dispose();
    }
    super.dispose();
  }

  void _send() {
    final out = <ChatMediaComposeResult>[];
    for (var i = 0; i < widget.items.length; i++) {
      final item = widget.items[i];
      final cap = _captions[i].text.trim();
      out.add(
        ChatMediaComposeResult(
          path: item.path,
          isVideo: item.isVideo,
          caption: cap.isEmpty ? null : cap,
        ),
      );
    }
    Navigator.pop(context, out);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final currentCaption = _captions[_page];
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    '${items.length} selected',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: items.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) {
                  final item = items[i];
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: item.isVideo
                          ? Container(
                              color: Colors.black87,
                              child: const Center(
                                child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 56),
                              ),
                            )
                          : Image.file(File(item.path), fit: BoxFit.contain),
                    ),
                  );
                },
              ),
            ),
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final item = items[i];
                  final selected = i == _page;
                  return GestureDetector(
                    onTap: () {
                      _pageController.animateToPage(i, duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
                      setState(() => _page = i);
                    },
                    child: Container(
                      width: 52,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: selected ? ChatTheme.purple : Colors.white24, width: selected ? 2 : 1),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: item.isVideo
                          ? Container(
                              color: Colors.white10,
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white70),
                            )
                          : Image.file(File(item.path), fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: ValueKey('caption_$_page'),
                      controller: currentCaption,
                      style: const TextStyle(color: Colors.white),
                      maxLines: 3,
                      minLines: 1,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Caption for ${_page + 1}/${items.length}…',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        filled: true,
                        fillColor: const Color(0xFF2A2A2E),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: ChatTheme.purple,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _send,
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Icon(Icons.send_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isChatAlbumOverlayCaption(currentCaption.text) && currentCaption.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'Long caption — this item will send separately',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ChatPendingUpload {
  ChatPendingUpload({
    required this.localId,
    required this.path,
    this.isVideo = false,
    this.isVoice = false,
    this.isDocument = false,
    this.caption,
    this.durationSeconds,
  });

  final String localId;
  final String path;
  final bool isVideo;
  final bool isVoice;
  final bool isDocument;
  final String? caption;
  final int? durationSeconds;
  double progress = 0;
  bool failed = false;
}

class PendingMediaBubble extends StatelessWidget {
  const PendingMediaBubble({super.key, required this.upload, this.onRetry});

  final ChatPendingUpload upload;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (upload.isVoice) return _PendingVoiceBubble(upload: upload, onRetry: onRetry);
    if (upload.isDocument) return _PendingDocumentBubble(upload: upload, onRetry: onRetry);
    final maxW = MediaQuery.sizeOf(context).width * 0.62;
    final cap = upload.caption?.trim() ?? '';
    final belowCaption = cap.isNotEmpty;

    final mediaCard = SizedBox(
      width: maxW,
      height: 180,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (upload.isVideo)
            Container(
              color: Colors.black87,
              child: const Center(child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 40)),
            )
          else
            Image.file(File(upload.path), fit: BoxFit.cover),
          Container(color: Colors.black45),
          Center(
            child: upload.failed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white, size: 36),
                      const SizedBox(height: 8),
                      if (onRetry != null)
                        TextButton(
                          onPressed: onRetry,
                          child: const Text('Retry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                        ),
                    ],
                  )
                : SizedBox(
                    width: 52,
                    height: 52,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: upload.progress <= 0 || upload.progress >= 1 ? null : upload.progress,
                          strokeWidth: 3,
                          color: Colors.white,
                          backgroundColor: Colors.white24,
                        ),
                        if (upload.progress > 0 && upload.progress < 1)
                          Text(
                            '${(upload.progress * 100).round()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );

    if (belowCaption) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: maxW),
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
                    child: mediaCard,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                  child: Text(upload.caption!, style: const TextStyle(color: Colors.white, fontSize: 14)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(upload.failed ? 'Failed' : 'Sending…', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: mediaCard,
        ),
        const SizedBox(height: 2),
        Text(upload.failed ? 'Failed' : 'Sending…', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
      ],
    );
  }
}

class _PendingVoiceBubble extends StatelessWidget {
  const _PendingVoiceBubble({required this.upload, this.onRetry});

  final ChatPendingUpload upload;
  final VoidCallback? onRetry;

  static const _bars = [0.35, 0.55, 0.4, 0.75, 0.5, 0.9, 0.45, 0.7, 0.55, 0.85, 0.4, 0.65, 0.5, 0.8, 0.45, 0.6];

  String _fmt(int? seconds) {
    final s = seconds ?? 0;
    final m = s ~/ 60;
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }

  @override
  Widget build(BuildContext context) {
    final progress = upload.progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: ChatTheme.purple,
            borderRadius: BorderRadius.circular(20).copyWith(bottomRight: const Radius.circular(6)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: upload.failed
                    ? GestureDetector(
                        onTap: onRetry,
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                          child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                        ),
                      )
                    : Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress <= 0 || progress >= 1 ? null : progress,
                            strokeWidth: 2.5,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                          Icon(
                            progress > 0 && progress < 1 ? Icons.upload_rounded : Icons.mic_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      height: 22,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var i = 0; i < _bars.length; i++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 1),
                                child: FractionallySizedBox(
                                  heightFactor: _bars[i],
                                  alignment: Alignment.bottomCenter,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: upload.failed
                                            ? 0.35
                                            : (i / _bars.length) <= progress
                                                ? 0.95
                                                : 0.35,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      upload.failed ? 'Tap to retry' : (progress > 0 ? '${(progress * 100).round()}%' : 'Sending…'),
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _fmt(upload.durationSeconds),
                style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PendingDocumentBubble extends StatelessWidget {
  const _PendingDocumentBubble({required this.upload, this.onRetry});

  final ChatPendingUpload upload;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.75;
    final name = upload.caption?.trim().isNotEmpty == true
        ? upload.caption!.trim()
        : upload.path.split(Platform.pathSeparator).last;
    return Container(
      constraints: BoxConstraints(maxWidth: maxW),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ChatTheme.purple,
        borderRadius: BorderRadius.circular(16).copyWith(bottomRight: const Radius.circular(5)),
        boxShadow: [
          BoxShadow(
            color: ChatTheme.purple.withValues(alpha: 0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.description_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 3),
                if (upload.failed)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      const Text('Failed', style: TextStyle(color: Colors.white70, fontSize: 11)),
                      if (onRetry != null) ...[
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: onRetry,
                          child: const Text('Retry', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, decoration: TextDecoration.underline)),
                        ),
                      ],
                    ],
                  )
                else
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          value: upload.progress <= 0 || upload.progress >= 1 ? null : upload.progress,
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        upload.progress > 0 && upload.progress < 1
                            ? 'Sending ${(upload.progress * 100).round()}%'
                            : 'Sending…',
                        style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
