import 'package:flutter/material.dart';

import '../../features/feed/feed_repository.dart';
import '../../features/feed/models/feed_models.dart';
import '../feed/feed_reel_viewer_screen.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);

class CategoryFeedScreen extends StatefulWidget {
  const CategoryFeedScreen({super.key, required this.categorySlug});

  final String categorySlug;

  @override
  State<CategoryFeedScreen> createState() => _CategoryFeedScreenState();
}

class _CategoryFeedScreenState extends State<CategoryFeedScreen> {
  final _feedRepo = FeedRepository();
  List<FeedItem> _items = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _feedRepo.getCategoryFeed(widget.categorySlug);
      if (!mounted) return;
      setState(() {
        _items = items;
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

  @override
  Widget build(BuildContext context) {
    final title = widget.categorySlug.replaceAll('-', ' ');
    return XLiveSubpage(
      title: title.isEmpty ? 'Category' : title[0].toUpperCase() + title.substring(1),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _CategoryErrorBody(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const _CategoryEmptyBody()
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 0.65,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (_, i) {
                        final item = _items[i];
                        return GestureDetector(
                          onTap: () => openFeedReelViewer(
                            context,
                            items: _items,
                            opened: item,
                            initialPage: 1,
                            loadMoreFeed: (page) => _feedRepo.getCategoryFeed(widget.categorySlug, page: page),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (item.thumbnailUrl != null)
                                  Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                                else
                                  Container(color: Colors.grey.shade300, child: const Icon(Icons.play_circle_outline_rounded, size: 40)),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  right: 8,
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}

class _CategoryEmptyBody extends StatelessWidget {
  const _CategoryEmptyBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('No posts in this category yet', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
          ],
        ),
      ),
    );
  }
}

class _CategoryErrorBody extends StatelessWidget {
  const _CategoryErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _purple),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
