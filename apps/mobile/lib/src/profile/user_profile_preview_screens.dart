import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/media/media_url_cache.dart';
import '../../core/network/api_exception.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../../core/share/share_links.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/feed/feed_album.dart';
import '../../features/social/models/social_models.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/social/social_repository.dart';
import '../../features/subscriptions/models/subscription_models.dart';
import '../../features/subscriptions/subscriptions_repository.dart';
import '../../core/subscriptions/subscription_store.dart';
import '../../features/users/users_repository.dart';
import '../app_bottom_nav.dart';
import '../social/social_api_screens.dart';
import '../feed/video_preview_comment_screens.dart';
import '../wallet/plan_clip_wallet_screens.dart';
import 'profile_screens.dart';
import 'report_profile_sheet.dart';

const _black = Color(0xFF0A0A0A);
const _greyLabel = Color(0xFF8E8E93);
const _btnGrey = Color(0xFFF2F2F2);
const _purpleFollow = Color(0xFF8A3FFC);
const _privatePurple = Color(0xFF9227D8);

const _kThumbAlt = 'https://images.unsplash.com/photo-1492691527719-9d1e07e534b4?w=400&q=80';

class OtherUserProfileArgs {
  const OtherUserProfileArgs({
    required this.userId,
    this.isOwnProfile = false,
    this.isRootTab = false,
  });

  final String userId;
  final bool isOwnProfile;
  final bool isRootTab;
}

class OtherUserProfileScreen extends StatefulWidget {
  const OtherUserProfileScreen({super.key, required this.args});

  final OtherUserProfileArgs args;

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  final _social = SocialRepository();
  final _subscriptions = SubscriptionsRepository();
  final _settings = SettingsRepository();
  int _tab = 0;
  bool _isLiveNow = false;
  int _clipsStat = 0;
  UserPublicProfile? _profile;
  List<ContentItem> _content = const [];
  final Set<String> _removedContentIds = <String>{};
  bool _loadingProfile = false;
  bool _loadingContent = false;
  String? _profileError;
  bool _followBusy = false;
  bool _subscribeBusy = false;
  bool _isSubscribed = false;
  CreatorSubscriptionPlan? _subscriptionPlan;
  bool _isBlocked = false;

  bool get _ownProfile => widget.args.isOwnProfile;
  bool get _rootTab => widget.args.isRootTab;
  bool get _hasSubscribablePlan => _subscriptionPlan?.hasSubscribablePlan ?? false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadContent();
    _loadSubscriptionStatus();
    _loadCreatorPlan();
    _loadBlockStatus();
  }

  Future<void> _loadProfile() async {
    final userId = widget.args.userId;
    setState(() {
      _loadingProfile = true;
      _profileError = null;
    });
    try {
      final profile = await _social.getProfile(userId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLiveNow = profile.isLive;
        _clipsStat = profile.clipsCount;
        _loadingProfile = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProfile = false;
        _profileError = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    final userId = widget.args.userId;
    if (!AuthSession.instance.isSignedIn) return;
    try {
      final subs = await _subscriptions.listMine(limit: 50);
      if (!mounted) return;
      setState(() => _isSubscribed = subs.any((s) => s.creatorId == userId) || SubscriptionStore.instance.isSubscribedTo(userId));
    } catch (_) {
      if (mounted) {
        setState(() => _isSubscribed = SubscriptionStore.instance.isSubscribedTo(userId));
      }
    }
  }

  Future<void> _loadCreatorPlan() async {
    final userId = widget.args.userId;
    if (_ownProfile) return;
    try {
      final plan = await _subscriptions.getPlan(userId);
      if (!mounted) return;
      setState(() => _subscriptionPlan = plan);
    } catch (_) {
      if (!mounted) return;
      setState(() => _subscriptionPlan = null);
    }
  }

  Future<void> _loadBlockStatus() async {
    final userId = widget.args.userId;
    if (_ownProfile) return;
    try {
      final blocked = await _settings.isUserBlocked(userId);
      if (!mounted) return;
      setState(() => _isBlocked = blocked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isBlocked = false);
    }
  }

  String _subscribeErrorMessage(Object e) {
    if (e is ApiException && (e.statusCode == 400 || e.statusCode == 404)) {
      final msg = _exceptionText(e);
      if (msg.contains('plan') || msg.contains('subscription') || msg.contains('not found') || msg.contains('statuscode')) {
        return 'This creator has not set up a subscription plan yet.';
      }
    }
    return friendlyApiMessage(e, fallback: 'Could not update subscription. Please try again.');
  }

  String _exceptionText(Object e) {
    if (e is ApiException) {
      return '${e.message} ${e.details}'.toLowerCase();
    }
    return e.toString().toLowerCase();
  }

  Future<void> _toggleSubscribe() async {
    final userId = widget.args.userId;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to subscribe.')));
      return;
    }
    final wasSubscribed = _isSubscribed;
    if (!wasSubscribed && !_hasSubscribablePlan) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This creator has not set up a subscription plan yet.')),
      );
      return;
    }
    setState(() {
      _subscribeBusy = true;
      _isSubscribed = !wasSubscribed;
    });
    try {
      if (wasSubscribed) {
        await _subscriptions.cancel(userId);
        SubscriptionStore.instance.removeSubscribedCreator(userId);
      } else {
        await _subscriptions.subscribe(userId);
        SubscriptionStore.instance.addSubscribedCreator(userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSubscribed = wasSubscribed);
      if (wasSubscribed) {
        SubscriptionStore.instance.addSubscribedCreator(userId);
      } else {
        SubscriptionStore.instance.removeSubscribedCreator(userId);
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_subscribeErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _subscribeBusy = false);
    }
  }

  Future<void> _loadContent() async {
    final userId = widget.args.userId;
    setState(() => _loadingContent = true);
    try {
      List<ContentItem> content;
      if (_tab == 4) {
        content = await _social.getUserCollection(userId);
      } else {
        final tab = switch (_tab) {
          1 => 'videos',
          2 => 'clips',
          3 => 'photos',
          _ => 'all',
        };
        content = await _social.getUserContent(userId, tab: tab);
      }
      if (!mounted) return;
      final visible = content.where((c) => !_removedContentIds.contains(c.id)).toList();
      _removedContentIds.removeWhere((id) => !content.any((c) => c.id == id));
      setState(() {
        _content = coalesceContentAlbums(visible);
        _loadingContent = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _content = const [];
        _loadingContent = false;
      });
    }
  }

  void _removeContentLocally(ContentItem item) {
    _removedContentIds.add(item.id);
    setState(() {
      _content = _content.where((c) => c.id != item.id).toList();
      if (item.targetType == 'clip') {
        _clipsStat = (_clipsStat - 1).clamp(0, 1 << 30);
      }
    });
  }

  Future<void> _toggleFollow() async {
    final userId = widget.args.userId;
    if (_profile == null) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to follow users.')));
      return;
    }
    final wasFollowing = _profile!.isFollowing;
    setState(() {
      _followBusy = true;
      _profile = UserPublicProfile(
        id: _profile!.id,
        username: _profile!.username,
        displayName: _profile!.displayName,
        bio: _profile!.bio,
        avatarUrl: _profile!.avatarUrl,
        followersCount: _profile!.followersCount + (wasFollowing ? -1 : 1),
        followingCount: _profile!.followingCount,
        clipsCount: _profile!.clipsCount,
        earnedPoints: _profile!.earnedPoints,
        isLive: _profile!.isLive,
        isFollowing: !wasFollowing,
      );
    });
    try {
      if (wasFollowing) {
        await _social.unfollow(userId);
      } else {
        await _social.follow(userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profile = UserPublicProfile(
          id: _profile!.id,
          username: _profile!.username,
          displayName: _profile!.displayName,
          bio: _profile!.bio,
          avatarUrl: _profile!.avatarUrl,
          followersCount: _profile!.followersCount + (wasFollowing ? 1 : -1),
          followingCount: _profile!.followingCount,
          clipsCount: _profile!.clipsCount,
          earnedPoints: _profile!.earnedPoints,
          isLive: _profile!.isLive,
          isFollowing: wasFollowing,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  void _onTabSelected(int tab) {
    setState(() => _tab = tab);
    _loadContent();
  }

  Future<void> _onRefresh() async {
    _removedContentIds.clear();
    await Future.wait([
      _loadProfile(),
      _loadContent(),
    ]);
  }

  void _onMoreSelected(String? v) {
    if (!mounted || v == null) return;
    if (v == 'share') {
      final name = _profile?.name.trim();
      final handle = _profile?.username?.trim();
      final label = (name != null && name.isNotEmpty)
          ? name
          : (handle != null && handle.isNotEmpty ? '@$handle' : 'this creator');
      Share.share('Check out $label on Xlive\n${profileShareUrl(widget.args.userId)}');
    } else if (v == 'report') {
      showReportProfileSheet(
        context,
        reportedUserId: widget.args.userId,
        reportedHandle: _profile?.handle ?? _profile?.username ?? '@user',
        reportedName: _profile?.name,
      );
    } else if (v == 'block') {
      _showBlockUserSheet();
    } else if (v == 'unblock') {
      _showUnblockUserSheet();
    }
  }

  void _showBlockUserSheet() {
    final displayName = _profile?.name ?? 'this user';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: _btnGrey, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.person_off_outlined, size: 44, color: Colors.grey.shade900),
              ),
              const SizedBox(height: 20),
              const Text('Block User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _black)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Block $displayName? Their streams and clips will be hidden, they will be removed from your chats, and they will not be able to contact you. You can unblock them anytime from this profile or Settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.45),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final userId = widget.args.userId;
                      Navigator.pop(ctx);
                      if (userId.isEmpty) return;
                      try {
                        await _settings.blockUser(userId);
                        if (!mounted) return;
                        setState(() => _isBlocked = true);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User blocked')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyApiMessage(e, fallback: 'Could not block this user.'))),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Block', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showUnblockUserSheet() {
    final displayName = _profile?.name ?? 'this user';
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: _btnGrey, borderRadius: BorderRadius.circular(20)),
                child: Icon(Icons.person_outline_rounded, size: 44, color: Colors.grey.shade900),
              ),
              const SizedBox(height: 20),
              const Text('Unblock User', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _black)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Text(
                  'Unblock $displayName? They will be able to contact you again and their content may appear in your feed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 15, color: Colors.grey.shade700, height: 1.45),
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final userId = widget.args.userId;
                      Navigator.pop(ctx);
                      if (userId.isEmpty) return;
                      try {
                        await _settings.unblockUser(userId);
                        if (!mounted) return;
                        setState(() => _isBlocked = false);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User unblocked')));
                      } catch (e) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyApiMessage(e, fallback: 'Could not unblock this user.'))),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _purpleFollow,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Unblock', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrivateLiveStreamSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(ctx).bottom),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              const Text(
                'Private Live Stream',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black),
              ),
              const SizedBox(height: 24),
              UserAvatar(radius: 44, imageUrl: _profile?.avatarUrl),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: _btnGrey, borderRadius: BorderRadius.circular(999)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Private Stream', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black)),
                    const SizedBox(width: 8),
                    _goldCoin(20),
                    const SizedBox(width: 6),
                    const Text('400 coins', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: FilledButton.styleFrom(
                      backgroundColor: _privatePurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Send Request', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _black,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Close', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openClipPreview(ContentItem item) async {
    if (item.type == FeedContentType.stream) return;
    final playable = _content.where((e) => e.type != FeedContentType.stream).toList();
    var index = playable.indexWhere((e) => e.id == item.id);
    final seed = List<ContentItem>.from(playable);
    if (index < 0) {
      seed.insert(0, item);
      index = 0;
    }
    VideoClipPreviewArgs toArgs(ContentItem c) => VideoClipPreviewArgs(
          targetType: c.targetType,
          targetId: c.id,
          title: c.title,
          thumbnailUrl: c.thumbnailUrl,
          creatorId: c.creatorId ?? widget.args.userId,
          creatorName: c.creatorName ?? _profile?.name,
          likeCount: c.likeCount,
          viewCount: c.viewCount,
          commentCount: c.commentCount,
          isImage: c.isImage,
          mediaUrl: c.isLocked
              ? null
              : MediaUrlCache.resolved(
                  c.targetType,
                  c.id,
                  resourceType: c.isImage ? 'image' : null,
                ),
          locked: c.isLocked,
        );
    final result = await Navigator.pushNamed(
      context,
      '/media/preview',
      arguments: FeedReelViewerArgs(
        items: seed.map(toArgs).toList(),
        initialIndex: index,
      ),
    );
    if (!mounted) return;
    if (result == true) {
      _removeContentLocally(item);
      _loadProfile();
    }
    _loadContent();
  }

  Widget _goldCoin(double s) {
    return Container(
      width: s,
      height: s,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
      child: Icon(Icons.star_rounded, color: Colors.white, size: s * 0.55),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = _profile;
    final handle = profile?.handle ?? '@user';
    final bio = profile?.bio ?? '';
    final avatarUrl = profile?.avatarUrl;
    final followingLabel = ApiJson.formatCount(profile?.followingCount ?? 0);
    final followersLabel = ApiJson.formatCount(profile?.followersCount ?? 0);
    final clipsLabel = '${profile?.clipsCount ?? 0}';
    final isFollowing = profile?.isFollowing ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !_rootTab,
        leading: _rootTab
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
        centerTitle: true,
        title: Text(handle, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
        actions: [
          if (_ownProfile) ...[
            IconButton(
              icon: const Icon(Icons.workspace_premium_rounded, color: _black),
              tooltip: 'Subscription',
              onPressed: () => Navigator.pushNamed(context, '/profile/creator/subscription-plan'),
            ),
            IconButton(
              icon: const Icon(Icons.mode_edit_outline_rounded, color: _black),
              tooltip: 'Edit profile',
              onPressed: () async {
                await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()));
                if (!mounted) return;
                await AuthSession.instance.refreshProfile();
                _loadProfile();
                _loadContent();
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: _black),
              tooltip: 'Settings',
              onPressed: () => Navigator.pushNamed(context, '/profile/settings'),
            ),
          ],
          if (!_ownProfile)
            PopupMenuButton<String>(
            offset: const Offset(0, 48),
            icon: const Icon(Icons.more_vert_rounded, color: _black),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade300)),
            color: Colors.white,
            onSelected: _onMoreSelected,
            itemBuilder: (c) => [
              PopupMenuItem<String>(
                value: 'share',
                child: Row(
                  children: [
                    Icon(Icons.ios_share_rounded, color: Colors.grey.shade800, size: 22),
                    const SizedBox(width: 12),
                    const Text('Share Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag_outlined, color: Colors.grey.shade800, size: 22),
                    const SizedBox(width: 12),
                    const Text('Report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                  ],
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: _isBlocked ? 'unblock' : 'block',
                child: Row(
                  children: [
                    Icon(
                      _isBlocked ? Icons.person_outline_rounded : Icons.block_rounded,
                      color: Colors.grey.shade800,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isBlocked ? 'Unblock User' : 'Block User',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      bottomNavigationBar: _rootTab ? const MainBottomNav(selected: MainNavItem.profile) : null,
      body: _loadingProfile
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _profileError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_profileError!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        TextButton(onPressed: _loadProfile, child: const Text('Retry')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  UserAvatar(radius: 52, imageUrl: avatarUrl, isLive: _isLiveNow),
                  const SizedBox(height: 14),
                  Text(handle, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _black)),
                  const SizedBox(height: 4),
                  if (bio.isNotEmpty) Text(bio, style: const TextStyle(fontSize: 15, color: _greyLabel)),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/social/follow-list',
                            arguments: FollowListArgs(userId: widget.args.userId, followers: false),
                          ),
                          child: _statCol(followingLabel, 'Following'),
                        ),
                      ),
                      Container(width: 1, height: 44, color: Colors.grey.shade300),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/social/follow-list',
                            arguments: FollowListArgs(userId: widget.args.userId, followers: true),
                          ),
                          child: _statCol(followersLabel, 'Followers'),
                        ),
                      ),
                      Container(width: 1, height: 44, color: Colors.grey.shade300),
                      Expanded(child: _statCol(clipsLabel, 'Clips')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_ownProfile)
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () async {
                              final published = await Navigator.pushNamed(context, '/profile/creator/create-clip');
                              if (!mounted) return;
                              if (published == true) {
                                await _loadProfile();
                                await _loadContent();
                              }
                            },
                            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
                            label: const Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            style: FilledButton.styleFrom(
                              backgroundColor: _purpleFollow,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pushNamed(context, '/profile/creator/tools'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            ),
                            child: const Text('Creator Tools', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _squareGreyBtn(Icons.videocam_outlined, () => Navigator.pushNamed(context, '/live/setup')),
                      ],
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: SizedBox(
                            height: 48,
                            child: FilledButton.icon(
                              onPressed: _followBusy ? null : _toggleFollow,
                              icon: Icon(isFollowing ? Icons.check_rounded : Icons.add_rounded, color: Colors.white, size: 22),
                              label: Text(
                                isFollowing ? 'Following' : 'Follow',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: _purpleFollow,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (_hasSubscribablePlan || _isSubscribed)
                          Expanded(
                            flex: 2,
                            child: SizedBox(
                              height: 48,
                              child: OutlinedButton(
                                onPressed: _subscribeBusy ? null : _toggleSubscribe,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _purpleFollow,
                                  side: BorderSide(
                                    color: _isSubscribed ? _purpleFollow : Colors.grey.shade300,
                                    width: _isSubscribed ? 1.5 : 1,
                                  ),
                                  backgroundColor: _isSubscribed ? _purpleFollow.withValues(alpha: 0.08) : Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                                ),
                                child: _isSubscribed
                                    ? const Text(
                                        'Subscribed',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      )
                                    : Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                            'Subscribe',
                                            maxLines: 1,
                                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, height: 1.1),
                                          ),
                                          if (_hasSubscribablePlan) ...[
                                            const SizedBox(height: 2),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                _goldCoin(12),
                                                const SizedBox(width: 3),
                                                Flexible(
                                                  child: Text(
                                                    '${_subscriptionPlan!.monthlyPrice}/mo',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 11,
                                                      height: 1.1,
                                                      color: Colors.grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        if (_hasSubscribablePlan || _isSubscribed) const SizedBox(width: 10),
                        _squareGreyBtn(Icons.person_add_alt_1_outlined, _showPrivateLiveStreamSheet),
                        const SizedBox(width: 10),
                        _squareGreyBtn(Icons.storefront_outlined, () {
                          showModalBottomSheet<void>(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => CreatorStoreComboSheet(creatorId: widget.args.userId),
                          );
                        }),
                      ],
                    ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _mainTab(0, Icons.grid_view_rounded, 'All'),
                      _mainTab(1, Icons.movie_filter_outlined, 'Videos'),
                      _mainTabClips(),
                      _mainTab(3, Icons.photo_outlined, 'Photos'),
                      _mainTab(4, Icons.collections_outlined, 'Collection'),
                    ],
                  ),
                  Container(height: 1, color: Colors.grey.shade200),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(12, 0, 12, 24 + MediaQuery.paddingOf(context).bottom),
            sliver: _buildContentSliver(),
          ),
        ],
      ),
              ),
    );
  }

  Widget _statCol(String val, String sub, {Widget? leading}) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[leading, const SizedBox(width: 4)],
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black)),
          ],
        ),
        const SizedBox(height: 4),
        Text(sub, style: const TextStyle(fontSize: 12, color: _greyLabel)),
      ],
    );
  }

  Widget _squareGreyBtn(IconData icon, VoidCallback onTap) {
    return Material(
      color: _btnGrey,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(width: 48, height: 48, child: Icon(icon, color: _black)),
      ),
    );
  }

  Widget _mainTab(int i, IconData icon, String label) {
    final on = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(i),
        child: Column(
          children: [
            Icon(icon, size: 22, color: on ? _black : _greyLabel),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? _black : _greyLabel)),
            const SizedBox(height: 8),
            Container(
              height: 3,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: on ? _black : Colors.transparent, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mainTabClips() {
    const i = 2;
    final on = _tab == i;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabSelected(i),
        child: Column(
          children: [
            SizedBox(height: 22, child: _clipsHeartIcon(on)),
            const SizedBox(height: 6),
            Text('Clips', style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w500, color: on ? _black : _greyLabel)),
            const SizedBox(height: 8),
            Container(
              height: 3,
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(color: on ? _black : Colors.transparent, borderRadius: BorderRadius.circular(2)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _clipsHeartIcon(bool on) {
    final c = on ? _black : _greyLabel;
    return Stack(
      alignment: Alignment.center,
      children: [
        Icon(Icons.favorite_border_rounded, size: 22, color: c),
        Icon(Icons.play_arrow_rounded, size: 15, color: c),
      ],
    );
  }

  Widget _buildContentSliver() {
    if (_loadingContent) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_content.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.movie_creation_outlined, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              switch (_tab) {
                1 => 'No post yet',
                2 => 'No clips yet',
                3 => 'No photos yet',
                4 => 'No collection items yet',
                _ => 'No content yet',
              },
              style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 40),
          ],
        ),
      );
    }
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4, childAspectRatio: 0.68),
      delegate: SliverChildBuilderDelegate(
        (_, i) => _apiContentCell(_content[i]),
        childCount: _content.length,
      ),
    );
  }

  Widget _apiContentCell(ContentItem item) {
    final image = item.thumbnailUrl ?? _kThumbAlt;
    return GestureDetector(
      onTap: item.type == FeedContentType.stream ? null : () => _openClipPreview(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(image, fit: BoxFit.cover),
            if (item.isLocked)
              Positioned.fill(
                child: Container(
                  color: Colors.black38,
                  alignment: Alignment.center,
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 28),
                ),
              ),
            if (item.isAlbum)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.collections_rounded, color: Colors.white, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
