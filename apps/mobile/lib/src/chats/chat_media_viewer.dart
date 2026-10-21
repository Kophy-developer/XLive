import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/media_url.dart';

void openChatImageViewer(
  BuildContext context,
  String imageUrl, {
  List<String>? gallery,
  int initialIndex = 0,
}) {
  final urls = <String>[
    for (final raw in (gallery == null || gallery.isEmpty ? <String>[imageUrl] : gallery))
      if (resolveMediaUrl(raw).isNotEmpty) resolveMediaUrl(raw),
  ];
  if (urls.isEmpty) return;
  final start = initialIndex.clamp(0, urls.length - 1);
  Navigator.push<void>(
    context,
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => urls.length == 1
          ? _ChatImageViewerScreen(imageUrl: urls.first)
          : _ChatImageGalleryViewerScreen(urls: urls, initialIndex: start),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

void openChatVideoViewer(BuildContext context, String videoUrl) {
  Navigator.push<void>(
    context,
    PageRouteBuilder<void>(
      opaque: true,
      barrierColor: Colors.black,
      pageBuilder: (_, _, _) => _ChatVideoViewerScreen(url: resolveMediaUrl(videoUrl, resourceType: 'video')),
      transitionsBuilder: (_, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}

class _ChatImageGalleryViewerScreen extends StatefulWidget {
  const _ChatImageGalleryViewerScreen({required this.urls, required this.initialIndex});

  final List<String> urls;
  final int initialIndex;

  @override
  State<_ChatImageGalleryViewerScreen> createState() => _ChatImageGalleryViewerScreenState();
}

class _ChatImageGalleryViewerScreenState extends State<_ChatImageGalleryViewerScreen> {
  late final PageController _pageController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _ChatImageViewerScreen(imageUrl: widget.urls[i], embedded: true),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (Navigator.canPop(context)) Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Text(
                      '${_index + 1}/${widget.urls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatImageViewerScreen extends StatefulWidget {
  const _ChatImageViewerScreen({required this.imageUrl, this.embedded = false});

  final String imageUrl;
  final bool embedded;

  @override
  State<_ChatImageViewerScreen> createState() => _ChatImageViewerScreenState();
}

class _ChatImageViewerScreenState extends State<_ChatImageViewerScreen> with SingleTickerProviderStateMixin {
  static const _minScale = 1.0;
  static const _maxScale = 4.0;
  static const _doubleTapScale = 2.5;

  final _transform = TransformationController();
  late final AnimationController _animController;
  Animation<Matrix4>? _animation;
  bool _loaded = false;
  bool _failed = false;
  bool _showChrome = true;
  double _dismissOffset = 0;
  Offset? _doubleTapLocal;

  bool _wasZoomed = false;

  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.05;

  @override
  void initState() {
    super.initState();
    if (!widget.embedded) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 220))
      ..addListener(() {
        final animation = _animation;
        if (animation != null) _transform.value = animation.value;
      });
    _transform.addListener(_onTransformChanged);
  }

  void _onTransformChanged() {
    if (!mounted) return;
    final zoomed = _isZoomed;
    if (zoomed == _wasZoomed && !(zoomed && _dismissOffset != 0)) return;
    _wasZoomed = zoomed;
    setState(() {
      if (zoomed) _dismissOffset = 0;
    });
  }

  @override
  void dispose() {
    _transform.removeListener(_onTransformChanged);
    _animController.dispose();
    _transform.dispose();
    if (!widget.embedded) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _animateTo(Matrix4 target) {
    _animation = Matrix4Tween(begin: _transform.value, end: target).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward(from: 0);
  }

  void _resetZoom() => _animateTo(Matrix4.identity());

  void _onDoubleTap() {
    if (_isZoomed) {
      _resetZoom();
      return;
    }
    final local = _doubleTapLocal;
    if (local == null) return;
    final scale = _doubleTapScale;
    final zoomed = Matrix4.identity()
      ..translateByDouble(local.dx, local.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-local.dx, -local.dy, 0, 1);
    _animateTo(zoomed);
  }

  void _close() {
    if (Navigator.canPop(context)) Navigator.pop(context);
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    if (_isZoomed) return;
    setState(() => _dismissOffset += details.delta.dy);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    if (_isZoomed) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_dismissOffset.abs() > 120 || velocity.abs() > 900) {
      _close();
      return;
    }
    setState(() => _dismissOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final dismissProgress = (_dismissOffset.abs() / 280).clamp(0.0, 1.0);
    final bgOpacity = (1.0 - dismissProgress * 0.65).clamp(0.35, 1.0);
    final body = Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          onTap: () {
            if (_failed || !_loaded || widget.embedded) return;
            setState(() => _showChrome = !_showChrome);
          },
          onDoubleTapDown: (details) => _doubleTapLocal = details.localPosition,
          onDoubleTap: _loaded && !_failed ? _onDoubleTap : null,
          onVerticalDragUpdate: !widget.embedded && _loaded && !_failed ? _onVerticalDragUpdate : null,
          onVerticalDragEnd: !widget.embedded && _loaded && !_failed ? _onVerticalDragEnd : null,
          behavior: HitTestBehavior.opaque,
          child: Transform.translate(
            offset: Offset(0, widget.embedded ? 0 : _dismissOffset),
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: _minScale,
              maxScale: _maxScale,
              panEnabled: _isZoomed,
              scaleEnabled: _loaded && !_failed,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.expand(
                child: Image.network(
                  widget.imageUrl,
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      if (!_loaded && !_failed) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted && !_loaded) setState(() => _loaded = true);
                        });
                      }
                      return child;
                    }
                    return const Center(
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (_, _, _) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted && !_failed) setState(() => _failed = true);
                    });
                    return const Center(
                      child: Icon(Icons.broken_image_rounded, color: Colors.white54, size: 64),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (!widget.embedded && _showChrome && dismissProgress < 0.2)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
    if (widget.embedded) return ColoredBox(color: Colors.black, child: body);
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: bgOpacity),
      body: body,
    );
  }
}

class ChatVideoBubble extends StatefulWidget {
  const ChatVideoBubble({super.key, required this.url, required this.mine});

  final String url;
  final bool mine;

  @override
  State<ChatVideoBubble> createState() => _ChatVideoBubbleState();
}

class _ChatVideoBubbleState extends State<ChatVideoBubble> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  String get _resolvedUrl => resolveMediaUrl(widget.url, resourceType: 'video');

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final resolved = _resolvedUrl;
    if (resolved.isEmpty) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    final controller = VideoPlayerController.networkUrl(Uri.parse(resolved));
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _openFullscreen() {
    if (_resolvedUrl.isEmpty) return;
    _controller?.pause();
    openChatVideoViewer(context, widget.url);
  }

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width * 0.62;
    if (_failed) {
      return GestureDetector(
        onTap: _openFullscreen,
        child: Container(
          width: maxW,
          height: 180,
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_fill_rounded, color: Colors.grey, size: 48),
              SizedBox(height: 8),
              Text('Tap to watch', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
        ),
      );
    }
    if (!_ready) {
      return Container(
        width: maxW,
        height: 180,
        decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(14)),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final c = _controller!;
    final aspect = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openFullscreen,
        borderRadius: BorderRadius.circular(14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: maxW,
            child: AspectRatio(
              aspectRatio: aspect,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  VideoPlayer(c),
                  Container(color: Colors.black26),
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 52),
                  ),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                      child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatVideoViewerScreen extends StatefulWidget {
  const _ChatVideoViewerScreen({required this.url});

  final String url;

  @override
  State<_ChatVideoViewerScreen> createState() => _ChatVideoViewerScreenState();
}

class _ChatVideoViewerScreenState extends State<_ChatVideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller.addListener(_onTick);
    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
      if (!mounted) return;
      setState(() {
        _ready = true;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = _controller;
    if (c == null || !_ready) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _toggleControls() => setState(() => _showControls = !_showControls);

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _controller?.removeListener(_onTick);
    _controller?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 64)),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (!_ready) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              const Center(child: CircularProgressIndicator(color: Colors.white)),
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final c = _controller!;
    final pos = c.value.position;
    final dur = c.value.duration;
    final aspect = c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        behavior: HitTestBehavior.opaque,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: VideoPlayer(c),
                ),
              ),
            ),
            if (_showControls) ...[
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Center(
                child: IconButton(
                  onPressed: _togglePlay,
                  iconSize: 72,
                  icon: Icon(
                    c.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [Color(0xCC000000), Color(0x00000000)],
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(_fmt(pos), style: const TextStyle(color: Colors.white, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: dur.inMilliseconds == 0
                                ? 0
                                : pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
                            max: dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds.toDouble(),
                            onChanged: (v) {
                              c.seekTo(Duration(milliseconds: v.round()));
                              setState(() {});
                            },
                            activeColor: Colors.white,
                            inactiveColor: Colors.white38,
                          ),
                        ),
                        Text(_fmt(dur), style: const TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
