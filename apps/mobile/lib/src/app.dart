import 'dart:async';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../core/navigation/app_navigator.dart';
import '../core/media/media_url_cache.dart';
import '../core/socket/xlive_socket_client.dart';
import '../core/session/auth_session.dart';
import '../core/widgets/user_avatar.dart';
import '../core/feed/home_feed_refresh.dart';
import '../core/live/live_now_store.dart';
import '../features/feed/feed_album.dart';
import '../features/feed/feed_repository.dart';
import '../features/feed/models/feed_models.dart';
import '../features/users/models/user_models.dart';
import '../features/users/users_repository.dart';
import 'auth/account_role.dart';
import 'auth/create_account_screen.dart';
import 'auth/dark_onboarding_screen.dart';
import 'auth/forgot_password_screen.dart';
import 'auth/sign_in_screen.dart';
import 'app_bottom_nav.dart';
import 'profile/profile_preferences_screens.dart';
import 'profile/profile_screens.dart';
import 'profile/profile_security_screens.dart';
import 'profile/creator_earnings_screens.dart';
import 'profile/creator_tools_screens.dart';
import 'profile/gifts_screen.dart';
import 'profile/saved_media_screen.dart';
import '../core/media/saved_media_store.dart';
import 'profile/creator_profile_market_screens.dart';
import 'profile/create_content_screen.dart';
import 'profile/created_clips_screens.dart';
import 'profile/edit_clip_screens.dart';
import 'profile/user_profile_preview_screens.dart';
import 'feed/video_preview_comment_screens.dart';
import 'feed/feed_reel_viewer_screen.dart';
import 'feed/instagram_feed_post.dart';
import 'wallet/plan_clip_wallet_screens.dart';
import 'live/live_stream_flow.dart';
import 'live/stream_replays_screens.dart';
import 'legal/legal_report_screens.dart';
import 'chats/chats_hub_screen.dart';
import 'section/explore_menu_screens.dart';
import 'social/social_api_screens.dart';
import '../features/social/social_repository.dart';
import 'integration/call_screens.dart';
import 'integration/category_feed_screen.dart';
import 'integration/clip_marketplace_screen.dart';
import 'integration/creator_subscription_plan_screen.dart';
import 'integration/insights_screens.dart';
import 'integration/push_inbox_screen.dart';
import 'integration/stream_invite_toast.dart';
import '../core/network/api_friendly_messages.dart';

class XLiveApp extends StatelessWidget {
  const XLiveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSession.instance,
      builder: (context, _) {
        return MaterialApp(
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [appRouteObserver],
          title: 'Xlive',
          debugShowCheckedModeBanner: false,
          supportedLocales: const [Locale('en')],
          localizationsDelegates: const [
            CountryLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFFFFFFF),
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8A2DDC)),
            fontFamily: 'SF Pro Display',
          ),
          builder: (context, child) {
            return StreamInviteToastHost(
              child: IncomingCallOverlay(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          initialRoute: '/',
          routes: {
        '/': (_) => const SplashScreen(),
        '/onboarding': (_) => const DarkOnboardingScreen(),
        '/auth/create-account': (_) => const CreateAccountScreen(),
        '/auth/sign-in': (c) {
          ActiveAccountContext.setRole(AccountRole.creator);
          final args = ModalRoute.of(c)?.settings.arguments;
          final initialEmail = args is String ? args : null;
          return SignInScreen(initialEmail: initialEmail);
        },
        '/auth/forgot-password': (_) => const ForgotPasswordScreen(),
        '/home': (_) => const HomeScreen(),
        '/live': (_) => const LiveHubScreen(),
        '/live/setup': (_) => const LiveSetupScreen(),
        '/live/during': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          return LiveDuringScreen(args: a is LiveDuringArgs ? a : null);
        },
        '/live/more': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          return LiveMoreScreen(args: a is LiveDuringArgs ? a : null);
        },
        '/live/summary': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          return LiveSummaryScreen(args: a is LiveSummaryArgs ? a : null);
        },
        '/live/invite': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          return LiveInviteScreen(args: a is LiveInviteArgs ? a : null);
        },
        '/live/replays': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          return StreamReplaysScreen(initialMine: a == true);
        },
        '/live/replay': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          final id = a is String ? a : '';
          if (id.isEmpty) return const SizedBox.shrink();
          return StreamReplayDetailScreen(streamId: id);
        },
        '/live/notifications': (_) => const LiveNotificationsScreen(),
        '/profile/settings': (_) => const ProfileMainScreen(),
        '/profile/me': (_) => const CreatorProfileScreen(isRootTab: true),
        '/profile/notifications': (_) => const ProfileNotificationsSettingsScreen(),
        '/profile/general-preference': (_) => const GeneralPreferenceScreen(),
        '/profile/content-preferences': (_) => const ContentPreferencesScreen(),
        '/profile/add-keyword': (_) => const AddKeywordScreen(),
        '/profile/security': (_) => const SecuritySettingsScreen(),
        '/profile/reset-password': (_) => const ResetPasswordScreen(),
        '/profile/creator/create-clip': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          final tab = a is int ? a : 0;
          return CreateContentScreen(initialTab: tab);
        },
        '/profile/creator/created-clips': (_) => const CreatorGate(child: MyCreatedClipsScreen()),
        '/profile/creator/created-clips/detail': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          final id = a is String ? a : '';
          if (id.isEmpty) return const SizedBox.shrink();
          return CreatorGate(child: CreatedClipDetailScreen(clipId: id));
        },
        '/profile/creator/edit-clip': (_) => const CreatorGate(child: EditClipMediaPickerScreen()),
        '/profile/creator/profile': (_) => const CreatorGate(child: CreatorProfileScreen()),
        '/profile/gifts': (_) => const MyGiftsScreen(),
        '/profile/saved': (_) => const SavedMediaScreen(),
        '/profile/creator/tools': (_) => const CreatorGate(child: CreatorToolsMenuScreen()),
        '/profile/creator/earnings': (_) => const CreatorGate(child: EarningsWithdrawalScreen()),
        '/profile/creator/analytics': (_) => const CreatorGate(child: PerformanceAnalyticsScreen()),
        '/profile/creator/private-live': (_) => const CreatorGate(child: PrivateLiveStreamScreen()),
        '/profile/creator/clip-archive': (_) => const CreatorGate(child: ClipArchiveScreen()),
        '/profile/creator/subscription': (_) => const CreatorGate(child: MySubscriptionScreen()),
        '/legal/report-issue': (_) => const ReportIssueScreen(),
        '/media/preview': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          if (a is FeedReelViewerArgs) return FeedReelViewerScreen(args: a);
          if (a is! VideoClipPreviewArgs) return const SizedBox.shrink();
          return VideoClipPreviewScreen(args: a);
        },
        '/chats': (_) => const ChatsHubScreen(),
        '/social/follow-list': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          if (a is! FollowListArgs) return const SizedBox.shrink();
          return FollowListScreen(args: a);
        },
        '/social/blocked': (_) => const BlockedUsersScreen(),
        '/social/stream-invites': (_) => const StreamInvitesScreen(),
        '/social/hashtags': (_) => const HashtagDiscoverScreen(),
        '/social/hashtag-feed': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          if (a is! HashtagFeedArgs) return const SizedBox.shrink();
          return HashtagFeedScreen(args: a);
        },
        '/groups/join-code': (_) => const GroupJoinCodeScreen(),
        '/groups/members': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          if (a is! GroupMembersArgs) return const SizedBox.shrink();
          return GroupMembersScreen(args: a);
        },
        '/explore': (_) => const ExploreMenuScreen(),
        '/profile/other-user': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          if (a is! OtherUserProfileArgs) return const SizedBox.shrink();
          if (a.userId.isEmpty) return const SizedBox.shrink();
          return OtherUserProfileScreen(args: a);
        },
        '/wallet/xlive': (_) => const XliveWalletScreen(),
        '/integration/push-inbox': (_) => const PushInboxScreen(),
        '/integration/clip-marketplace': (_) => const ClipMarketplaceScreen(),
        '/integration/category-feed': (c) {
          final slug = ModalRoute.of(c)?.settings.arguments;
          if (slug is! String || slug.isEmpty) return const SizedBox.shrink();
          return CategoryFeedScreen(categorySlug: slug);
        },
        '/integration/post-insights': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          if (a is! PostInsightsArgs) return const SizedBox.shrink();
          return PostInsightsScreen(targetType: a.targetType, targetId: a.targetId);
        },
        '/profile/creator/subscription-plan': (c) {
          final a = ModalRoute.of(c)?.settings.arguments;
          final creatorId = a is String ? a : AuthSession.instance.user?.id;
          if (creatorId == null || creatorId.isEmpty) return const SizedBox.shrink();
          return CreatorSubscriptionPlanScreen(creatorId: creatorId);
        },
      },
        );
      },
    );
  }
}

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _light = Color(0xFFF6F6F6);
const _homeMuted = Color(0xFF8E8E93);
const _homeGradStart = Color(0xFF66A6FF);
const _homeGradEnd = Color(0xFF896CFE);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      final session = AuthSession.instance;
      if (!session.isLoaded) {
        try {
          await session.load().timeout(const Duration(seconds: 15));
        } catch (_) {}
      }
      if (!mounted) return;
      final route = session.isSignedIn ? '/home' : '/onboarding';
      Navigator.pushReplacementNamed(context, route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              child: Image.asset(
                'assets/app_icon_dark.png',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (rect) => const LinearGradient(colors: [_purple, _sky]).createShader(rect),
              child: const Text('Xlive', style: TextStyle(fontSize: 54, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with RouteAware, WidgetsBindingObserver {
  final _feedRepo = FeedRepository();
  final _usersRepo = UsersRepository();
  final _socialRepo = SocialRepository();
  final _scrollController = ScrollController();
  final _suggestedStore = const FlutterSecureStorage();
  static const _suggestedHideKey = 'xlive_home_suggested_hidden';
  final Map<String, GlobalKey> _feedItemKeys = {};
  StreamSubscription<void>? _homeRefreshSub;
  int _feedTab = 0;
  int _activeFeedIndex = 0;
  bool _feedCovered = false;
  bool _routeCovered = false;
  bool _appInactive = false;
  List<FeedItem> _items = const [];
  List<SuggestedAccount> _suggestedAccounts = const [];
  bool _suggestedHidden = false;
  final Set<String> _followingIds = {};
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  bool get _allowFeedPlayback => !_feedCovered && !_routeCovered && !_appInactive;
  bool get _showSuggested => _feedTab == 0 && !_suggestedHidden && _suggestedAccounts.isNotEmpty;

  void _dismissSuggested() {
    setState(() => _suggestedHidden = true);
    unawaited(_suggestedStore.write(key: _suggestedHideKey, value: '1'));
  }

  Future<void> _loadSuggestedDismissed() async {
    try {
      final value = await _suggestedStore.read(key: _suggestedHideKey);
      if (!mounted) return;
      if (value == '1') setState(() => _suggestedHidden = true);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
    _homeRefreshSub = HomeFeedRefresh.instance.stream.listen((_) {
      if (mounted) {
        _loadFeed();
        _loadSuggestedAccounts();
      }
    });
    unawaited(LiveNowStore.instance.refresh());
    unawaited(_loadSuggestedDismissed());
    _loadFeed();
    _loadSuggestedAccounts();
    if (AuthSession.instance.isSignedIn) {
      AuthSession.instance.refreshWallet();
      AuthSession.instance.refreshUnread();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _homeRefreshSub?.cancel();
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didPushNext() {
    if (_routeCovered) return;
    setState(() => _routeCovered = true);
  }

  @override
  void didPopNext() {
    if (!_routeCovered) return;
    setState(() => _routeCovered = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final inactive = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached;
    if (_appInactive == inactive) return;
    setState(() => _appInactive = inactive);
  }

  static const _feedKeys = ['for-you', 'following', 'live', 'clips'];

  GlobalKey _keyFor(String id) => _feedItemKeys.putIfAbsent(id, GlobalKey.new);

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) {
      _updateActiveIndex();
      return;
    }
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 480) {
      _loadMore();
    }
    _updateActiveIndex();
  }

  void _updateActiveIndex() {
    if (!_scrollController.hasClients || _items.isEmpty || !mounted) return;
    final screenHeight = MediaQuery.sizeOf(context).height;
    if (screenHeight <= 0) return;
    final focusY = screenHeight * 0.42;
    var bestIndex = _activeFeedIndex.clamp(0, _items.length - 1);
    var bestScore = double.negativeInfinity;

    for (var i = 0; i < _items.length; i++) {
      final ctx = _feedItemKeys[_items[i].id]?.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      final height = box.size.height;
      if (height <= 0) continue;
      final bottom = top + height;
      final visibleTop = top < 0 ? 0.0 : top;
      final visibleBottom = bottom > screenHeight ? screenHeight : bottom;
      final visible = visibleBottom - visibleTop;
      if (visible <= height * 0.2) continue;
      final center = top + height * 0.5;
      final dist = (center - focusY).abs() / screenHeight;
      final visibleRatio = (visible / height).clamp(0.0, 1.0);
      final score = visibleRatio * 2.0 - dist;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    if (bestIndex == _activeFeedIndex) return;
    setState(() => _activeFeedIndex = bestIndex);
    _prefetchAround(bestIndex);
  }

  void _prefetchAround(int index) {
    if (_items.isEmpty) return;
    final start = index.clamp(0, _items.length - 1);
    final end = (index + 3).clamp(0, _items.length);
    if (start >= end) return;
    unawaited(MediaUrlCache.prefetchFeedItems(_items.sublist(start, end)));
  }

  Future<void> _enrichBatch(List<FeedItem> batch) async {
    if (batch.isEmpty) return;
    try {
      final enriched = await _feedRepo.enrichCreators(batch);
      if (!mounted) return;
      final byId = {for (final item in enriched) item.id: item};
      setState(() {
        _items = _items.map((item) => byId[item.id] ?? item).toList();
      });
    } catch (_) {}
  }

  List<FeedItem> _processFeed(List<FeedItem> raw) {
    if (_feedTab == 2) return coalesceFeedAlbums(raw);
    return coalesceFeedAlbums(filterOutSavedLives(raw));
  }

  Future<List<FeedItem>> _fetchPage(int page) async {
    final raw = await switch (_feedTab) {
      0 => _feedRepo.getForYou(page: page),
      1 => _feedRepo.getFollowing(page: page),
      2 => _feedRepo.getLive(page: page),
      _ => _feedRepo.getClips(page: page),
    };
    return _processFeed(raw);
  }

  Future<void> _loadFeed() async {
    final cached = _feedRepo.cachedFirstPage(_feedKeys[_feedTab]);
    if (cached != null) {
      final processed = _processFeed(cached);
      setState(() {
        _items = processed;
        _loading = false;
        _error = null;
        _page = 1;
        _hasMore = cached.length >= 20;
        _activeFeedIndex = 0;
      });
      _prefetchAround(0);
    } else {
      setState(() {
        _items = const [];
        _loading = true;
        _error = null;
        _page = 1;
        _hasMore = true;
        _activeFeedIndex = 0;
      });
    }
    final requestedTab = _feedTab;
    try {
      final items = await _fetchPage(1);
      if (!mounted || requestedTab != _feedTab) return;
      setState(() {
        _items = items;
        _loading = false;
        _error = null;
        _page = 1;
        _hasMore = items.length >= 20;
        _activeFeedIndex = 0;
      });
      _prefetchAround(0);
      unawaited(_enrichBatch(items));
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateActiveIndex();
      });
    } catch (e) {
      if (!mounted || requestedTab != _feedTab) return;
      setState(() {
        if (cached == null) _items = const [];
        _loading = false;
        _error = cached == null ? (friendlyApiMessage(e)) : null;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final requestedTab = _feedTab;
    final next = _page + 1;
    try {
      final items = await _fetchPage(next);
      if (!mounted || requestedTab != _feedTab) return;
      setState(() {
        _items = [..._items, ...items];
        _page = next;
        _hasMore = items.length >= 20;
        _loadingMore = false;
      });
      unawaited(_enrichBatch(items));
      _prefetchAround(_activeFeedIndex);
    } catch (_) {
      if (!mounted || requestedTab != _feedTab) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onFeedTabSelected(int tab) {
    if (_feedTab == tab) return;
    setState(() => _feedTab = tab);
    _loadFeed();
  }

  void _openPreview(FeedItem item) async {
    if (item.type == FeedContentType.stream) {
      setState(() => _feedCovered = true);
      await Navigator.pushNamed(
        context,
        '/live/during',
        arguments: LiveDuringArgs(
          streamId: item.id,
          isHost: item.creatorId != null && item.creatorId == AuthSession.instance.user?.id,
        ),
      );
      if (!mounted) return;
      setState(() => _feedCovered = false);
      if (_feedTab == 2) _loadFeed();
      return;
    }
    setState(() => _feedCovered = true);
    final result = await openFeedReelViewer(
      context,
      items: _items,
      opened: item,
      initialPage: _page,
      loadMoreFeed: (page) async {
        final fetched = await _fetchPage(page);
        if (mounted) {
          final existing = _items.map((e) => e.id).toSet();
          final neu = fetched.where((e) => !existing.contains(e.id)).toList();
          if (neu.isNotEmpty) {
            setState(() {
              _items = [..._items, ...neu];
              _page = page;
              _hasMore = fetched.length >= 20;
            });
            unawaited(_enrichBatch(neu));
          } else {
            setState(() {
              _page = page;
              _hasMore = fetched.length >= 20;
            });
          }
        }
        return fetched;
      },
    );
    if (!mounted) return;
    setState(() => _feedCovered = false);
    if (result != true) return;
    await _loadFeed();
  }

  Future<void> _openCreator(FeedItem item) async {
    var id = item.creatorId?.trim();
    if (id == null || id.isEmpty) {
      try {
        final detail = await SocialRepository().getMediaDetail(
          targetType: item.targetType,
          targetId: item.id,
        );
        id = detail.creatorId?.trim();
      } catch (_) {}
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

  bool _isPlaceholderHandle(String? value) {
    final handle = (value ?? '').replaceAll('@', '').trim().toLowerCase();
    if (handle.length < 2) return true;
    return const {
      'user',
      'creator',
      'unknown',
      'guest',
      'null',
      'undefined',
      'anonymous',
    }.contains(handle);
  }

  Future<void> _loadSuggestedAccounts() async {
    try {
      final selfId = AuthSession.instance.user?.id;
      final found = <XLiveUser>[];
      try {
        final online = await _usersRepo.listOnline(limit: 16);
        found.addAll(online);
      } catch (_) {}
      for (final q in ['a', 'e']) {
        try {
          final hits = await _usersRepo.searchUsers(q, limit: 8);
          for (final u in hits) {
            if (!found.any((x) => x.id == u.id)) found.add(u);
          }
        } catch (_) {}
      }

      final verified = <SuggestedAccount>[];
      for (final u in found) {
        if (u.id.isEmpty || u.id == selfId || u.id.startsWith('suggested_')) continue;
        if (u.isFollowing || _followingIds.contains(u.id)) {
          _followingIds.add(u.id);
          continue;
        }
        try {
          final profile = await _socialRepo.getProfile(u.id);
          if (profile.id.isEmpty) continue;
          final handle = profile.username?.trim();
          final name = profile.name.trim();
          if (_isPlaceholderHandle(handle) && (name.isEmpty || _isPlaceholderHandle(name))) {
            continue;
          }
          verified.add(
            SuggestedAccount(
              id: profile.id,
              username: (handle != null && handle.isNotEmpty && !_isPlaceholderHandle(handle))
                  ? handle
                  : name.toLowerCase().replaceAll(RegExp(r'\s+'), '_'),
              displayName: name.isNotEmpty && !_isPlaceholderHandle(name) ? name : (handle ?? 'Creator'),
              avatarUrl: profile.avatarUrl ?? u.avatarUrl,
              isFollowing: profile.isFollowing,
            ),
          );
        } catch (_) {
          continue;
        }
        if (verified.length >= 12) break;
      }

      if (mounted) {
        setState(() {
          _suggestedAccounts = verified;
        });
      }
    } catch (_) {
      if (mounted && _suggestedAccounts.isEmpty) {
        setState(() {
          _suggestedAccounts = const [];
        });
      }
    }
  }

  Future<void> _toggleFollowAccount(SuggestedAccount account) async {
    final isCurrentlyFollowing = _followingIds.contains(account.id) || account.isFollowing;
    final nextState = !isCurrentlyFollowing;
    if (nextState) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.selectionClick();
    }

    final previousSuggested = List<SuggestedAccount>.from(_suggestedAccounts);

    setState(() {
      if (nextState) {
        _followingIds.add(account.id);
        _suggestedAccounts.removeWhere((a) => a.id == account.id);
      } else {
        _followingIds.remove(account.id);
      }
    });

    try {
      if (nextState) {
        await _socialRepo.follow(account.id);
      } else {
        await _socialRepo.unfollow(account.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (isCurrentlyFollowing) {
          _followingIds.add(account.id);
        } else {
          _followingIds.remove(account.id);
        }
        _suggestedAccounts = previousSuggested;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  void _openSuggestedAccount(SuggestedAccount account) {
    final me = AuthSession.instance.user?.id;
    if (me != null && me == account.id) {
      Navigator.pushNamed(context, '/profile/creator/profile');
      return;
    }
    Navigator.pushNamed(
      context,
      '/profile/other-user',
      arguments: OtherUserProfileArgs(userId: account.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    final avatarUrl = session.user?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pushNamed(context, '/live'),
                    icon: const Icon(Icons.camera_alt_outlined, color: _black, size: 26),
                    tooltip: 'Live and camera',
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/profile/me', (r) => false),
                    child: UserAvatar(radius: 20, imageUrl: avatarUrl),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                    decoration: BoxDecoration(color: _light, borderRadius: BorderRadius.circular(999)),
                    child: Row(
                      children: [
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, '/wallet/xlive'),
                          borderRadius: BorderRadius.circular(999),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(children: [
                              const Icon(Icons.monetization_on_rounded, size: 18, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(
                                '${session.walletBalance ?? '900'}',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ]),
                          ),
                        ),
                        const SizedBox(width: 6),
                        InkWell(
                          onTap: () => Navigator.pushNamed(context, '/wallet/xlive'),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(color: _black, shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.white, size: 15),
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            _HomeFeedTabBar(selected: _feedTab, onSelect: _onFeedTabSelected),
            const SizedBox(height: 4),
            Expanded(
              child: _loading && _items.isEmpty
                  ? Column(
                      children: [
                        if (_showSuggested)
                          _HomeSuggestedAccountsSection(
                            accounts: _suggestedAccounts,
                            followingIds: _followingIds,
                            onToggleFollow: _toggleFollowAccount,
                            onOpenAccount: _openSuggestedAccount,
                            onDismiss: _dismissSuggested,
                          ),
                        const Expanded(
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                      ],
                    )
                  : _error != null && _items.isEmpty
                      ? Column(
                          children: [
                            if (_showSuggested)
                              _HomeSuggestedAccountsSection(
                                accounts: _suggestedAccounts,
                                followingIds: _followingIds,
                                onToggleFollow: _toggleFollowAccount,
                                onOpenAccount: _openSuggestedAccount,
                                onDismiss: _dismissSuggested,
                              ),
                            Expanded(
                              child: _HomeEmptyState(
                                icon: Icons.wifi_off_rounded,
                                title: 'Something went wrong',
                                subtitle: _error!,
                                actionLabel: 'Retry',
                                onAction: _loadFeed,
                              ),
                            ),
                          ],
                        )
                      : _items.isEmpty
                          ? Column(
                              children: [
                                if (_showSuggested)
                                  _HomeSuggestedAccountsSection(
                                    accounts: _suggestedAccounts,
                                    followingIds: _followingIds,
                                    onToggleFollow: _toggleFollowAccount,
                                    onOpenAccount: _openSuggestedAccount,
                                    onDismiss: _dismissSuggested,
                                  ),
                                Expanded(
                                  child: _HomeEmptyState(
                                    icon: switch (_feedTab) {
                                      1 => Icons.people_alt_rounded,
                                      2 => Icons.sensors_rounded,
                                      3 => Icons.movie_creation_rounded,
                                      _ => Icons.auto_awesome_rounded,
                                    },
                                    title: switch (_feedTab) {
                                      1 => 'No posts yet',
                                      2 => 'No live streams',
                                      3 => 'No clips yet',
                                      _ => 'Your feed is empty',
                                    },
                                    subtitle: switch (_feedTab) {
                                      1 => 'Posts from people you follow will show up here.',
                                      2 => 'When creators go live, you will see them here.',
                                      3 => 'New clips will appear here as they are posted.',
                                      _ => 'Follow creators and explore to fill your feed.',
                                    },
                                  ),
                                ),
                              ],
                            )
                          : RefreshIndicator(
                              onRefresh: () async {
                                await Future.wait([
                                  _loadFeed(),
                                  _loadSuggestedAccounts(),
                                ]);
                              },
                              child: ListView.builder(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemCount: (_showSuggested ? 1 : 0) +
                                    _items.length +
                                    (_loadingMore ? 1 : 0),
                                itemBuilder: (_, index) {
                                  final hasSuggested = _showSuggested;
                                  if (hasSuggested && index == 0) {
                                    return _HomeSuggestedAccountsSection(
                                      accounts: _suggestedAccounts,
                                      followingIds: _followingIds,
                                      onToggleFollow: _toggleFollowAccount,
                                      onOpenAccount: _openSuggestedAccount,
                                      onDismiss: _dismissSuggested,
                                    );
                                  }
                                  final postIndex = hasSuggested ? index - 1 : index;
                                  if (postIndex >= _items.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 24),
                                      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                    );
                                  }
                                  final item = _items[postIndex];
                                  return InstagramFeedPost(
                                    key: ValueKey(item.id),
                                    mediaKey: _keyFor(item.id),
                                    item: item,
                                    shouldPlay: _allowFeedPlayback && postIndex == _activeFeedIndex,
                                    onOpenFullscreen: () => _openPreview(item),
                                    onOpenProfile: () => _openCreator(item),
                                    onCommentCountChanged: (count) {
                                      final i = _items.indexWhere((e) => e.id == item.id);
                                      if (i < 0) return;
                                      if (_items[i].commentCount == count) return;
                                      setState(() {
                                        _items = [
                                          for (var j = 0; j < _items.length; j++)
                                            if (j == i) _items[j].copyWith(commentCount: count) else _items[j],
                                        ];
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainBottomNav(selected: MainNavItem.home),
    );
  }
}

class LiveMoreScreen extends StatefulWidget {
  const LiveMoreScreen({super.key, this.args});

  final LiveDuringArgs? args;

  @override
  State<LiveMoreScreen> createState() => _LiveMoreScreenState();
}

class _LiveMoreScreenState extends State<LiveMoreScreen> {
  final List<_StreamViewer> _viewers = [];
  final Set<String> _mutedIds = {};
  final Set<String> _talkBackIds = {};
  StreamSubscription<Map<String, dynamic>>? _viewersSub;

  @override
  void initState() {
    super.initState();
    final streamId = widget.args?.streamId;
    if (streamId != null && streamId.isNotEmpty) {
      XLiveSocketClient.instance.requestStreamViewers(streamId);
      _viewersSub = XLiveSocketClient.instance.onStreamViewers.listen((event) {
        if (event['streamId']?.toString() != streamId) return;
        final raw = event['viewers'] ?? event['users'] ?? event['items'];
        if (raw is! List) return;
        if (!mounted) return;
        setState(() {
          _viewers
            ..clear()
            ..addAll(
              raw.map((item) {
                final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
                final id = map['userId']?.toString() ?? map['id']?.toString() ?? '';
                return _StreamViewer(
                  id: id,
                  name: map['displayName']?.toString() ?? map['username']?.toString() ?? 'Viewer',
                  avatarUrl: map['avatarUrl']?.toString(),
                  muted: map['muted'] == true || map['isMuted'] == true,
                  talkBack: map['talkBack'] == true || map['hasTalkBack'] == true || map['talkBackGranted'] == true,
                );
              }).where((v) => v.id.isNotEmpty),
            );
          for (final v in _viewers) {
            if (v.muted) _mutedIds.add(v.id);
            if (v.talkBack) _talkBackIds.add(v.id);
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _viewersSub?.cancel();
    super.dispose();
  }

  Future<void> _removeViewer(String userId) async {
    final streamId = widget.args?.streamId;
    if (streamId == null || streamId.isEmpty) return;
    final ok = await XLiveSocketClient.instance.removeViewer(streamId: streamId, userId: userId);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Viewer removed' : 'Could not remove viewer')),
    );
    if (ok) setState(() => _viewers.removeWhere((v) => v.id == userId));
  }

  Future<void> _toggleMute(_StreamViewer viewer) async {
    final streamId = widget.args?.streamId;
    if (streamId == null) return;
    final muted = _mutedIds.contains(viewer.id);
    final ok = muted
        ? await XLiveSocketClient.instance.unmuteViewer(streamId: streamId, userId: viewer.id)
        : await XLiveSocketClient.instance.muteViewer(streamId: streamId, userId: viewer.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (muted) {
          _mutedIds.remove(viewer.id);
        } else {
          _mutedIds.add(viewer.id);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update mute')));
    }
  }

  Future<void> _toggleTalkBack(_StreamViewer viewer) async {
    final streamId = widget.args?.streamId;
    if (streamId == null) return;
    final granted = _talkBackIds.contains(viewer.id);
    final ok = granted
        ? await XLiveSocketClient.instance.revokeTalkBack(streamId: streamId, userId: viewer.id)
        : await XLiveSocketClient.instance.grantTalkBack(streamId: streamId, userId: viewer.id);
    if (!mounted) return;
    if (ok) {
      setState(() {
        if (granted) {
          _talkBackIds.remove(viewer.id);
        } else {
          _talkBackIds.add(viewer.id);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update talkback')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHost = widget.args?.isHost == true;
    return Scaffold(
      backgroundColor: _light,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 32, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(100))),
            const SizedBox(height: 16),
            if (isHost && widget.args?.streamId != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Manage Viewers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade900)),
                ),
              ),
              const SizedBox(height: 8),
              if (_viewers.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Viewers will appear here', style: TextStyle(color: Colors.grey.shade600)),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _viewers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final v = _viewers[i];
                      final muted = _mutedIds.contains(v.id);
                      final talkBack = _talkBackIds.contains(v.id);
                      return ListTile(
                        leading: UserAvatar(radius: 22, imageUrl: v.avatarUrl),
                        title: Text(v.name),
                        subtitle: muted || talkBack
                            ? Text(
                                [
                                  if (muted) 'Muted',
                                  if (talkBack) 'Talkback',
                                ].join(' · '),
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              )
                            : null,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: muted ? 'Unmute' : 'Mute',
                              onPressed: () => _toggleMute(v),
                              icon: Icon(muted ? Icons.mic_off_rounded : Icons.mic_rounded, size: 20),
                            ),
                            IconButton(
                              tooltip: talkBack ? 'Revoke talkback' : 'Grant talkback',
                              onPressed: () => _toggleTalkBack(v),
                              icon: Icon(talkBack ? Icons.record_voice_over_rounded : Icons.voice_over_off_outlined, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              onPressed: () => _removeViewer(v.id),
                              icon: const Icon(Icons.person_remove_outlined, size: 20),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ] else
              Expanded(
                child: ListView(
                  children: [
                    if (isHost)
                      ListTile(
                        title: const Text('Private Live Stream'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.pushNamed(context, '/profile/creator/private-live'),
                      ),
                    ListTile(title: const Text('Settings'), trailing: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }
}

class _StreamViewer {
  const _StreamViewer({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.muted = false,
    this.talkBack = false,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  final bool muted;
  final bool talkBack;
}

class LiveNotificationsScreen extends StatefulWidget {
  const LiveNotificationsScreen({super.key});

  @override
  State<LiveNotificationsScreen> createState() => _LiveNotificationsScreenState();
}

class _LiveNotificationsScreenState extends State<LiveNotificationsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_outlined, color: _black),
            title: const Text('Push inbox', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
            subtitle: const Text('View recent push notifications', style: TextStyle(fontSize: 13, color: Colors.black54)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const PushInboxScreen())),
          ),
          ListTile(
            leading: const Icon(Icons.settings_outlined, color: _black),
            title: const Text('Notification settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
            subtitle: const Text('Manage live, sound, and call alerts', style: TextStyle(fontSize: 13, color: Colors.black54)),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.pushNamed(context, '/profile/notifications'),
          ),
        ],
      ),
    );
  }
}


class _HomeFeedTabBar extends StatelessWidget {
  const _HomeFeedTabBar({required this.selected, required this.onSelect});

  final int selected;
  final ValueChanged<int> onSelect;

  static const _labels = ['For you', 'Following', 'Live', 'Clip'];
  static const _icons = [
    Icons.auto_awesome_rounded,
    Icons.people_alt_rounded,
    Icons.sensors_rounded,
    Icons.movie_creation_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_labels.length, (i) {
            final active = selected == i;
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelect(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                    horizontal: active ? 16 : 13,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: active ? _black : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _icons[i],
                        size: 15,
                        color: active ? Colors.white : const Color(0xFF8E8E93),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _labels[i],
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                          color: active ? Colors.white : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class SuggestedAccount {
  const SuggestedAccount({
    required this.id,
    required this.username,
    required this.displayName,
    this.avatarUrl,
    this.isFollowing = false,
  });

  final String id;
  final String username;
  final String displayName;
  final String? avatarUrl;
  final bool isFollowing;

  String get initials {
    final direct = displayName.trim();
    if (direct.isNotEmpty) return direct[0].toUpperCase();
    final handle = username.replaceAll('@', '').trim();
    if (handle.isNotEmpty) return handle[0].toUpperCase();
    return 'U';
  }
}

class _HomeSuggestedAccountsSection extends StatelessWidget {
  const _HomeSuggestedAccountsSection({
    required this.accounts,
    required this.followingIds,
    required this.onToggleFollow,
    required this.onOpenAccount,
    required this.onDismiss,
  });

  final List<SuggestedAccount> accounts;
  final Set<String> followingIds;
  final ValueChanged<SuggestedAccount> onToggleFollow;
  final ValueChanged<SuggestedAccount> onOpenAccount;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.only(top: 14, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Suggested pages',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: onDismiss,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: accounts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final account = accounts[i];
                final isFollowing = followingIds.contains(account.id) || account.isFollowing;
                return _SuggestedAccountCard(
                  account: account,
                  isFollowing: isFollowing,
                  onToggleFollow: () => onToggleFollow(account),
                  onOpen: () => onOpenAccount(account),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedAccountCard extends StatelessWidget {
  const _SuggestedAccountCard({
    required this.account,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.onOpen,
  });

  final SuggestedAccount account;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final handle = account.username.startsWith('@') ? account.username : '@${account.username}';

    return Container(
      width: 132,
      height: 196,
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: onOpen,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: ClipOval(
                child: account.avatarUrl != null && account.avatarUrl!.isNotEmpty
                    ? Image.network(
                        account.avatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _fallbackAvatar(),
                      )
                    : _fallbackAvatar(),
              ),
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: onOpen,
            child: Text(
              handle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 35,
            child: Material(
              color: isFollowing ? const Color(0xFF2C2C2E) : Colors.white,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: onToggleFollow,
                child: Center(
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      color: isFollowing ? Colors.white : Colors.black,
                      fontWeight: isFollowing ? FontWeight.w600 : FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: const Color(0xFF262628),
      alignment: Alignment.center,
      child: Text(
        account.initials,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 22,
        ),
      ),
    );
  }
}

class _HomeEmptyState extends StatelessWidget {
  const _HomeEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
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
                  colors: [_homeGradStart.withValues(alpha: 0.18), _homeGradEnd.withValues(alpha: 0.18)],
                ),
              ),
              child: Icon(icon, size: 38, color: _homeGradEnd),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: _homeMuted, height: 1.45),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onAction,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _black,
                  side: const BorderSide(color: Color(0xFFE2E2E6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: Text(actionLabel!, style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
