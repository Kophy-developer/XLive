import 'dart:async';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

import '../../core/live/live_now_store.dart';
import '../../core/widgets/media_icon_scrim.dart';
import '../../core/media/feed_sound_store.dart';
import '../../core/media/media_url.dart';
import '../../core/media/media_url_cache.dart';
import '../../core/session/auth_session.dart';
import '../../core/share/share_links.dart';
import '../../core/utils/relative_time.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/feed/feed_repository.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/social/social_repository.dart';
import 'video_preview_comment_screens.dart';
import '../../core/network/api_friendly_messages.dart';

class InstagramFeedPost extends StatefulWidget {
  const InstagramFeedPost({
    super.key,
    required this.item,
    required this.onOpenFullscreen,
    this.onOpenProfile,
    this.onCommentCountChanged,
    this.shouldPlay = false,
    this.mediaKey,
  });

  final FeedItem item;
  final VoidCallback onOpenFullscreen;
  final VoidCallback? onOpenProfile;
  final ValueChanged<int>? onCommentCountChanged;
  final bool shouldPlay;
  final Key? mediaKey;

  @override
  State<InstagramFeedPost> createState() => _InstagramFeedPostState();
}

class _InstagramFeedPostState extends State<InstagramFeedPost> {
  final _social = SocialRepository();
  final _feed = FeedRepository();
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  bool _liking = false;

  FeedItem get item => widget.item;

  @override
  void initState() {
    super.initState();
    _liked = false;
    _likeCount = item.likeCount;
    _commentCount = item.commentCount;
    _refreshLike();
  }

  @override
  void didUpdateWidget(covariant InstagramFeedPost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _liked = false;
      _likeCount = item.likeCount;
      _commentCount = item.commentCount;
      _refreshLike();
      return;
    }
    if (oldWidget.item.commentCount != widget.item.commentCount &&
        widget.item.commentCount >= _commentCount) {
      _commentCount = widget.item.commentCount;
    }
    if (oldWidget.item.likeCount != widget.item.likeCount) {
      _likeCount = widget.item.likeCount;
    }
  }

  void _setCommentCount(int count) {
    if (_commentCount == count) return;
    setState(() => _commentCount = count);
    widget.onCommentCountChanged?.call(count);
  }

  Future<void> _refreshLike() async {
    if (!AuthSession.instance.isSignedIn) return;
    try {
      final summary = await _social.getLikeSummary(
        targetType: item.targetType,
        targetId: item.id,
      );
      if (!mounted) return;
      setState(() {
        _liked = summary.likedByMe;
        _likeCount = summary.count;
      });
    } catch (_) {}
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to like posts.')));
      return;
    }
    final wasLiked = _liked;
    setState(() {
      _liking = true;
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) {
        await _social.unlike(targetType: item.targetType, targetId: item.id);
      } else {
        await _social.like(targetType: item.targetType, targetId: item.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        targetType: item.targetType,
        targetId: item.id,
        onActivity: () async {
          try {
            final count = await _social.getCommentCount(targetType: item.targetType, targetId: item.id);
            if (mounted) _setCommentCount(count);
          } catch (_) {}
        },
      ),
    ).then((_) async {
      try {
        final count = await _social.getCommentCount(targetType: item.targetType, targetId: item.id);
        if (mounted) _setCommentCount(count);
      } catch (_) {}
    });
  }

  Future<void> _share() async {
    final title = item.title.trim().isEmpty ? 'this post' : item.title;
    try {
      if (AuthSession.instance.isSignedIn) {
        await _feed.recordInteraction(action: 'share', targetType: item.targetType, targetId: item.id);
      }
      await Share.share('Check out "$title" on Xlive\n${mediaShareUrl(item.id)}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  String get _creatorName {
    final me = AuthSession.instance.user;
    if (me != null && item.creatorId != null && item.creatorId == me.id) {
      final self = me.displayName?.trim();
      if (self != null && self.isNotEmpty) return self;
      final handle = me.username?.trim();
      if (handle != null && handle.isNotEmpty) return handle;
    }
    return item.displayName;
  }

  String? get _creatorAvatar {
    final url = item.creatorAvatarUrl?.trim();
    if (url != null && url.isNotEmpty) return url;
    final me = AuthSession.instance.user;
    if (me != null && item.creatorId != null && item.creatorId == me.id) {
      final self = me.avatarUrl?.trim();
      if (self != null && self.isNotEmpty) return self;
    }
    return null;
  }

  void _openAlbumMedia(int page) {
    final slides = item.albumSlides;
    if (slides.isEmpty) return;
    widget.onOpenFullscreen();
  }

  void _handleStageTap() {
    widget.onOpenFullscreen();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (item.isAlbum)
          _FeedAlbumCarousel(
            key: widget.mediaKey,
            slides: item.albumSlides,
            creatorName: _creatorName,
            creatorAvatarUrl: _creatorAvatar,
            onOpenProfile: widget.onOpenProfile,
            onDoubleTapLike: _toggleLike,
            onTapSlide: (page) {
              _openAlbumMedia(page);
            },
          )
        else
          _FeedMediaStage(
            key: widget.mediaKey,
            item: item,
            shouldPlay: widget.shouldPlay,
            onTap: _handleStageTap,
            onDoubleTapLike: _toggleLike,
            creatorName: _creatorName,
            creatorAvatarUrl: _creatorAvatar,
            onOpenProfile: widget.onOpenProfile,
            onMore: widget.onOpenFullscreen,
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(
            children: [
              _FeedEngagementAction(
                icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                count: _likeCount,
                iconColor: _liked ? const Color(0xFFFF3040) : const Color(0xFF0A0A0A),
                filled: _liked,
                onTap: _toggleLike,
              ),
              const SizedBox(width: 8),
              _FeedEngagementAction(
                icon: Icons.mode_comment_outlined,
                count: _commentCount,
                onTap: _openComments,
              ),
              const SizedBox(width: 8),
              _FeedEngagementAction(
                icon: Icons.ios_share_rounded,
                onTap: _share,
              ),
              const Spacer(),
              if (item.type == FeedContentType.stream)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE11D48),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                  ),
                ),
            ],
          ),
        ),
        if (item.title.trim().isNotEmpty && item.title != 'Untitled')
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 14, color: Color(0xFF0A0A0A), height: 1.35),
                children: [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: widget.onOpenProfile,
                      child: Text(
                        '$_creatorName ',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF0A0A0A), height: 1.35),
                      ),
                    ),
                  ),
                  TextSpan(text: item.title),
                  if (formatRelativeTime(item.createdAt).isNotEmpty)
                    TextSpan(
                      text: ' · ${formatRelativeTime(item.createdAt)}',
                      style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93), fontWeight: FontWeight.w500, height: 1.35),
                    ),
                ],
              ),
            ),
          ),
        if (_commentCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: _openComments,
                child: Text(
                  _commentCount == 1 ? 'View 1 comment' : 'View all $_commentCount comments',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ),
            ),
          )
        else
          const SizedBox(height: 16),
        const SizedBox(height: 18),
      ],
    );
  }
}

class _FeedEngagementAction extends StatelessWidget {
  const _FeedEngagementAction({
    required this.icon,
    required this.onTap,
    this.count,
    this.iconColor = const Color(0xFF0A0A0A),
    this.filled = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int? count;
  final Color iconColor;
  final bool filled;

  String _compact(int value) {
    if (value < 1000) return '$value';
    if (value < 1000000) {
      final k = value / 1000;
      final text = k >= 10 || k == k.roundToDouble() ? '${k.round()}' : k.toStringAsFixed(1);
      return '${text}K';
    }
    final m = value / 1000000;
    final text = m >= 10 || m == m.roundToDouble() ? '${m.round()}' : m.toStringAsFixed(1);
    return '${text}M';
  }

  @override
  Widget build(BuildContext context) {
    final showCount = count != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            color: filled ? const Color(0xFFFF3040).withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(showCount ? 12 : 11, 8, showCount ? 14 : 11, 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: iconColor),
                if (showCount) ...[
                  const SizedBox(width: 7),
                  Text(
                    _compact(count!),
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: filled ? const Color(0xFFFF3040) : const Color(0xFF0A0A0A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedMediaStage extends StatefulWidget {
  const _FeedMediaStage({
    super.key,
    required this.item,
    required this.shouldPlay,
    required this.onTap,
    required this.onDoubleTapLike,
    required this.creatorName,
    this.creatorAvatarUrl,
    this.onOpenProfile,
    this.onMore,
  });

  final FeedItem item;
  final bool shouldPlay;
  final VoidCallback? onTap;
  final VoidCallback onDoubleTapLike;
  final String creatorName;
  final String? creatorAvatarUrl;
  final VoidCallback? onOpenProfile;
  final VoidCallback? onMore;

  @override
  State<_FeedMediaStage> createState() => _FeedMediaStageState();
}

class _FeedMediaStageState extends State<_FeedMediaStage> {
  VideoPlayerController? _controller;
  bool _ready = false;
  String? _playbackUrl;
  bool _showHeartBurst = false;
  int _prepareToken = 0;
  bool _muted = FeedSoundStore.instance.muted;

  FeedItem get item => widget.item;
  bool get _isImage => item.isImage;
  bool get _canPlayVideo => !_isImage && item.type != FeedContentType.stream && !item.isLocked;

  @override
  void initState() {
    super.initState();
    FeedSoundStore.instance.addListener(_onSoundChanged);
    if (_canPlayVideo && widget.shouldPlay) {
      _prepareInlineVideo();
    }
  }

  void _onSoundChanged() {
    final muted = FeedSoundStore.instance.muted;
    if (_muted == muted) return;
    _muted = muted;
    final c = _controller;
    if (c != null) {
      c.setVolume(FeedSoundStore.instance.volume);
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant _FeedMediaStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.item.id != widget.item.id) {
      _tearDownPlayer();
      if (_canPlayVideo && widget.shouldPlay) {
        _prepareInlineVideo();
      }
      return;
    }
    if (!_canPlayVideo) return;
    if (oldWidget.shouldPlay != widget.shouldPlay) {
      if (widget.shouldPlay) {
        _prepareInlineVideo();
      } else {
        _tearDownPlayer();
      }
    }
  }

  Future<void> _prepareInlineVideo() async {
    final token = ++_prepareToken;
    try {
      final media = await MediaUrlCache.fetch(item.targetType, item.id).timeout(const Duration(seconds: 15));
      final raw = media.url;
      if (raw == null || raw.isEmpty || !mounted || token != _prepareToken || !widget.shouldPlay) return;
      final url = resolveMediaUrl(raw, resourceType: 'video');
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted || token != _prepareToken || !widget.shouldPlay) {
        await controller.dispose();
        return;
      }
      await controller.setLooping(true);
      await controller.setVolume(FeedSoundStore.instance.volume);
      await controller.play();
      await _controller?.dispose();
      if (!mounted || token != _prepareToken || !widget.shouldPlay) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      setState(() {
        _playbackUrl = url;
        _ready = true;
        _muted = FeedSoundStore.instance.muted;
      });
    } catch (_) {}
  }

  void _tearDownPlayer() {
    _prepareToken++;
    final controller = _controller;
    _controller = null;
    controller?.dispose();
    if (_ready || _playbackUrl != null) {
      setState(() {
        _ready = false;
        _playbackUrl = null;
      });
    }
  }

  @override
  void dispose() {
    FeedSoundStore.instance.removeListener(_onSoundChanged);
    _prepareToken++;
    _controller?.dispose();
    super.dispose();
  }

  void _toggleMute() {
    FeedSoundStore.instance.toggle();
  }

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeartBurst = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartBurst = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final thumb = resolveMediaUrl(item.thumbnailUrl, resourceType: _isImage ? 'image' : null);
    final image = thumb.isNotEmpty
        ? Image.network(
            thumb,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40),
            ),
          )
        : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onDoubleTap: _handleDoubleTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRect(
          child: ColoredBox(
            color: const Color(0xFF111111),
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                if (image != null)
                  image
                else if (!_ready)
                  Center(
                    child: Icon(
                      _isImage ? Icons.photo_rounded : Icons.play_circle_outline_rounded,
                      color: Colors.white38,
                      size: 48,
                    ),
                  ),
                if (_ready && _controller != null && _playbackUrl != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  ),
                if (_canPlayVideo && !_ready)
                  const Center(
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 64),
                  ),
                Positioned(
                  top: 10,
                  left: 12,
                  right: 4,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onOpenProfile,
                        child: UserAvatar(
                          radius: 16,
                          imageUrl: widget.creatorAvatarUrl,
                          isLive: item.creatorIsLive || LiveNowStore.instance.isLive(item.creatorId),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onOpenProfile,
                          child: Text.rich(
                            TextSpan(
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                              ),
                              children: [
                                TextSpan(text: widget.creatorName),
                                if (formatRelativeTime(item.createdAt).isNotEmpty)
                                  TextSpan(
                                    text: ' · ${formatRelativeTime(item.createdAt)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.78),
                                      shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
                                    ),
                                  ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      if (widget.onMore != null)
                        MediaIconScrim(
                          onTap: widget.onMore,
                          child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 22),
                        ),
                    ],
                  ),
                ),
                if (_canPlayVideo)
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: MediaIconScrim(
                      onTap: _toggleMute,
                      size: 36,
                      child: Icon(
                        _muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                if (_showHeartBurst)
                  const Center(
                    child: Icon(Icons.favorite_rounded, color: Color(0xFFFF3040), size: 96),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeedAlbumCarousel extends StatefulWidget {
  const _FeedAlbumCarousel({
    super.key,
    required this.slides,
    required this.creatorName,
    this.creatorAvatarUrl,
    this.onOpenProfile,
    required this.onDoubleTapLike,
    this.onTapSlide,
  });

  final List<FeedItem> slides;
  final String creatorName;
  final String? creatorAvatarUrl;
  final VoidCallback? onOpenProfile;
  final VoidCallback onDoubleTapLike;
  final ValueChanged<int>? onTapSlide;

  @override
  State<_FeedAlbumCarousel> createState() => _FeedAlbumCarouselState();
}

class _FeedAlbumCarouselState extends State<_FeedAlbumCarousel> {
  int _page = 0;
  bool _showHeartBurst = false;

  void _handleDoubleTap() {
    widget.onDoubleTapLike();
    setState(() => _showHeartBurst = true);
    Future<void>.delayed(const Duration(milliseconds: 700), () {
      if (mounted) setState(() => _showHeartBurst = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final slides = widget.slides;
    final lead = slides.isNotEmpty ? slides.first : null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: _handleDoubleTap,
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ClipRect(
          child: ColoredBox(
            color: const Color(0xFF111111),
            child: Stack(
              fit: StackFit.expand,
              children: [
                PageView.builder(
                  itemCount: slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final slide = slides[i];
                    final thumb = resolveMediaUrl(slide.thumbnailUrl, resourceType: 'image');
                    Widget imageWidget;
                    if (thumb.isEmpty) {
                      imageWidget = const Center(child: Icon(Icons.photo_rounded, color: Colors.white38, size: 48));
                    } else {
                      imageWidget = Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const Center(
                          child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 40),
                        ),
                      );
                    }
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => widget.onTapSlide?.call(i),
                      child: imageWidget,
                    );
                  },
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  right: 4,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: widget.onOpenProfile,
                        child: UserAvatar(
                          radius: 16,
                          imageUrl: widget.creatorAvatarUrl,
                          isLive: (lead?.creatorIsLive ?? false) || LiveNowStore.instance.isLive(lead?.creatorId),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: widget.onOpenProfile,
                          child: Text(
                            widget.creatorName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '${_page + 1}/${slides.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ),
                if (slides.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < slides.length; i++)
                          Container(
                            width: i == _page ? 7 : 5,
                            height: i == _page ? 7 : 5,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == _page ? Colors.white : Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (_showHeartBurst)
                  const Center(
                    child: Icon(Icons.favorite_rounded, color: Color(0xFFFF3040), size: 96),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

