import 'package:flutter/material.dart';

import '../../core/media/media_url.dart';
import '../../core/media/saved_media_store.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/session/auth_session.dart';
import '../../features/feed/feed_album.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/social/models/social_models.dart';
import '../feed/feed_reel_viewer_screen.dart';
import '../feed/video_preview_comment_screens.dart';

class SavedMediaScreen extends StatefulWidget {
  const SavedMediaScreen({super.key});

  @override
  State<SavedMediaScreen> createState() => _SavedMediaScreenState();
}

class _SavedMediaScreenState extends State<SavedMediaScreen> {
  bool _loading = true;
  String? _error;
  List<VideoClipPreviewArgs> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!AuthSession.instance.isSignedIn) {
      setState(() {
        _loading = false;
        _error = 'Sign in to see saved media.';
        _items = const [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final details = await SavedMediaStore.instance.fetchSavedDetails(page: 1, limit: 100);
      final visible = details.where((d) => d.id.isNotEmpty && !d.isLocked).toList();
      final coalesced = coalesceFeedAlbums([for (final d in visible) _toFeedItem(d)]);
      if (!mounted) return;
      setState(() {
        _items = [for (final item in coalesced) VideoClipPreviewArgs.fromFeedItem(item)];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  FeedItem _toFeedItem(MediaDetail detail) {
    return FeedItem(
      id: detail.id,
      type: detail.type,
      title: detail.title,
      thumbnailUrl: detail.thumbnailUrl,
      mediaType: detail.mediaType,
      viewCount: detail.viewCount,
      likeCount: detail.likeCount,
      commentCount: detail.commentCount,
      creatorId: detail.creatorId,
      creatorName: detail.creatorName,
      createdAt: detail.createdAt,
      accessAllowed: detail.accessAllowed,
      needsPurchase: detail.needsPurchase,
      needsUnlock: detail.needsUnlock,
      unlockPrice: detail.unlockPrice,
      saveCount: detail.saveCount,
    );
  }

  void _open(int index) {
    if (_items.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FeedReelViewerScreen(
          args: FeedReelViewerArgs(
            items: _items,
            initialIndex: index,
            initialPage: 1,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(onPressed: _load, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(child: Text('No saved media yet'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(8),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 4,
                          mainAxisSpacing: 4,
                        ),
                        itemCount: _items.length,
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          final thumb = resolveMediaUrl(item.thumbnailUrl, resourceType: 'image');
                          return GestureDetector(
                            onTap: () => _open(index),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColoredBox(
                                  color: const Color(0xFF1C1C1E),
                                  child: thumb.isEmpty
                                      ? const Center(
                                          child: Icon(Icons.bookmark_outline_rounded, color: Colors.white38),
                                        )
                                      : Image.network(
                                          thumb,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Center(
                                            child: Icon(Icons.broken_image_outlined, color: Colors.white38),
                                          ),
                                        ),
                                ),
                                if (item.isAlbum)
                                  const Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Icon(Icons.collections_rounded, color: Colors.white, size: 16),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
