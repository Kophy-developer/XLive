import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/explore/explore_recent_searches.dart';
import '../../core/media/media_url_cache.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/session/auth_session.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/explore/explore_repository.dart';
import '../../features/feed/feed_repository.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/hashtags/hashtags_repository.dart';
import '../../features/social/social_repository.dart';
import '../../features/streams/models/stream_models.dart';
import '../../features/streams/streams_repository.dart';
import '../../features/users/models/user_models.dart';
import '../../features/users/users_repository.dart';
import '../app_bottom_nav.dart';
import '../chats/group_chat_screen.dart';
import '../feed/video_preview_comment_screens.dart';
import '../live/live_stream_flow.dart';
import '../profile/user_profile_preview_screens.dart';
import '../social/social_api_screens.dart';

const _black = Color(0xFF0A0A0A);
const _searchFill = Color(0xFFF2F2F2);
const _tabInactive = Color(0xFF8E8E93);
const _sectionMuted = Color(0xFF8E8E93);
const _followGradStart = Color(0xFF66A6FF);
const _followGradEnd = Color(0xFF896CFE);

class _LiveCardData {
  const _LiveCardData({
    required this.streamId,
    required this.name,
    this.imageUrl,
    required this.viewers,
    required this.points,
    this.contentType = FeedContentType.stream,
    this.title,
    this.creatorId,
    this.creatorName,
    this.likeCount = 0,
    this.commentCount = 0,
    this.isImage = false,
  });

  final String streamId;
  final String name;
  final String? imageUrl;
  final int viewers;
  final int points;
  final FeedContentType contentType;
  final String? title;
  final String? creatorId;
  final String? creatorName;
  final int likeCount;
  final int commentCount;
  final bool isImage;

  bool get gradientOnly => imageUrl == null || imageUrl!.isEmpty;

  bool get isLiveStream => contentType == FeedContentType.stream;

  String get targetType => switch (contentType) {
        FeedContentType.clip => 'clip',
        FeedContentType.stream => 'stream',
        _ => 'video',
      };

  factory _LiveCardData.fromStream(LiveStream stream) {
    final image = stream.thumbnailUrl ?? stream.hostAvatarUrl;
    return _LiveCardData(
      streamId: stream.id,
      name: stream.hostName ?? stream.title,
      imageUrl: image,
      viewers: stream.viewerCount,
      points: stream.giftPoints,
    );
  }

  factory _LiveCardData.fromFeed(FeedItem item) {
    return _LiveCardData(
      streamId: item.id,
      name: item.displayName,
      imageUrl: item.thumbnailUrl ?? item.creatorAvatarUrl,
      viewers: item.viewCount,
      points: item.points,
      contentType: item.type,
      title: item.title,
      creatorId: item.creatorId,
      creatorName: item.creatorName,
      likeCount: item.likeCount,
      commentCount: item.commentCount,
      isImage: item.isImage,
    );
  }
}

void _openLiveStream(BuildContext context, String streamId, {String? creatorId}) {
  final isHost = creatorId != null &&
      creatorId == AuthSession.instance.user?.id;
  Navigator.pushNamed(
    context,
    '/live/during',
    arguments: LiveDuringArgs(streamId: streamId, isHost: isHost),
  );
}

void _openExploreMedia(BuildContext context, _LiveCardData item, {List<_LiveCardData>? siblings}) {
  if (item.isLiveStream) {
    _openLiveStream(context, item.streamId, creatorId: item.creatorId);
    return;
  }
  final pool = (siblings ?? const <_LiveCardData>[])
      .where((e) => !e.isLiveStream)
      .toList();
  VideoClipPreviewArgs toArgs(_LiveCardData e) => VideoClipPreviewArgs(
        targetType: e.targetType,
        targetId: e.streamId,
        title: e.title ?? e.name,
        thumbnailUrl: e.imageUrl,
        creatorId: e.creatorId,
        creatorName: e.creatorName ?? e.name,
        likeCount: e.likeCount,
        viewCount: e.viewers,
        commentCount: e.commentCount,
        isImage: e.isImage,
        mediaUrl: MediaUrlCache.resolved(e.targetType, e.streamId),
      );
  if (pool.length <= 1) {
    Navigator.pushNamed(
      context,
      '/media/preview',
      arguments: toArgs(item),
    );
    return;
  }
  var index = pool.indexWhere((e) => e.streamId == item.streamId);
  if (index < 0) {
    pool.insert(0, item);
    index = 0;
  }
  Navigator.pushNamed(
    context,
    '/media/preview',
    arguments: FeedReelViewerArgs(
      items: pool.map(toArgs).toList(),
      initialIndex: index,
    ),
  );
}

class ExploreMenuScreen extends StatefulWidget {
  const ExploreMenuScreen({super.key});

  @override
  State<ExploreMenuScreen> createState() => _ExploreMenuScreenState();
}

class _ExploreMenuScreenState extends State<ExploreMenuScreen> {
  int _tab = 0;

  Future<void> _openSearch() async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const ExploreSearchScreen()));
    if (mounted) setState(() {});
  }

  void _goPeopleTab() => setState(() => _tab = 2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 52,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _black),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false);
                  }
                },
              ),
              Expanded(child: _ExploreSearchPill(onTap: _openSearch)),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ExploreTabBar(selected: _tab, onSelect: (i) => setState(() => _tab = i)),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                _ExploreAllBody(onViewAllPeople: _goPeopleTab),
                const _ExploreLiveBody(),
                _ExplorePeopleListBody(),
                _ExploreHashtagsBody(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const MainBottomNav(selected: MainNavItem.explore),
    );
  }
}

class _ExploreSearchPill extends StatelessWidget {
  const _ExploreSearchPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.centerLeft,
          decoration: BoxDecoration(color: _searchFill, borderRadius: BorderRadius.circular(999)),
          child: Row(
            children: [
              Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text('Search', style: TextStyle(color: Colors.grey.shade500, fontSize: 16, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExploreTabBar extends StatelessWidget {
  const _ExploreTabBar({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _labels = ['All', 'Live', 'People', 'Trending'];
  static const _icons = [
    Icons.auto_awesome_rounded,
    Icons.sensors_rounded,
    Icons.people_alt_rounded,
    Icons.tag_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: _labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final active = selected == i;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: Material(
              color: active ? _black : _searchFill,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(_icons[i], size: 17, color: active ? Colors.white : _tabInactive),
                      const SizedBox(width: 6),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Colors.white : _tabInactive,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExploreEmptyState extends StatelessWidget {
  const _ExploreEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_followGradStart.withValues(alpha: 0.18), _followGradEnd.withValues(alpha: 0.18)],
            ),
          ),
          child: Icon(icon, size: 38, color: _followGradEnd),
        ),
        const SizedBox(height: 18),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: _sectionMuted, height: 1.45),
        ),
      ],
    );
    if (compact) {
      return Padding(padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28), child: content);
    }
    return Center(
      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: content),
    );
  }
}

class _ExploreAllBody extends StatefulWidget {
  const _ExploreAllBody({required this.onViewAllPeople});

  final VoidCallback onViewAllPeople;

  @override
  State<_ExploreAllBody> createState() => _ExploreAllBodyState();
}

class _ExploreAllBodyState extends State<_ExploreAllBody> {
  final _feedRepo = FeedRepository();
  final _usersRepo = UsersRepository();
  final _streamsRepo = StreamsRepository();
  final _socialRepo = SocialRepository();
  List<XLiveUser> _people = const [];
  List<_LiveCardData> _liveStreams = const [];
  List<_LiveCardData> _suggestions = const [];
  bool _loadingPeople = false;
  bool _loadingLive = false;

  @override
  void initState() {
    super.initState();
    _loadPeople();
    _loadLive();
    _loadSuggestions();
  }

  Future<void> _loadLive() async {
    try {
      final streams = await _streamsRepo.listLive(limit: 30);
      if (!mounted) return;
      setState(() {
        _liveStreams = streams.map(_LiveCardData.fromStream).toList();
        _loadingLive = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingLive = false);
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final feed = await _feedRepo.getForYou(limit: 9);
      if (!mounted) return;
      setState(() => _suggestions = feed.map(_LiveCardData.fromFeed).toList());
      MediaUrlCache.prefetchFeedItems(feed, limit: 6);
    } catch (_) {}
  }

  Future<void> _followUser(String userId) async {
    try {
      await _socialRepo.follow(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Followed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _loadPeople() async {
    try {
      List<XLiveUser> people;
      if (AuthSession.instance.isSignedIn) {
        try {
          final feed = await _feedRepo.followersFeed(limit: 8);
          if (!mounted) return;
          final deduped = <String, XLiveUser>{};
          for (final f in feed) {
            final id = f.creatorId?.trim();
            if (id == null || id.isEmpty) continue;
            final name = f.creatorName?.trim();
            if (name == null || name.isEmpty) continue;
            deduped.putIfAbsent(
              id,
              () => XLiveUser(id: id, displayName: name, avatarUrl: f.creatorAvatarUrl),
            );
          }
          setState(() {
            _people = deduped.values.toList();
            _loadingPeople = false;
          });
          return;
        } catch (_) {}
      }
      people = await _usersRepo.listOnline(limit: 8);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loadingPeople = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPeople = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['live', 'music', 'sports', 'comedy'].map((slug) {
                return ActionChip(
                  label: Text(slug[0].toUpperCase() + slug.substring(1)),
                  onPressed: () => Navigator.pushNamed(context, '/integration/category-feed', arguments: slug),
                );
              }).toList(),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('Live streams', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
          ),
        ),
        if (_loadingLive)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
        else if (_liveStreams.isEmpty)
          const SliverToBoxAdapter(
            child: _ExploreEmptyState(
              icon: Icons.sensors_rounded,
              title: 'No one is live yet',
              subtitle: 'Be the first to go live, or check back soon for streams.',
              compact: true,
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 0.68,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = _liveStreams[i];
                  return ExploreStreamCard(
                    name: s.name,
                    imageUrl: s.imageUrl,
                    viewers: s.viewers,
                    points: s.points,
                    gradientOnly: s.gradientOnly,
                    onTap: () => _openLiveStream(context, s.streamId),
                  );
                },
                childCount: _liveStreams.length,
              ),
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                Text('People', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
                const Spacer(),
                GestureDetector(
                  onTap: widget.onViewAllPeople,
                  child: Text('View all >', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _tabInactive)),
                ),
              ],
            ),
          ),
        ),
        if (_loadingPeople)
          const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
        else if (_people.isEmpty)
          const SliverToBoxAdapter(
            child: _ExploreEmptyState(
              icon: Icons.people_alt_rounded,
              title: 'No people to show',
              subtitle: 'Follow creators to see them here.',
              compact: true,
            ),
          )
        else
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                if (i >= _people.length.clamp(0, 4)) return null;
                final p = _people[i];
                final name = p.displayName ?? p.username ?? 'User';
                return Padding(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: i == 3 ? 8 : 16),
                  child: _ExplorePeopleRow(
                    name: name,
                    avatarUrl: p.avatarUrl,
                    onAdd: () => _followUser(p.id),
                    onRow: () => Navigator.pushNamed(
                      context,
                      '/profile/other-user',
                      arguments: OtherUserProfileArgs(userId: p.id),
                    ),
                  ),
                );
              },
              childCount: _people.length.clamp(0, 4),
            ),
          ),
        if (_suggestions.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 0, 8),
              child: Text('Suggestions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
            ),
          ),
          SliverToBoxAdapter(
            child: _SuggestionCarouselSection(
              label: '#ForYou',
              entries: _suggestions,
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _ExploreLiveBody extends StatefulWidget {
  const _ExploreLiveBody();

  @override
  State<_ExploreLiveBody> createState() => _ExploreLiveBodyState();
}

class _ExploreLiveBodyState extends State<_ExploreLiveBody> {
  final _streamsRepo = StreamsRepository();
  List<_LiveCardData> _streams = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final streams = await _streamsRepo.listLive(limit: 30);
      if (!mounted) return;
      setState(() {
        _streams = streams.map(_LiveCardData.fromStream).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_streams.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            _ExploreEmptyState(
              icon: Icons.sensors_rounded,
              title: 'No one is live yet',
              subtitle: 'Live streams will show up here the moment creators go on air. Pull down to refresh.',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.68,
        ),
        itemCount: _streams.length,
        itemBuilder: (context, i) {
          final s = _streams[i];
          return ExploreStreamCard(
            name: s.name,
            imageUrl: s.imageUrl,
            viewers: s.viewers,
            points: s.points,
            gradientOnly: s.gradientOnly,
            showNewBadge: false,
            onTap: () => _openLiveStream(context, s.streamId),
          );
        },
      ),
    );
  }
}

class _ExplorePeopleListBody extends StatefulWidget {
  @override
  State<_ExplorePeopleListBody> createState() => _ExplorePeopleListBodyState();
}

class _ExplorePeopleListBodyState extends State<_ExplorePeopleListBody> {
  final _usersRepo = UsersRepository();
  final _feedRepo = FeedRepository();
  final _socialRepo = SocialRepository();
  List<XLiveUser> _people = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _followUser(String userId) async {
    try {
      await _socialRepo.follow(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Followed')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _load() async {
    try {
      List<XLiveUser> people;
      if (AuthSession.instance.isSignedIn) {
        try {
          final feed = await _feedRepo.followersFeed(limit: 30);
          final deduped = <String, XLiveUser>{};
          for (final f in feed) {
            final id = f.creatorId?.trim();
            if (id == null || id.isEmpty) continue;
            final name = f.creatorName?.trim();
            if (name == null || name.isEmpty) continue;
            deduped.putIfAbsent(
              id,
              () => XLiveUser(id: id, displayName: name, avatarUrl: f.creatorAvatarUrl),
            );
          }
          people = deduped.values.toList();
          if (people.isNotEmpty) {
            if (!mounted) return;
            setState(() {
              _people = people;
              _loading = false;
            });
            return;
          }
        } catch (_) {}
      }
      people = await _usersRepo.listOnline(limit: 30);
      if (!mounted) return;
      setState(() {
        _people = people;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_people.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            _ExploreEmptyState(
              icon: Icons.people_alt_rounded,
              title: 'No people to show',
              subtitle: 'When creators and people you follow are around, you’ll find them here to connect with.',
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      itemCount: _people.length,
      itemBuilder: (context, i) {
        final p = _people[i];
        final name = p.displayName ?? p.username ?? 'User';
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: _ExplorePeopleRow(
            name: name,
            avatarUrl: p.avatarUrl,
            onAdd: () => _followUser(p.id),
            onRow: () => Navigator.pushNamed(
              context,
              '/profile/other-user',
              arguments: OtherUserProfileArgs(userId: p.id),
            ),
          ),
        );
      },
    );
  }
}

class _ExploreHashtagsBody extends StatefulWidget {
  @override
  State<_ExploreHashtagsBody> createState() => _ExploreHashtagsBodyState();
}

class _ExploreHashtagsBodyState extends State<_ExploreHashtagsBody> {
  final _repo = HashtagsRepository();
  List<HashtagItem> _trending = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await _repo.trending(limit: 12);
      if (!mounted) return;
      setState(() {
        _trending = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Trending', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _black)),
                ),
                TextButton(onPressed: () => Navigator.pushNamed(context, '/social/hashtags'), child: const Text('See all')),
              ],
            ),
          ),
        ),
        if (_loading)
          const SliverFillRemaining(hasScrollBody: false, child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
        else if (_trending.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: _ExploreEmptyState(
              icon: Icons.tag_rounded,
              title: 'No trending topics',
              subtitle: 'Trending topics from across Xlive will appear here as conversations heat up.',
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.4),
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final tag = _trending[i];
                  return Material(
                    color: _searchFill,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => Navigator.pushNamed(context, '/social/hashtag-feed', arguments: HashtagFeedArgs(tag: tag.tag)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('#${tag.tag}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, color: _black)),
                            Text('${tag.postCount} posts', style: const TextStyle(fontSize: 12, color: _sectionMuted)),
                          ],
                        ),
                      ),
                    ),
                  );
                },
                childCount: _trending.length,
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }
}

class _SuggestionCarouselSection extends StatelessWidget {
  const _SuggestionCarouselSection({required this.label, required this.entries});

  final String label;
  final List<_LiveCardData> entries;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _sectionMuted)),
        ),
        SizedBox(
          height: 172,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final s = entries[i];
              return SizedBox(
                width: 108,
                child: ExploreStreamCard(
                  name: s.name,
                  imageUrl: s.imageUrl,
                  viewers: s.viewers,
                  points: s.points,
                  gradientOnly: s.gradientOnly,
                  compact: true,
                  showNewBadge: false,
                  showViewers: s.isLiveStream,
                  onTap: () => _openExploreMedia(context, s, siblings: entries),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ExplorePeopleRow extends StatelessWidget {
  const _ExplorePeopleRow({required this.name, required this.avatarUrl, required this.onAdd, required this.onRow});

  final String name;
  final String? avatarUrl;
  final VoidCallback onAdd;
  final VoidCallback onRow;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onRow,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              UserAvatar(radius: 28, imageUrl: avatarUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onAdd,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [_followGradStart, _followGradEnd],
                    ),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExploreStreamCard extends StatelessWidget {
  const ExploreStreamCard({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.viewers,
    required this.points,
    required this.onTap,
    this.frosted = false,
    this.gradientOnly = false,
    this.compact = false,
    this.showNewBadge = false,
    this.showViewers = true,
  });

  final String name;
  final String? imageUrl;
  final int viewers;
  final int points;
  final VoidCallback onTap;
  final bool frosted;
  final bool gradientOnly;
  final bool compact;
  final bool showNewBadge;
  final bool showViewers;

  bool get _useGradient => gradientOnly || imageUrl == null || imageUrl!.isEmpty;

  @override
  Widget build(BuildContext context) {
    const r = 12.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(r),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(r),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_useGradient)
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFFF8A5B), Color(0xFF2EC4B6)]),
                  ),
                )
              else
                Image.network(imageUrl!, fit: BoxFit.cover),
              if (frosted && !_useGradient)
                ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(color: Colors.white.withValues(alpha: 0.22)),
                  ),
                ),
              Container(color: Colors.black.withValues(alpha: 0.12)),
              if (showViewers || showNewBadge)
                Positioned(
                  top: compact ? 6 : 8,
                  left: compact ? 6 : 8,
                  right: compact ? 6 : 8,
                  child: Row(
                    children: [
                      if (showViewers) ...[
                        Icon(Icons.remove_red_eye_outlined, size: compact ? 13 : 14, color: Colors.white),
                        const SizedBox(width: 3),
                        Text('$viewers', style: TextStyle(color: Colors.white, fontSize: compact ? 11 : 12, fontWeight: FontWeight.w600, shadows: const [Shadow(blurRadius: 4, color: Colors.black54)])),
                      ],
                      const Spacer(),
                      if (showNewBadge)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF8A2DDC), Color(0xFF35D3FB)]),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text('New', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(compact ? 8 : 10, 20, compact ? 8 : 10, compact ? 8 : 10),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Color(0xE6000000), Color(0x00000000)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: compact ? 12 : 13,
                          shadows: const [Shadow(blurRadius: 6, color: Colors.black87)],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.diamond_outlined, size: compact ? 10 : 11, color: Colors.white),
                          const SizedBox(width: 2),
                          Text(
                            '$points',
                            style: TextStyle(color: Colors.white, fontSize: compact ? 10 : 11, fontWeight: FontWeight.w500, shadows: const [Shadow(blurRadius: 4, color: Colors.black54)]),
                          ),
                        ],
                      ),
                    ],
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

class ExploreSearchScreen extends StatefulWidget {
  const ExploreSearchScreen({super.key});

  @override
  State<ExploreSearchScreen> createState() => _ExploreSearchScreenState();
}

class _ExploreSearchScreenState extends State<ExploreSearchScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _exploreRepo = ExploreRepository();
  ExploreSearchResult _results = const ExploreSearchResult();
  List<String> _recent = const [];
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    await ExploreRecentSearches.instance.ensureLoaded();
    if (!mounted) return;
    setState(() => _recent = ExploreRecentSearches.instance.items);
  }

  Future<void> _remember(String q) async {
    await ExploreRecentSearches.instance.push(q);
    if (!mounted) return;
    setState(() => _recent = ExploreRecentSearches.instance.items);
  }

  @override
  void dispose() {
    _controller.removeListener(_onQueryChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _onQueryChanged() async {
    final q = _controller.text.trim();
    if (q.length < 2) {
      setState(() {
        _results = const ExploreSearchResult();
        _searching = false;
      });
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await _exploreRepo.search(q, limit: 12);
      if (!mounted) return;
      setState(() {
        _results = results;
        _searching = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  bool get _hasResults => !_results.isEmpty;

  void _openVideoOrClip(ExploreSearchHit hit) {
    _remember(_controller.text.trim());
    Navigator.pushNamed(
      context,
      '/media/preview',
      arguments: VideoClipPreviewArgs(
        targetType: hit.kind == 'clip' ? 'clip' : 'video',
        targetId: hit.id,
        title: hit.title,
        thumbnailUrl: hit.thumbnailUrl,
        creatorId: hit.creatorId,
        creatorName: hit.creatorName,
        isImage: hit.isImage,
      ),
    );
  }

  void _openStream(ExploreSearchHit hit) {
    _remember(_controller.text.trim());
    final isHost = hit.creatorId != null &&
        hit.creatorId == AuthSession.instance.user?.id;
    Navigator.pushNamed(
      context,
      '/live/during',
      arguments: LiveDuringArgs(streamId: hit.id, isHost: isHost),
    );
  }

  void _openGroup(GroupSummary group) {
    _remember(_controller.text.trim());
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          groupId: group.id,
          groupName: group.name,
          avatarUrl: group.iconUrl ?? '',
        ),
      ),
    );
  }

  Widget _sectionTitle(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black)),
    );
  }

  Widget _mediaTile(ExploreSearchHit hit, {required VoidCallback onTap}) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: 48,
          height: 48,
          child: hit.thumbnailUrl == null || hit.thumbnailUrl!.isEmpty
              ? ColoredBox(color: Colors.grey.shade200, child: const Icon(Icons.play_circle_outline_rounded))
              : Image.network(hit.thumbnailUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => ColoredBox(color: Colors.grey.shade200, child: const Icon(Icons.broken_image_outlined))),
        ),
      ),
      title: Text(hit.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: hit.subtitle == null ? null : Text(hit.subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: hit.isLive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.red.shade600, borderRadius: BorderRadius.circular(999)),
              child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
            )
          : null,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasText = _controller.text.trim().length >= 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        elevation: 0,
        backgroundColor: Colors.white,
        toolbarHeight: 52,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: _black),
                onPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(color: _searchFill, borderRadius: BorderRadius.circular(999)),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    cursorColor: _black,
                    style: const TextStyle(fontSize: 16, color: _black, fontWeight: FontWeight.w400),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Search people, videos, live…',
                      hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: Colors.grey.shade500),
                      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 40),
                      suffixIcon: hasText
                          ? IconButton(
                              icon: Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                              onPressed: () {
                                _controller.clear();
                                setState(() {});
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: hasText
          ? _searching && !_hasResults
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : !_hasResults
                  ? Center(child: Text('No results', style: TextStyle(color: Colors.grey.shade600)))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                      children: [
                        if (_results.users.isNotEmpty) ...[
                          _sectionTitle('People'),
                          ..._results.users.map(
                            (u) => ListTile(
                              leading: UserAvatar(radius: 20, imageUrl: u.avatarUrl),
                              title: Text(u.displayName ?? u.username ?? 'User'),
                              subtitle: u.username == null ? null : Text('@${u.username}'),
                              onTap: () {
                                _remember(_controller.text.trim());
                                Navigator.pushNamed(
                                  context,
                                  '/profile/other-user',
                                  arguments: OtherUserProfileArgs(userId: u.id),
                                );
                              },
                            ),
                          ),
                        ],
                        if (_results.videos.isNotEmpty) ...[
                          _sectionTitle('Videos'),
                          ..._results.videos.map((h) => _mediaTile(h, onTap: () => _openVideoOrClip(h))),
                        ],
                        if (_results.clips.isNotEmpty) ...[
                          _sectionTitle('Clips'),
                          ..._results.clips.map((h) => _mediaTile(h, onTap: () => _openVideoOrClip(h))),
                        ],
                        if (_results.streams.isNotEmpty) ...[
                          _sectionTitle('Live'),
                          ..._results.streams.map((h) => _mediaTile(h, onTap: () => _openStream(h))),
                        ],
                        if (_results.hashtags.isNotEmpty) ...[
                          _sectionTitle('Tags'),
                          ..._results.hashtags.map(
                            (tag) => ListTile(
                              leading: const Icon(Icons.tag_rounded),
                              title: Text('#${tag.tag}'),
                              subtitle: Text('${tag.postCount} posts'),
                              onTap: () {
                                _remember('#${tag.tag}');
                                Navigator.pushNamed(context, '/social/hashtag-feed', arguments: HashtagFeedArgs(tag: tag.tag));
                              },
                            ),
                          ),
                        ],
                        if (_results.groups.isNotEmpty) ...[
                          _sectionTitle('Groups'),
                          ..._results.groups.map(
                            (g) => ListTile(
                              leading: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: g.iconUrl == null || g.iconUrl!.isEmpty ? null : NetworkImage(g.iconUrl!),
                                child: g.iconUrl == null || g.iconUrl!.isEmpty ? const Icon(Icons.group_rounded) : null,
                              ),
                              title: Text(g.name),
                              subtitle: Text('${g.memberCount} members'),
                              onTap: () => _openGroup(g),
                            ),
                          ),
                        ],
                      ],
                    )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const Text('Recent Searches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                const SizedBox(height: 12),
                if (_recent.isEmpty)
                  Text('No recent searches', style: TextStyle(color: Colors.grey.shade600))
                else
                  ..._recent.map(
                    (q) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 4),
                      leading: Icon(Icons.history_rounded, size: 22, color: Colors.grey.shade600),
                      title: Text(q, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _black)),
                      trailing: IconButton(
                        icon: Icon(Icons.close_rounded, size: 18, color: Colors.grey.shade500),
                        onPressed: () async {
                          await ExploreRecentSearches.instance.remove(q);
                          if (!mounted) return;
                          setState(() => _recent = ExploreRecentSearches.instance.items);
                        },
                      ),
                      onTap: () {
                        _controller.text = q;
                        setState(() {});
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
