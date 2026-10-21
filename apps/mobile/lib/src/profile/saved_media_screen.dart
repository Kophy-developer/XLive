import 'package:flutter/material.dart';

import '../../core/media/media_url.dart';
import '../../core/media/saved_media_store.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/session/auth_session.dart';
import '../../features/social/social_repository.dart';
import '../feed/feed_reel_viewer_screen.dart';
import '../feed/video_preview_comment_screens.dart';

class SavedMediaScreen extends StatefulWidget {
  const SavedMediaScreen({super.key});

  @override
  State<SavedMediaScreen> createState() => _SavedMediaScreenState();
}

class _SavedMediaScreenState extends State<SavedMediaScreen> {
  final _social = SocialRepository();
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
      await SavedMediaStore.instance.ensureLoaded();
      final refs = SavedMediaStore.instance.items;
      final loaded = <VideoClipPreviewArgs>[];
      for (final ref in refs) {
        try {
          final detail = await _social.getMediaDetail(targetType: ref.targetType, targetId: ref.targetId);
          if (detail.isLocked) continue;
          loaded.add(
            VideoClipPreviewArgs(
              targetType: ref.targetType,
              targetId: ref.targetId,
              title: detail.title,
              thumbnailUrl: detail.thumbnailUrl,
              mediaUrl: detail.streamUrl,
              creatorId: detail.creatorId,
              creatorName: detail.creatorName,
              unlockPrice: detail.unlockPrice,
              locked: false,
              isImage: detail.streamUrl != null &&
                  (detail.streamUrl!.toLowerCase().contains('.jpg') ||
                      detail.streamUrl!.toLowerCase().contains('.png') ||
                      detail.streamUrl!.toLowerCase().contains('.webp') ||
                      detail.streamUrl!.toLowerCase().contains('/image')),
              commentCount: detail.commentCount,
              likeCount: detail.likeCount,
            ),
          );
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _items = loaded;
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
                            child: ColoredBox(
                              color: const Color(0xFF1C1C1E),
                              child: thumb.isEmpty
                                  ? const Center(child: Icon(Icons.movie_outlined, color: Colors.white38))
                                  : Image.network(
                                      thumb,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) =>
                                          const Center(child: Icon(Icons.broken_image_outlined, color: Colors.white38)),
                                    ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
