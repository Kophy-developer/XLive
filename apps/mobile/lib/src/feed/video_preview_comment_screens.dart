import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

import '../../core/network/api_friendly_messages.dart';
import '../../core/network/api_json.dart';
import '../../core/media/content_unlock_store.dart';
import '../../core/subscriptions/subscription_store.dart';
import '../../core/media/feed_sound_store.dart';
import '../../core/media/giphy.dart';
import '../../core/media/media_url.dart';
import '../../core/media/media_url_cache.dart';
import '../../core/media/saved_media_store.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/auth_session.dart';
import '../../core/share/share_links.dart';
import '../../core/social/comment_emoji.dart';
import '../../core/utils/relative_time.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/social/models/social_models.dart';
import '../../features/feed/feed_album.dart';
import '../../features/feed/feed_repository.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/insights/insights_repository.dart';
import '../../features/social/social_repository.dart';
import '../../features/videos/videos_repository.dart';
import '../../features/clips/clips_repository.dart';
import '../integration/insights_screens.dart';
import '../profile/user_profile_preview_screens.dart';

const _black = Color(0xFF000000);
const _sheetBg = Color(0xFF1C1C1E);
const _inputBg = Color(0xFF2C2C2C);
const _muted = Color(0xFF9E9E9E);
const _sendPurple = Color(0xFF8E24ED);

class VideoClipPreviewArgs {
  const VideoClipPreviewArgs({
    this.targetType,
    this.targetId,
    this.title,
    this.thumbnailUrl,
    this.creatorId,
    this.creatorName,
    this.filledHeart = false,
    this.likeCount = 0,
    this.viewCount = 0,
    this.commentCount = 0,
    this.isImage = false,
    this.mediaUrl,
    this.createdAt,
    this.unlockPrice = 0,
    this.locked = false,
    this.saveTargetIds = const [],
    this.isAlbum = false,
  });

  factory VideoClipPreviewArgs.fromFeedItem(FeedItem item) {
    return VideoClipPreviewArgs(
      targetType: item.targetType,
      targetId: item.id,
      title: item.title,
      thumbnailUrl: item.thumbnailUrl,
      creatorId: item.creatorId,
      creatorName: item.displayName,
      likeCount: item.likeCount,
      viewCount: item.viewCount,
      commentCount: item.commentCount,
      isImage: item.isImage,
      mediaUrl: item.isLocked
          ? null
          : MediaUrlCache.resolved(
              item.targetType,
              item.id,
              resourceType: item.isImage ? 'image' : null,
            ),
      createdAt: item.createdAt,
      unlockPrice: item.unlockPrice,
      locked: item.isLocked,
      saveTargetIds: feedSaveTargetIds(item),
      isAlbum: item.isAlbum,
    );
  }

  final String? targetType;
  final String? targetId;
  final String? title;
  final String? thumbnailUrl;
  final String? creatorId;
  final String? creatorName;
  final bool filledHeart;
  final int likeCount;
  final int viewCount;
  final int commentCount;
  final bool isImage;
  final String? mediaUrl;
  final DateTime? createdAt;
  final int unlockPrice;
  final bool locked;
  final List<String> saveTargetIds;
  final bool isAlbum;

  bool get hasTarget => targetId != null && targetId!.isNotEmpty;

  List<String> get resolvedSaveTargetIds {
    if (saveTargetIds.isNotEmpty) return saveTargetIds;
    final id = targetId?.trim();
    if (id == null || id.isEmpty) return const [];
    return [id];
  }

  VideoClipPreviewArgs copyWith({
    String? targetType,
    String? targetId,
    String? title,
    String? thumbnailUrl,
    String? creatorId,
    String? creatorName,
    bool? filledHeart,
    int? likeCount,
    int? viewCount,
    int? commentCount,
    bool? isImage,
    String? mediaUrl,
    DateTime? createdAt,
    int? unlockPrice,
    bool? locked,
    List<String>? saveTargetIds,
    bool? isAlbum,
    bool clearMediaUrl = false,
  }) {
    return VideoClipPreviewArgs(
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      creatorId: creatorId ?? this.creatorId,
      creatorName: creatorName ?? this.creatorName,
      filledHeart: filledHeart ?? this.filledHeart,
      likeCount: likeCount ?? this.likeCount,
      viewCount: viewCount ?? this.viewCount,
      commentCount: commentCount ?? this.commentCount,
      isImage: isImage ?? this.isImage,
      mediaUrl: clearMediaUrl ? null : (mediaUrl ?? this.mediaUrl),
      createdAt: createdAt ?? this.createdAt,
      unlockPrice: unlockPrice ?? this.unlockPrice,
      locked: locked ?? this.locked,
      saveTargetIds: saveTargetIds ?? this.saveTargetIds,
      isAlbum: isAlbum ?? this.isAlbum,
    );
  }
}

class FeedReelViewerArgs {
  const FeedReelViewerArgs({
    required this.items,
    this.initialIndex = 0,
    this.initialPage = 1,
    this.loadMore,
  });

  final List<VideoClipPreviewArgs> items;
  final int initialIndex;
  final int initialPage;
  final Future<List<VideoClipPreviewArgs>> Function(int page)? loadMore;
}

class VideoClipPreviewScreen extends StatefulWidget {
  const VideoClipPreviewScreen({
    super.key,
    this.args = const VideoClipPreviewArgs(),
    this.isActive = true,
    this.embeddedInReel = false,
    this.onRemoved,
    this.onUnlocked,
  });

  final VideoClipPreviewArgs args;
  final bool isActive;
  final bool embeddedInReel;
  final ValueChanged<String>? onRemoved;
  final ValueChanged<VideoClipPreviewArgs>? onUnlocked;

  @override
  State<VideoClipPreviewScreen> createState() => _VideoClipPreviewScreenState();
}

class _VideoClipPreviewScreenState extends State<VideoClipPreviewScreen> with WidgetsBindingObserver {
  static final Set<String> _countedViews = <String>{};
  final _social = SocialRepository();
  final _feed = FeedRepository();
  final _insights = InsightsRepository();
  final _videosRepo = VideosRepository();
  final _clipsRepo = ClipsRepository();
  late bool _liked;
  late int _likeCount;
  late int _commentCount;
  int _shareCount = 0;
  int? _ownerViews;
  int _unlockPrice = 0;
  DateTime? _createdAt;
  bool _holdingSpeed = false;
  String? _title;
  String? _thumbnailUrl;
  String? _mediaUrl;
  String? _creatorName;
  String? _creatorId;
  bool _followingCreator = false;
  bool _loadingDetail = false;
  bool _locked = false;
  bool _savingBookmark = false;
  bool _unlocking = false;
  int _soldCount = 0;
  bool _isArchived = false;
  String? _loadError;
  String? _mediaError;
  int _mediaLoadToken = 0;
  VideoPlayerController? _videoController;
  bool _videoReady = false;
  bool _isImageMedia = false;
  bool _loadingMedia = false;
  bool _soundMuted = FeedSoundStore.instance.muted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FeedSoundStore.instance.addListener(_onFeedSoundChanged);
    _liked = widget.args.filledHeart;
    _likeCount = widget.args.likeCount;
    _commentCount = widget.args.commentCount;
    _title = widget.args.title;
    _thumbnailUrl = widget.args.thumbnailUrl;
    _creatorName = widget.args.creatorName;
    _creatorId = widget.args.creatorId;
    _isImageMedia = widget.args.isImage;
    final type = widget.args.targetType ?? 'video';
    final id = widget.args.targetId ?? '';
    final isSubscriber = SubscriptionStore.instance.isSubscribedTo(_creatorId);
    _locked = widget.args.locked && !isSubscriber && !ContentUnlockStore.isUnlocked(type, id);
    _unlockPrice = widget.args.unlockPrice;
    _createdAt = widget.args.createdAt;
    _soundMuted = FeedSoundStore.instance.muted;
    unawaited(() async {
      await ContentUnlockStore.ensureLoaded();
      if (!mounted) return;
      final unlocked = ContentUnlockStore.isUnlocked(type, id);
      final nextLocked = widget.args.locked && !isSubscriber && !unlocked;
      if (nextLocked != _locked) {
        setState(() => _locked = nextLocked);
        if (!_locked && widget.isActive) unawaited(_loadMedia());
      }
    }());
    if (widget.args.hasTarget) {
      _loadDetail();
      if (widget.isActive && !_locked) _loadMedia();
    }
  }

  void _onFeedSoundChanged() {
    final muted = FeedSoundStore.instance.muted;
    if (_soundMuted == muted && mounted) {
      setState(() {});
      return;
    }
    _soundMuted = muted;
    final c = _videoController;
    if (c != null && widget.isActive) {
      c.setVolume(FeedSoundStore.instance.volume);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _pausePlayback(mute: true);
      return;
    }
    if (state == AppLifecycleState.resumed && widget.isActive) {
      _resumePlayback();
    }
  }

  @override
  void didUpdateWidget(covariant VideoClipPreviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final unlockedByArgs = oldWidget.args.locked && !widget.args.locked;
    if (unlockedByArgs) {
      _locked = false;
      if (widget.isActive && !_loadingMedia && _videoController == null) {
        _loadMedia();
      }
    }
    if (oldWidget.isActive == widget.isActive) return;
    if (widget.isActive) {
      if (_videoController != null) {
        _resumePlayback();
      } else if (!_loadingMedia && widget.args.hasTarget && !_locked) {
        _loadMedia();
      }
    } else {
      _pausePlayback(mute: true);
    }
  }

  @override
  void dispose() {
    FeedSoundStore.instance.removeListener(_onFeedSoundChanged);
    WidgetsBinding.instance.removeObserver(this);
    _mediaLoadToken++;
    final controller = _videoController;
    _videoController = null;
    controller?.removeListener(_onVideoTick);
    controller?.dispose();
    super.dispose();
  }

  void _onVideoTick() {
    if (!mounted || _isImageMedia || !_videoReady) return;
    setState(() {});
  }

  String _fmtDuration(Duration d) {
    final total = d.inSeconds;
    final m = total ~/ 60;
    final s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _pausePlayback({required bool mute}) async {
    final c = _videoController;
    if (c == null) return;
    try {
      if (_holdingSpeed) {
        _holdingSpeed = false;
        await c.setPlaybackSpeed(1);
      }
      if (mute) await c.setVolume(0);
      if (c.value.isPlaying) await c.pause();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _resumePlayback() async {
    final c = _videoController;
    if (c == null || !widget.isActive) return;
    try {
      await c.setVolume(FeedSoundStore.instance.volume);
      if (!c.value.isPlaying) await c.play();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  void _toggleSound() {
    FeedSoundStore.instance.toggle();
  }

  void _finishRemoval() {
    final id = widget.args.targetId;
    if (widget.embeddedInReel && id != null && id.isNotEmpty) {
      widget.onRemoved?.call(id);
      return;
    }
    Navigator.pop(context, true);
  }

  bool _urlLooksLikeImage(String url) {
    final u = url.toLowerCase();
    return u.contains('.png') ||
        u.contains('.jpg') ||
        u.contains('.jpeg') ||
        u.contains('.webp') ||
        u.contains('.gif') ||
        u.contains('.heic');
  }

  static const _videoUnavailableMessage = 'This video is unavailable';

  Future<bool> _urlIsMissing(String url) async {
    try {
      final res = await http.head(Uri.parse(url)).timeout(const Duration(seconds: 8));
      return res.statusCode == 404 || res.statusCode == 410;
    } catch (_) {
      return false;
    }
  }

  Future<void> _initVideo(String url) async {
    final token = _mediaLoadToken;
    final old = _videoController;
    old?.removeListener(_onVideoTick);
    await old?.dispose();
    _videoController = null;
    if (mounted) {
      setState(() {
        _videoReady = false;
        _mediaError = null;
        _loadingMedia = true;
      });
    }
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolveMediaUrl(url, resourceType: 'video')),
    );
    _videoController = controller;
    try {
      await controller.initialize().timeout(const Duration(seconds: 25));
      if (!mounted || token != _mediaLoadToken) {
        await controller.dispose();
        if (_videoController == controller) _videoController = null;
        return;
      }
      await controller.setLooping(true);
      if (widget.isActive) {
        await controller.setVolume(FeedSoundStore.instance.volume);
        await controller.play();
      } else {
        await controller.setVolume(0);
        await controller.pause();
      }
      if (!mounted || token != _mediaLoadToken) {
        await controller.dispose();
        if (_videoController == controller) _videoController = null;
        return;
      }
      if (!widget.isActive) {
        await controller.setVolume(0);
        await controller.pause();
      } else {
        await controller.setVolume(FeedSoundStore.instance.volume);
      }
      controller.addListener(_onVideoTick);
      setState(() {
        _videoReady = true;
        _loadingMedia = false;
        _mediaError = null;
      });
    } on TimeoutException {
      await controller.dispose();
      if (_videoController == controller) _videoController = null;
      if (!mounted || token != _mediaLoadToken) return;
      setState(() {
        _videoReady = false;
        _loadingMedia = false;
        _mediaError = connectionErrorMessage;
      });
    } catch (_) {
      await controller.dispose();
      if (_videoController == controller) _videoController = null;
      if (!mounted || token != _mediaLoadToken) return;
      final missing = await _urlIsMissing(url);
      if (!mounted || token != _mediaLoadToken) return;
      setState(() {
        _videoReady = false;
        _loadingMedia = false;
        _mediaError = missing ? _videoUnavailableMessage : 'Could not play this video. Please retry.';
      });
    }
  }

  Future<void> _loadMedia({bool force = false}) async {
    final id = widget.args.targetId;
    if (id == null || id.isEmpty) return;
    final type = widget.args.targetType ?? 'video';
    final token = ++_mediaLoadToken;
    if (mounted) {
      setState(() {
        _loadingMedia = true;
        _mediaError = null;
      });
    }

    Future<void> playResolved(String resolved, {required bool treatAsImage}) async {
      if (!mounted || token != _mediaLoadToken) return;
      setState(() {
        _mediaUrl = resolved.isEmpty ? null : resolved;
        _isImageMedia = treatAsImage;
        if (treatAsImage || resolved.isEmpty) {
          _loadingMedia = false;
        }
      });
      if (!treatAsImage && resolved.isNotEmpty) {
        if (!widget.isActive) {
          if (mounted && token == _mediaLoadToken) {
            setState(() => _loadingMedia = false);
          }
          return;
        }
        await _initVideo(resolved);
      }
    }

    final treatAsImageArg = widget.args.isImage;
    final imageType = treatAsImageArg ? 'image' : 'video';

    if (treatAsImageArg) {
      final thumb = resolveMediaUrl(widget.args.thumbnailUrl, resourceType: 'image');
      if (thumb.isNotEmpty) {
        await playResolved(thumb, treatAsImage: true);
        return;
      }
    }

    if (!force) {
      final passed = widget.args.mediaUrl?.trim();
      if (passed != null && passed.isNotEmpty) {
        final treatAsImage = treatAsImageArg || _urlLooksLikeImage(passed);
        final resolved = resolveMediaUrl(passed, resourceType: treatAsImage ? 'image' : imageType);
        await playResolved(resolved, treatAsImage: treatAsImage);
        return;
      }

      final cached = MediaUrlCache.resolved(type, id, resourceType: imageType);
      if (cached != null && cached.isNotEmpty) {
        final treatAsImage = treatAsImageArg || _urlLooksLikeImage(cached);
        await playResolved(
          resolveMediaUrl(cached, resourceType: treatAsImage ? 'image' : 'video'),
          treatAsImage: treatAsImage,
        );
        return;
      }
    }

    try {
      final media = await MediaUrlCache.fetch(type, id, force: force).timeout(const Duration(seconds: 15));
      if (!mounted || token != _mediaLoadToken) return;
      final raw = media.url;
      final treatAsImage = treatAsImageArg || (raw != null && _urlLooksLikeImage(raw));
      final resolved = resolveMediaUrl(raw, resourceType: treatAsImage ? 'image' : 'video');
      await playResolved(resolved, treatAsImage: treatAsImage);
    } catch (e) {
      if (!mounted || token != _mediaLoadToken) return;
      if (e is ApiException && (e.statusCode == 404 || e.statusCode == 410)) {
        if (mounted && token == _mediaLoadToken) {
          setState(() {
            _loadingMedia = false;
            _mediaError = _videoUnavailableMessage;
          });
        }
        return;
      }
      final message = friendlyApiMessage(e, fallback: 'Could not load video. Please retry.');
      final lower = message.toLowerCase();
      final isSubscriber = SubscriptionStore.instance.isSubscribedTo(_creatorId);
      final accessDenied = (lower.contains('not authorized') ||
          lower.contains('unlock') ||
          lower.contains('purchase') ||
          lower.contains('access') ||
          lower.contains('403') ||
          (e is ApiException && e.statusCode == 403)) && !isSubscriber;
      if (accessDenied) {
        ContentUnlockStore.clear(type, id);
        setState(() {
          _locked = true;
          _loadingMedia = false;
          _mediaError = null;
        });
        return;
      }
      final thumb = resolveMediaUrl(widget.args.thumbnailUrl, resourceType: treatAsImageArg ? 'image' : null);
      if (treatAsImageArg && thumb.isNotEmpty) {
        await playResolved(thumb, treatAsImage: true);
        return;
      }
      setState(() {
        _loadingMedia = false;
        _mediaError = message;
      });
    }
  }

  Future<void> _retryMedia() async {
    await _loadMedia(force: true);
  }

  Future<void> _unlockContent() async {
    final id = widget.args.targetId;
    if (id == null || id.isEmpty || _unlocking) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to unlock content.')));
      return;
    }
    final balance = AuthSession.instance.walletBalance ?? 0;
    if (_unlockPrice > 0 && balance < _unlockPrice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Not enough coins. You need $_unlockPrice coins to unlock.'),
          action: SnackBarAction(label: 'Top up', onPressed: () => Navigator.pushNamed(context, '/wallet/xlive')),
        ),
      );
      return;
    }
    setState(() => _unlocking = true);
    final type = widget.args.targetType ?? 'video';
    var chargedOrOwned = false;
    try {
      var alreadyOwned = false;
      try {
        if (_isClip) {
          await _clipsRepo.purchaseCollectible(id);
        } else {
          await _videosRepo.unlockVideo(id);
        }
        chargedOrOwned = true;
      } on ApiException catch (e) {
        final msg = e.message.toLowerCase();
        final owned = e.statusCode == 409 ||
            msg.contains('already unlocked') ||
            msg.contains('already purchased') ||
            msg.contains('already own');
        if (!owned) rethrow;
        alreadyOwned = true;
        chargedOrOwned = true;
      }
      ContentUnlockStore.mark(type, id);
      await AuthSession.instance.refreshWallet();
      MediaUrlCache.invalidate(type, id);

      MediaDetail? detail;
      for (var attempt = 0; attempt < 4; attempt++) {
        if (attempt > 0) {
          await Future<void>.delayed(Duration(milliseconds: 250 * attempt));
        }
        detail = await _social.getMediaDetail(targetType: type, targetId: id);
        if (!detail.isLocked) break;
      }

      var playUrl = detail?.streamUrl?.trim();
      if (playUrl == null || playUrl.isEmpty) {
        try {
          final media = await MediaUrlCache.fetch(type, id, force: true).timeout(const Duration(seconds: 15));
          playUrl = media.url?.trim();
        } catch (_) {}
      }

      final treatAsImage = widget.args.isImage || (playUrl != null && _urlLooksLikeImage(playUrl));
      final resolved = playUrl == null || playUrl.isEmpty
          ? ''
          : resolveMediaUrl(playUrl, resourceType: treatAsImage ? 'image' : 'video');

      if (!mounted) return;
      setState(() {
        _locked = false;
        if (detail != null) {
          _unlockPrice = detail.unlockPrice > 0 ? detail.unlockPrice : _unlockPrice;
          _title = detail.title.isNotEmpty ? detail.title : _title;
          _thumbnailUrl = detail.thumbnailUrl ?? _thumbnailUrl;
          _creatorName = detail.creatorName ?? _creatorName;
          _creatorId = detail.creatorId ?? _creatorId;
        }
        if (resolved.isNotEmpty) {
          _mediaUrl = resolved;
          _isImageMedia = treatAsImage;
          _mediaError = null;
        } else {
          _mediaError = 'Unlocked, but the video could not be loaded. Please retry.';
        }
      });
      widget.onUnlocked?.call(
        widget.args.copyWith(
          locked: false,
          unlockPrice: _unlockPrice,
          mediaUrl: resolved.isEmpty ? null : resolved,
          clearMediaUrl: resolved.isEmpty,
          isImage: treatAsImage,
        ),
      );
      if (resolved.isNotEmpty) {
        if (treatAsImage) {
          setState(() {
            _videoReady = false;
            _loadingMedia = false;
          });
        } else if (widget.isActive) {
          await _initVideo(resolved);
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            alreadyOwned
                ? 'Already unlocked'
                : (_isClip ? 'Clip unlocked' : 'Content unlocked'),
          ),
        ),
      );
    } catch (e) {
      if (!chargedOrOwned) {
        ContentUnlockStore.clear(type, id);
        if (mounted) setState(() => _locked = true);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _unlocking = false);
    }
  }

  Future<void> _setHoldSpeed(bool holding) async {
    final c = _videoController;
    if (c == null || !_videoReady || _locked || _isImageMedia) return;
    if (_holdingSpeed == holding) return;
    _holdingSpeed = holding;
    if (holding) {
      if (!c.value.isPlaying) await c.play();
      await c.setPlaybackSpeed(2);
      HapticFeedback.selectionClick();
    } else {
      await c.setPlaybackSpeed(1);
    }
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    final c = _videoController;
    if (c == null) return;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      c.play();
    }
    setState(() {});
  }

  void _openInsights() {
    final id = widget.args.targetId;
    if (id == null || id.isEmpty) return;
    Navigator.pushNamed(
      context,
      '/integration/post-insights',
      arguments: PostInsightsArgs(targetType: widget.args.targetType ?? 'video', targetId: id),
    );
  }

  bool get _isOwnContent {
    final me = AuthSession.instance.user?.id;
    return me != null && _creatorId != null && me == _creatorId;
  }

  bool get _isClip => (widget.args.targetType ?? 'video') == 'clip';

  bool get _canDeleteClip => _isClip && _soldCount <= 0;

  bool get _canArchiveClip => _isClip && !_isArchived;

  Future<void> _loadDetail() async {
    setState(() {
      _loadingDetail = true;
      _loadError = null;
    });
    try {
      final type = widget.args.targetType ?? 'video';
      final id = widget.args.targetId!;
      final detail = await _social.getMediaDetail(targetType: type, targetId: id);
      if (!mounted) return;
      final isSubscriber = SubscriptionStore.instance.isSubscribedTo(detail.creatorId ?? _creatorId);
      final sessionUnlocked = isSubscriber || ContentUnlockStore.isUnlocked(type, id);
      final locked = detail.isLocked && !sessionUnlocked;
      if (!detail.isLocked) {
        ContentUnlockStore.mark(type, id);
      }
      setState(() {
        _title = detail.title;
        _thumbnailUrl = detail.thumbnailUrl ?? _thumbnailUrl;
        _creatorName = detail.creatorName ?? _creatorName;
        _creatorId = detail.creatorId ?? _creatorId;
        _followingCreator = detail.isFollowingCreator;
        _soldCount = detail.soldCount;
        _isArchived = detail.isArchived;
        _createdAt = detail.createdAt ?? _createdAt;
        _unlockPrice = detail.unlockPrice > 0 ? detail.unlockPrice : _unlockPrice;
        _locked = locked;
        _loadingDetail = false;
      });
      if (!locked && (widget.args.locked || sessionUnlocked)) {
        widget.onUnlocked?.call(
          widget.args.copyWith(
            locked: false,
            unlockPrice: _unlockPrice,
            mediaUrl: detail.streamUrl,
            clearMediaUrl: detail.streamUrl == null || detail.streamUrl!.isEmpty,
          ),
        );
      }
      final streamUrl = detail.streamUrl?.trim();
      if (!_videoReady &&
          !_isImageMedia &&
          !_locked &&
          (_mediaUrl == null || _mediaUrl!.isEmpty) &&
          streamUrl != null &&
          streamUrl.isNotEmpty &&
          !_urlLooksLikeImage(streamUrl)) {
        final resolved = resolveMediaUrl(streamUrl, resourceType: 'video');
        if (resolved.isNotEmpty) {
          setState(() {
            _mediaUrl = resolved;
            _locked = false;
          });
          await _initVideo(resolved);
        }
      } else if (!_locked &&
          widget.isActive &&
          !_videoReady &&
          !_loadingMedia &&
          (_mediaUrl == null || _mediaUrl!.isEmpty)) {
        await _loadMedia(force: sessionUnlocked);
      }
      await _refreshMetrics();
      if (AuthSession.instance.isSignedIn) {
        unawaited(() async {
          try {
            final viewKey = '$type:${widget.args.targetId}';
            if (!_countedViews.contains(viewKey)) {
              await _feed.recordInteraction(
                action: 'view',
                targetType: type,
                targetId: widget.args.targetId!,
              );
              _countedViews.add(viewKey);
            }
          } catch (_) {}
        }());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingDetail = false;
        _loadError = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _refreshMetrics() async {
    if (!widget.args.hasTarget) return;
    final type = widget.args.targetType ?? 'video';
    final id = widget.args.targetId!;
    try {
      final likes = await _social.getLikeSummary(targetType: type, targetId: id);
      final commentCount = await _social.getCommentCount(targetType: type, targetId: id);
      var shares = _shareCount;
      var comments = commentCount;
      int? ownerViews;
      if (_isOwnContent) {
        final stats = await _insights.getInsights(targetType: type, targetId: id);
        shares = ApiJson.intValue(stats['shares'] ?? stats['shareCount'], fallback: shares);
        if (stats.containsKey('views') || stats.containsKey('viewCount')) {
          ownerViews = ApiJson.intValue(stats['views'] ?? stats['viewCount']);
        }
      }
      if (!mounted) return;
      setState(() {
        _likeCount = likes.count;
        _liked = likes.likedByMe;
        _commentCount = comments;
        _shareCount = shares;
        _ownerViews = ownerViews;
      });
    } catch (_) {
      if (!mounted) return;
      try {
        final likes = await _social.getLikeSummary(targetType: type, targetId: id);
        final commentCount = await _social.getCommentCount(targetType: type, targetId: id);
        if (!mounted) return;
        setState(() {
          _likeCount = likes.count;
          _liked = likes.likedByMe;
          _commentCount = commentCount;
          _ownerViews = null;
        });
      } catch (_) {}
    }
  }

  Future<void> _toggleLike() async {
    if (!widget.args.hasTarget) {
      setState(() {
        _liked = !_liked;
        _likeCount += _liked ? 1 : -1;
      });
      return;
    }
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to like posts.')));
      return;
    }
    final type = widget.args.targetType ?? 'video';
    final id = widget.args.targetId!;
    final wasLiked = _liked;
    setState(() {
      _liked = !wasLiked;
      _likeCount += wasLiked ? -1 : 1;
    });
    try {
      if (wasLiked) {
        await _social.unlike(targetType: type, targetId: id);
      } else {
        await _social.like(targetType: type, targetId: id);
      }
      await _refreshMetrics();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _liked = wasLiked;
        _likeCount += wasLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _toggleFollow() async {
    final creatorId = _creatorId;
    if (creatorId == null || creatorId.isEmpty) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to follow creators.')));
      return;
    }
    final wasFollowing = _followingCreator;
    setState(() => _followingCreator = !wasFollowing);
    try {
      if (wasFollowing) {
        await _social.unfollow(creatorId);
      } else {
        await _social.follow(creatorId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _followingCreator = wasFollowing);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _openCreatorProfile() async {
    var id = _creatorId?.trim();
    if (id == null || id.isEmpty) {
      final type = widget.args.targetType;
      final targetId = widget.args.targetId;
      if (type != null && targetId != null) {
        try {
          final detail = await _social.getMediaDetail(targetType: type, targetId: targetId);
          id = detail.creatorId?.trim();
          if (mounted && id != null && id.isNotEmpty) {
            setState(() {
              _creatorId = id;
              _creatorName = detail.creatorName ?? _creatorName;
            });
          }
        } catch (_) {}
      }
    }
    if (!mounted) return;
    if (id == null || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile unavailable for this post.')),
      );
      return;
    }
    final me = AuthSession.instance.user?.id;
    if (me != null && me == id) {
      Navigator.pushNamed(context, '/profile/creator/profile');
      return;
    }
    Navigator.pushNamed(
      context,
      '/profile/other-user',
      arguments: OtherUserProfileArgs(userId: id),
    );
  }

  void _openComments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CommentsSheet(
        targetType: widget.args.targetType ?? 'video',
        targetId: widget.args.hasTarget ? widget.args.targetId : null,
        onActivity: _refreshMetrics,
      ),
    ).then((_) => _refreshMetrics());
  }

  Future<void> _shareContent() async {
    if (!widget.args.hasTarget) return;
    final type = widget.args.targetType ?? 'video';
    final id = widget.args.targetId!;
    final title = _title ?? 'this post';
    final message = 'Check out "$title" on Xlive\n${mediaShareUrl(id)}';
    try {
      if (AuthSession.instance.isSignedIn) {
        await _feed.recordInteraction(action: 'share', targetType: type, targetId: id);
        if (mounted) setState(() => _shareCount += 1);
        await _refreshMetrics();
      }
      await Share.share(message);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _deleteContent() async {
    final id = widget.args.targetId;
    if (id == null || id.isEmpty) return;
    if (_isClip && !_canDeleteClip) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sold clips cannot be deleted. Archive them instead.')),
      );
      return;
    }
    final label = _isClip ? 'clip' : 'post';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete $label?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      if (_isClip) {
        await _clipsRepo.deleteClip(id);
      } else {
        await _videosRepo.deleteVideo(id);
      }
      if (!mounted) return;
      _finishRemoval();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _archiveContent() async {
    final id = widget.args.targetId;
    if (id == null || id.isEmpty || !_canArchiveClip) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive clip?'),
        content: const Text('This hides the clip from feeds, profiles, and resale. You can manage it later in Clip Archive.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Archive')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await _clipsRepo.archiveClip(id);
      if (!mounted) return;
      _finishRemoval();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _toggleSave() async {
    final ids = widget.args.resolvedSaveTargetIds;
    if (ids.isEmpty || _savingBookmark) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to save media.')));
      return;
    }
    if (_locked) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Unlock this content before saving.')));
      return;
    }
    final type = (widget.args.targetType ?? 'video').trim().toLowerCase();
    if (type == 'clip' || type == 'stream') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only posts and videos can be saved.')),
      );
      return;
    }
    setState(() => _savingBookmark = true);
    try {
      final saved = await SavedMediaStore.instance.toggleAll(
        targetType: type,
        targetIds: ids,
        canView: true,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(saved ? 'Saved' : 'Removed from Saved')),
      );
      setState(() {});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _savingBookmark = false);
    }
  }

  void _openMoreMenu() {
    final isSaved = SavedMediaStore.instance.isSavedAll(widget.args.resolvedSaveTargetIds);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded),
              title: Text(isSaved ? 'Unsave' : 'Save'),
              onTap: () {
                Navigator.pop(ctx);
                _toggleSave();
              },
            ),
            if (_isOwnContent && _canArchiveClip)
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive clip'),
                onTap: () {
                  Navigator.pop(ctx);
                  _archiveContent();
                },
              ),
            if (_isOwnContent && (!_isClip || _canDeleteClip))
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: Text(_isClip ? 'Delete clip' : 'Delete post', style: const TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteContent();
                },
              ),
            ListTile(
              leading: const Icon(Icons.link_rounded),
              title: const Text('Copy link'),
              onTap: () {
                Navigator.pop(ctx);
                final targetId = widget.args.targetId;
                if (targetId == null) return;
                final link = '${widget.args.targetType ?? 'video'}/$targetId';
                Clipboard.setData(ClipboardData(text: link));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied')));
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    final thumb = resolveMediaUrl(_thumbnailUrl);
    final title = _title ?? 'Title of the clip';
    final creator = _creatorName ?? 'VGame';
    final body = Stack(
      fit: StackFit.expand,
      children: [
          Positioned.fill(child: _buildMediaLayer(thumb)),
          if (_locked)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0x33F59E0B),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.lock_rounded, color: Color(0xFFFBBF24), size: 32),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Exclusive Content',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          children: [
                            const TextSpan(text: 'Unlock for '),
                            TextSpan(
                              text: '${_unlockPrice > 0 ? _unlockPrice : 5} coins',
                              style: const TextStyle(color: Color(0xFFFBBF24), fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A3FFC), Color(0xFF3B82F6)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: _unlocking ? null : _unlockContent,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 13),
                                child: Center(
                                  child: _unlocking
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : Text(
                                          (AuthSession.instance.walletBalance ?? 0) < _unlockPrice
                                              ? 'Top up Wallet to Unlock'
                                              : (_unlockPrice > 0
                                                  ? 'Unlock · $_unlockPrice coins'
                                                  : (_isClip ? 'Buy clip' : 'Unlock')),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (_holdingSpeed)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 56,
              right: 18,
              child: IgnorePointer(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '2×',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 180,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.28)],
                  ),
                ),
              ),
            ),
          ),
          if (!_locked && !_isImageMedia && _videoReady)
            Positioned.fill(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _togglePlayPause,
                    ),
                  ),
                  Expanded(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) => _setHoldSpeed(true),
                      onPointerUp: (_) => _setHoldSpeed(false),
                      onPointerCancel: (_) => _setHoldSpeed(false),
                    ),
                  ),
                ],
              ),
            ),
          Positioned(
            left: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: widget.embeddedInReel
                  ? const SizedBox(width: 44, height: 44)
                  : IconButton(
                      padding: const EdgeInsets.only(left: 8, top: 4),
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                    ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 120 + bottomPad,
            child: Column(
              children: [
                if (!_isImageMedia) ...[
                  _sideAction(
                    icon: _soundMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                    label: _soundMuted ? 'Mute' : 'Sound',
                    onTap: _toggleSound,
                  ),
                  const SizedBox(height: 18),
                ],
                _sideAction(
                  icon: _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  label: '$_likeCount',
                  iconColor: _liked ? const Color(0xFFFF3040) : Colors.white,
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 18),
                _sideAction(
                  icon: Icons.mode_comment_rounded,
                  label: '$_commentCount',
                  onTap: _openComments,
                ),
                if (_isOwnContent && _ownerViews != null) ...[
                  const SizedBox(height: 18),
                  _sideAction(
                    icon: Icons.visibility_outlined,
                    label: '$_ownerViews',
                    onTap: _openInsights,
                  ),
                ],
                const SizedBox(height: 18),
                _sideAction(
                  icon: Icons.ios_share_rounded,
                  label: '$_shareCount',
                  onTap: _shareContent,
                ),
                const SizedBox(height: 18),
                if (_isOwnContent)
                  _sideAction(
                    icon: Icons.insights_rounded,
                    label: 'Stats',
                    onTap: _openInsights,
                  ),
                if (_isOwnContent) const SizedBox(height: 18),
                _sideAction(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  onTap: _openMoreMenu,
                ),
              ],
            ),
          ),
          Positioned(
            left: 8,
            right: 72,
            bottom: 78 + bottomPad,
            child: !_locked && !_isImageMedia && _videoReady && _videoController != null
                ? Builder(
                    builder: (_) {
                      final c = _videoController!;
                      final pos = c.value.position;
                      final dur = c.value.duration;
                      final maxMs = dur.inMilliseconds <= 0 ? 1.0 : dur.inMilliseconds.toDouble();
                      final value = pos.inMilliseconds.toDouble().clamp(0.0, maxMs).toDouble();
                      return Row(
                        children: [
                          Text(
                            _fmtDuration(pos),
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.5,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                              ),
                              child: Slider(
                                value: value,
                                max: maxMs,
                                onChanged: (v) {
                                  c.seekTo(Duration(milliseconds: v.round()));
                                  setState(() {});
                                },
                                activeColor: Colors.white,
                                inactiveColor: Colors.white38,
                              ),
                            ),
                          ),
                          Text(
                            _fmtDuration(dur),
                            style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      );
                    },
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            left: 16,
            right: 72,
            bottom: 16 + bottomPad,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: GestureDetector(
                        onTap: _openCreatorProfile,
                        behavior: HitTestBehavior.opaque,
                        child: Text(
                          creator,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    if (formatRelativeTime(_createdAt).isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(
                        '· ${formatRelativeTime(_createdAt)}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                    const SizedBox(width: 10),
                    if (!_isOwnContent)
                      OutlinedButton(
                        onPressed: _creatorId == null ? null : _toggleFollow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white, width: 1),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text(
                          _followingCreator ? 'Following' : 'Follow',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ),
                  ],
                ),
                if (SubscriptionStore.instance.isSubscribedTo(_creatorId)) ...[
                  const SizedBox(height: 5),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A30E5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star_rounded, size: 12, color: Colors.amber),
                        SizedBox(width: 4),
                        Text(
                          'Subscriber All-Access',
                          style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          if (_loadingDetail && !_videoReady && _mediaUrl == null)
            const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
          if (_loadError != null)
            Positioned(
              left: 16,
              right: 16,
              top: MediaQuery.paddingOf(context).top + 56,
              child: Material(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_loadError!, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ),
              ),
            ),
        ],
    );
    if (widget.embeddedInReel) {
      return ColoredBox(color: _black, child: body);
    }
    return Scaffold(
      backgroundColor: _black,
      body: body,
    );
  }

  Widget _buildMediaLayer(String thumb) {
    if (_locked) {
      if (thumb.isNotEmpty) {
        return ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Colors.black)),
        );
      }
      return const ColoredBox(color: Colors.black);
    }
    if (_isImageMedia) {
      final src = (_mediaUrl != null && _mediaUrl!.isNotEmpty) ? _mediaUrl! : thumb;
      if (src.isEmpty) {
        return const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64));
      }
      return InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.network(
            src,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38, size: 64)),
          ),
        ),
      );
    }
    if (_videoReady && _videoController != null) {
      final c = _videoController!;
      return Center(
        child: AspectRatio(
          aspectRatio: c.value.aspectRatio == 0 ? 9 / 16 : c.value.aspectRatio,
          child: VideoPlayer(c),
        ),
      );
    }
    if (_mediaError != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (thumb.isNotEmpty)
            Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          Container(color: Colors.black54),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    _mediaError!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loadingMedia ? null : _retryMedia,
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _black,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: Text(_loadingMedia ? 'Retrying…' : 'Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }
    if (thumb.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        ],
      );
    }
    return const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2));
  }

  Widget _sideAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CommentReactionChip {
  const _CommentReactionChip({required this.code, required this.count, this.mineId});
  final String code;
  final int count;
  final String? mineId;
}

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    this.targetType = 'video',
    this.targetId,
    this.onActivity,
  });

  final String targetType;
  final String? targetId;
  final VoidCallback? onActivity;

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _social = SocialRepository();
  final _input = TextEditingController();
  final _focus = FocusNode();
  List<CommentItem> _comments = const [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  String? _replyToId;
  String? _replyToName;
  final Set<String> _expandedThreads = {};
  bool _pickerOpen = false;
  bool _gifOpen = false;
  String _gifQuery = '';
  List<GiphyGif> _gifs = const [];
  bool _gifLoading = false;
  String? _pendingGifUrl;
  String? _pendingGifPreview;
  Timer? _gifDebounce;
  String? _reactingToId;
  String? _attachError;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments({bool silent = false}) async {
    final targetId = widget.targetId;
    if (targetId == null || targetId.isEmpty) {
      setState(() {
        _loading = false;
        _comments = const [];
      });
      return;
    }
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final comments = await _social.listComments(targetType: widget.targetType, targetId: targetId);
      if (!mounted) return;
      setState(() {
        _comments = _flattenComments(comments);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = silent ? _error : friendlyApiMessage(e);
      });
    }
  }

  List<CommentItem> _flattenComments(List<CommentItem> roots) {
    final out = <CommentItem>[];
    void walk(CommentItem c, String? forcedParent) {
      final node = forcedParent == null || (c.parentId != null && c.parentId!.isNotEmpty)
          ? c
          : CommentItem(
              id: c.id,
              content: c.content,
              authorId: c.authorId,
              authorName: c.authorName,
              authorAvatarUrl: c.authorAvatarUrl,
              createdAt: c.createdAt,
              replyCount: c.replyCount,
              parentId: forcedParent,
            );
      out.add(node);
      for (final reply in c.replies) {
        walk(reply, c.id);
      }
    }
    for (final c in roots) {
      walk(c, null);
    }
    return out;
  }

  Future<void> _loadGifs([String query = '']) async {
    setState(() {
      _gifLoading = true;
      _attachError = null;
    });
    try {
      final items = query.trim().isEmpty ? await listTrendingGiphy() : await searchGiphy(query);
      if (!mounted) return;
      setState(() {
        _gifs = items;
        _gifLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gifLoading = false;
        _attachError = friendlyApiMessage(e);
      });
    }
  }

  void _onGifQuery(String value) {
    _gifQuery = value;
    _gifDebounce?.cancel();
    _gifDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadGifs(value);
    });
  }

  void _toggleGifPicker() {
    final next = !_gifOpen;
    setState(() {
      _gifOpen = next;
      if (next) _pickerOpen = false;
    });
    if (next && _gifs.isEmpty) _loadGifs(_gifQuery);
  }

  Future<void> _sendComment() async {
    final targetId = widget.targetId;
    final text = _input.text.trim();
    final gifUrl = _pendingGifUrl;
    if (targetId == null || targetId.isEmpty) return;
    if (text.isEmpty && (gifUrl == null || gifUrl.isEmpty)) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to comment.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await _social.createComment(
        targetType: widget.targetType,
        targetId: targetId,
        content: composeCommentContent(text, gifUrl),
        parentId: _replyToId,
      );
      _input.clear();
      setState(() {
        _replyToId = null;
        _replyToName = null;
        _pendingGifUrl = null;
        _pendingGifPreview = null;
        _gifOpen = false;
        _attachError = null;
      });
      await _loadComments();
      widget.onActivity?.call();
    } catch (e) {
      if (!mounted) return;
      setState(() => _attachError = friendlyApiMessage(e));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _deleteOwnComment(CommentItem comment) async {
    try {
      await _social.deleteComment(comment.id);
      await _loadComments(silent: true);
      widget.onActivity?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _onCommentLongPress(CommentItem comment) async {
    final copyText = textWithoutMedia(comment.content);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF2C2C2C),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy_rounded, color: Colors.white),
                title: const Text('Copy', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: copyText.isEmpty ? decodeCommentText(comment.content) : copyText));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _beginReply(CommentItem comment) {
    setState(() {
      _replyToId = comment.id;
      _replyToName = comment.authorName ?? 'user';
      if (comment.parentId != null && comment.parentId!.isNotEmpty) {
        _expandedThreads.add(comment.parentId!);
      } else {
        _expandedThreads.add(comment.id);
      }
    });
    _focus.requestFocus();
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  List<CommentItem> get _topLevelComments =>
      _comments.where((c) => (c.parentId == null || c.parentId!.isEmpty) && !isReactionComment(c.content)).toList();

  List<CommentItem> _repliesFor(String parentId) {
    final direct = _comments.where((c) => c.parentId == parentId && !isReactionComment(c.content)).toList();
    final nested = <CommentItem>[];
    for (final d in direct) {
      nested.add(d);
      nested.addAll(_comments.where((c) => c.parentId == d.id && !isReactionComment(c.content)));
    }
    final seen = <String>{};
    return nested.where((c) => seen.add(c.id)).toList();
  }

  List<_CommentReactionChip> _reactionsFor(String parentId) {
    final mine = AuthSession.instance.user?.id;
    final map = <String, _CommentReactionChip>{};
    for (final c in _comments) {
      final parsed = parseReaction(c.content);
      if (parsed == null) continue;
      final target = parsed.parentId ?? c.parentId;
      if (target != parentId) continue;
      final code = parsed.code;
      final cur = map[code] ?? _CommentReactionChip(code: code, count: 0);
      map[code] = _CommentReactionChip(
        code: code,
        count: cur.count + 1,
        mineId: (mine != null && c.authorId == mine) ? c.id : cur.mineId,
      );
    }
    return map.values.toList();
  }

  Future<void> _toggleReaction(String parentId, String code) async {
    final targetId = widget.targetId;
    if (targetId == null || targetId.isEmpty) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to react.')));
      return;
    }
    final mineId = _reactionsFor(parentId).where((r) => r.code == code).map((r) => r.mineId).firstWhere(
          (id) => id != null && id.isNotEmpty,
          orElse: () => null,
        );
    setState(() => _reactingToId = null);
    try {
      if (mineId != null) {
        await _social.deleteComment(mineId);
      } else {
        await _social.createComment(
          targetType: widget.targetType,
          targetId: targetId,
          content: reactionToken(code, parentId),
          parentId: parentId,
        );
      }
      await _loadComments(silent: true);
      widget.onActivity?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  String? _replyTargetName(CommentItem reply) {
    final parentId = reply.parentId;
    if (parentId == null || parentId.isEmpty) return null;
    for (final c in _comments) {
      if (c.id == parentId) return c.authorName;
    }
    return null;
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    _gifDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.68,
        minChildSize: 0.38,
        maxChildSize: 0.92,
        builder: (ctx, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: _sheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey.shade600, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator(color: Colors.white54, strokeWidth: 2))
                      : _error != null
                          ? Center(child: Text(_error!, style: const TextStyle(color: _muted)))
                          : _topLevelComments.isEmpty
                              ? const Center(child: Text('No comments yet', style: TextStyle(color: _muted)))
                              : ListView.builder(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  itemCount: _topLevelComments.length,
                                  itemBuilder: (_, i) {
                                    final c = _topLevelComments[i];
                                    final replies = _repliesFor(c.id);
                                    final expanded = _expandedThreads.contains(c.id);
                                    const previewCount = 2;
                                    final visibleReplies = expanded || replies.length <= previewCount
                                        ? replies
                                        : replies.take(previewCount).toList();
                                    final hidden = replies.length - visibleReplies.length;
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        _commentBlock(
                                          comment: c,
                                          onReply: () => _beginReply(c),
                                        ),
                                        for (final reply in visibleReplies)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 44, bottom: 8),
                                            child: _commentBlock(
                                              comment: reply,
                                              onReply: () => _beginReply(reply),
                                              compact: true,
                                              replyToName: _replyTargetName(reply),
                                            ),
                                          ),
                                        if (hidden > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 56, bottom: 14),
                                            child: GestureDetector(
                                              onTap: () => setState(() => _expandedThreads.add(c.id)),
                                              child: Text(
                                                'View $hidden more ${hidden == 1 ? 'reply' : 'replies'}',
                                                style: const TextStyle(
                                                  color: _muted,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          )
                                        else if (expanded && replies.length > previewCount)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 56, bottom: 14),
                                            child: GestureDetector(
                                              onTap: () => setState(() => _expandedThreads.remove(c.id)),
                                              child: const Text(
                                                'Hide replies',
                                                style: TextStyle(
                                                  color: _muted,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    );
                                  },
                                ),
                ),
                if (_replyToId != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFF252528),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Replying to @${_replyToName ?? 'user'}',
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ),
                        IconButton(
                          onPressed: _cancelReply,
                          icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                if (_pickerOpen)
                  SizedBox(
                    height: 148,
                    child: GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: commentEmojiPackList.length,
                      itemBuilder: (_, i) {
                        final item = commentEmojiPackList[i];
                        return GestureDetector(
                          onTap: () {
                            final next = '${_input.text}${item.glyph}';
                            _input.value = TextEditingValue(
                              text: next,
                              selection: TextSelection.collapsed(offset: next.length),
                            );
                            setState(() {});
                          },
                          child: Center(child: Text(item.glyph, style: const TextStyle(fontSize: 22))),
                        );
                      },
                    ),
                  ),
                if (_gifOpen)
                  SizedBox(
                    height: 220,
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  style: const TextStyle(color: Colors.white, fontSize: 14),
                                  onChanged: _onGifQuery,
                                  decoration: const InputDecoration(
                                    hintText: 'Search GIPHY',
                                    hintStyle: TextStyle(color: _muted),
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text('GIPHY', style: TextStyle(color: _muted, fontSize: 10, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _gifLoading
                              ? const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)))
                              : GridView.builder(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 6,
                                    crossAxisSpacing: 6,
                                  ),
                                  itemCount: _gifs.length,
                                  itemBuilder: (_, i) {
                                    final gif = _gifs[i];
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _pendingGifUrl = gif.url;
                                          _pendingGifPreview = gif.previewUrl;
                                          _gifOpen = false;
                                          _attachError = null;
                                        });
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(
                                          gif.previewUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFF2C2C2C)),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + bottomInset),
                  color: _sheetBg,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_pendingGifPreview != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _pendingGifPreview!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => const SizedBox(width: 56, height: 56),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setState(() {
                                  _pendingGifUrl = null;
                                  _pendingGifPreview = null;
                                }),
                                child: const Text('Remove', style: TextStyle(color: Colors.white70)),
                              ),
                            ],
                          ),
                        ),
                      if (_attachError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(_attachError!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                        ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => setState(() {
                              _pickerOpen = !_pickerOpen;
                              if (_pickerOpen) _gifOpen = false;
                            }),
                            icon: Icon(
                              _pickerOpen ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                              color: Colors.white70,
                            ),
                          ),
                          TextButton(
                            onPressed: _sending ? null : _toggleGifPicker,
                            child: Text(
                              'GIF',
                              style: TextStyle(
                                color: _gifOpen ? const Color(0xFF8B5CF6) : Colors.white70,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(999)),
                              child: TextField(
                                controller: _input,
                                focusNode: _focus,
                                style: const TextStyle(color: Colors.white, fontSize: 16),
                                minLines: 1,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  hintText: _replyToId == null ? 'Add a comment…' : 'Write a reply…',
                                  hintStyle: const TextStyle(color: _muted),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Material(
                            color: _sendPurple,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: _sending ? null : _sendComment,
                              child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Icon(Icons.send_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _commentBlock({
    required CommentItem comment,
    required VoidCallback onReply,
    bool compact = false,
    String? replyToName,
  }) {
    final user = comment.authorName == null ? '@user' : '@${comment.authorName}';
    final decoded = textWithoutMedia(comment.content);
    final media = extractMediaUrls(comment.content);
    final emojiOnly = decoded.isNotEmpty && media.isEmpty && !RegExp(r'[A-Za-z0-9]').hasMatch(decoded);
    final chips = _reactionsFor(comment.id);
    final me = AuthSession.instance.user?.id;
    final mine = me != null && comment.authorId == me;
    return GestureDetector(
      onLongPress: () => _onCommentLongPress(comment),
      child: Padding(
      padding: EdgeInsets.only(bottom: compact ? 8 : 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(radius: compact ? 14 : 18, imageUrl: comment.authorAvatarUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(user, style: TextStyle(color: Colors.white, fontSize: compact ? 13 : 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                          ),
                          Text(' • ${comment.timeLabel}', style: const TextStyle(color: _muted, fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
                if (replyToName != null && replyToName.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 2),
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(color: _muted, fontSize: compact ? 12 : 13),
                        children: [
                          const TextSpan(text: 'Replying to '),
                          TextSpan(
                            text: '@$replyToName',
                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (decoded.isNotEmpty)
                  Text(
                    decoded,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: emojiOnly ? 28 : (compact ? 13 : 14),
                      height: 1.4,
                    ),
                  ),
                for (final url in media)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        url,
                        height: 140,
                        fit: BoxFit.cover,
                        semanticLabel: '${comment.authorName ?? 'user'} commented${decoded.isEmpty ? '' : ': $decoded'}',
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                Row(
                  children: [
                    TextButton(
                      onPressed: onReply,
                      style: TextButton.styleFrom(foregroundColor: _muted, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('Reply', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(width: 12),
                    TextButton(
                      onPressed: () => setState(() => _reactingToId = _reactingToId == comment.id ? null : comment.id),
                      style: TextButton.styleFrom(foregroundColor: _muted, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      child: const Text('React', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                    ),
                    if (mine) ...[
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: () => _deleteOwnComment(comment),
                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Delete', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.redAccent)),
                      ),
                    ],
                  ],
                ),
                if (_reactingToId == comment.id)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final code in quickReactionCodes)
                          GestureDetector(
                            onTap: () => _toggleReaction(comment.id, code),
                            child: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(color: _inputBg, borderRadius: BorderRadius.circular(18)),
                              child: Text(glyphForCode(code), style: const TextStyle(fontSize: 18)),
                            ),
                          ),
                      ],
                    ),
                  ),
                if (chips.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in chips)
                        GestureDetector(
                          onTap: () => _toggleReaction(comment.id, chip.code),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: chip.mineId != null ? const Color(0x338E24ED) : _inputBg,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: chip.mineId != null ? _sendPurple : Colors.white12),
                            ),
                            child: Text(
                              '${glyphForCode(chip.code)} ${chip.count}',
                              style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
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
