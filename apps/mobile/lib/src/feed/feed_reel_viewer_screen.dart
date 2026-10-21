import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/media/media_url_cache.dart';
import '../../features/feed/models/feed_models.dart';
import 'video_preview_comment_screens.dart';

class FeedReelViewerScreen extends StatefulWidget {
  const FeedReelViewerScreen({super.key, required this.args});

  final FeedReelViewerArgs args;

  @override
  State<FeedReelViewerScreen> createState() => _FeedReelViewerScreenState();
}

class _FeedReelViewerScreenState extends State<FeedReelViewerScreen> {
  late final PageController _pageController;
  late List<VideoClipPreviewArgs> _items;
  late int _index;
  late int _page;
  bool _loadingMore = false;
  bool _hasMore = true;
  bool _removedAny = false;

  @override
  void initState() {
    super.initState();
    _items = List<VideoClipPreviewArgs>.from(widget.args.items);
    final maxIndex = _items.isEmpty ? 0 : _items.length - 1;
    _index = widget.args.initialIndex.clamp(0, maxIndex);
    _page = widget.args.initialPage;
    _hasMore = widget.args.loadMore != null;
    _pageController = PageController(initialPage: _index);
    _pageController.addListener(_onScrollPosition);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _items.isEmpty) return;
      _prefetchAround(_index);
      if (_index >= _items.length - 2) _loadMore();
    });
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScrollPosition);
    _pageController.dispose();
    super.dispose();
  }

  void _onScrollPosition() {
    if (!_pageController.hasClients || _items.isEmpty) return;
    final page = _pageController.page;
    if (page == null) return;
    final nearest = page.round().clamp(0, _items.length - 1);
    if (nearest == _index) return;
    setState(() => _index = nearest);
    _prefetchAround(nearest);
    if (nearest >= _items.length - 3) _loadMore();
  }

  void _prefetchAround(int index) {
    if (_items.isEmpty) return;
    final start = index.clamp(0, _items.length - 1);
    final end = (index + 3).clamp(0, _items.length);
    for (var i = start; i < end; i++) {
      final item = _items[i];
      final id = item.targetId;
      final type = item.targetType;
      if (id == null || id.isEmpty || type == null || type.isEmpty) continue;
      MediaUrlCache.resolved(type, id, resourceType: item.isImage ? 'image' : null);
    }
  }

  Future<void> _loadMore() async {
    final loader = widget.args.loadMore;
    if (loader == null || _loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final nextPage = _page + 1;
    try {
      final more = await loader(nextPage);
      if (!mounted) return;
      if (more.isEmpty) {
        setState(() {
          _hasMore = false;
          _loadingMore = false;
        });
        return;
      }
      final existing = _items.map((e) => e.targetId).whereType<String>().toSet();
      final fresh = more.where((e) => e.targetId != null && !existing.contains(e.targetId)).toList();
      setState(() {
        _items = [..._items, ...fresh];
        _page = nextPage;
        _hasMore = more.length >= 10;
        _loadingMore = false;
      });
      _prefetchAround(_index);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    _prefetchAround(index);
    if (index >= _items.length - 3) _loadMore();
  }

  void _onRemoved(String targetId) {
    _removedAny = true;
    final removeAt = _items.indexWhere((e) => e.targetId == targetId);
    if (removeAt < 0) return;
    setState(() {
      _items = List<VideoClipPreviewArgs>.from(_items)..removeAt(removeAt);
    });
    if (_items.isEmpty) {
      Navigator.pop(context, true);
      return;
    }
    final nextIndex = removeAt.clamp(0, _items.length - 1);
    setState(() => _index = nextIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_pageController.hasClients) return;
      _pageController.jumpToPage(nextIndex);
    });
  }

  void _onUnlocked(VideoClipPreviewArgs updated) {
    final id = updated.targetId;
    if (id == null || id.isEmpty) return;
    final at = _items.indexWhere((e) => e.targetId == id);
    if (at < 0) return;
    final current = _items[at];
    if (!current.locked && (updated.mediaUrl == null || updated.mediaUrl == current.mediaUrl)) return;
    setState(() {
      final next = List<VideoClipPreviewArgs>.from(_items);
      next[at] = current.copyWith(
        locked: false,
        unlockPrice: updated.unlockPrice,
        mediaUrl: updated.mediaUrl,
        clearMediaUrl: updated.mediaUrl == null || updated.mediaUrl!.isEmpty,
      );
      _items = next;
    });
  }

  void _close() {
    Navigator.pop(context, _removedAny);
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: Text('No videos', style: TextStyle(color: Colors.white70))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            allowImplicitScrolling: false,
            physics: const PageScrollPhysics(parent: BouncingScrollPhysics()),
            itemCount: _items.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final args = _items[index];
              final active = index == _index;
              return RepaintBoundary(
                child: VideoClipPreviewScreen(
                  key: ValueKey('reel_${args.targetType}_${args.targetId}'),
                  args: args,
                  isActive: active,
                  embeddedInReel: true,
                  onRemoved: _onRemoved,
                  onUnlocked: _onUnlocked,
                ),
              );
            },
          ),
          Positioned(
            left: 0,
            top: 0,
            child: SafeArea(
              bottom: false,
              child: IconButton(
                padding: const EdgeInsets.only(left: 8, top: 4),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: _close,
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
              ),
            ),
          ),
          if (_loadingMore)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 28,
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

List<FeedItem> feedReelPlayableItems(Iterable<FeedItem> items) {
  return items.where((e) => e.type != FeedContentType.stream).toList();
}

Future<Object?> openFeedReelViewer(
  BuildContext context, {
  required List<FeedItem> items,
  required FeedItem opened,
  int initialPage = 1,
  Future<List<FeedItem>> Function(int page)? loadMoreFeed,
}) {
  final playable = feedReelPlayableItems(items);
  var index = playable.indexWhere((e) => e.id == opened.id);
  final seed = List<FeedItem>.from(playable);
  if (index < 0) {
    seed.insert(0, opened);
    index = 0;
  }
  return Navigator.pushNamed(
    context,
    '/media/preview',
    arguments: FeedReelViewerArgs(
      items: seed.map(VideoClipPreviewArgs.fromFeedItem).toList(),
      initialIndex: index,
      initialPage: initialPage,
      loadMore: loadMoreFeed == null
          ? null
          : (page) async {
              final more = await loadMoreFeed(page);
              return feedReelPlayableItems(more).map(VideoClipPreviewArgs.fromFeedItem).toList();
            },
    ),
  );
}
