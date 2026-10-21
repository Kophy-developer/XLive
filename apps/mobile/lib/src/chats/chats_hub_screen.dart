import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/live/live_now_store.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/session/auth_session.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/chats/chats_repository.dart';
import '../../features/groups/groups_repository.dart';
import '../../features/feed/feed_repository.dart';
import '../../features/users/users_repository.dart';
import '../../features/users/models/user_models.dart';
import '../../features/calls/models/call_models.dart';
import '../integration/call_screens.dart';
import '../app_bottom_nav.dart';
import 'chat_models.dart';
import 'chat_theme.dart';
import 'dm_chat_screen.dart';
import 'explore_groups_screen.dart';
import 'group_chat_screen.dart';
import 'group_dialogs_sheets.dart';
import 'group_info_screen.dart';
import 'select_contact_screen.dart';

class ChatsHubScreen extends StatefulWidget {
  const ChatsHubScreen({super.key});

  @override
  State<ChatsHubScreen> createState() => _ChatsHubScreenState();
}

class _ChatsHubScreenState extends State<ChatsHubScreen> with WidgetsBindingObserver {
  final _chatsRepo = ChatsRepository();
  final _groupsRepo = GroupsRepository();
  final _settings = SettingsRepository();
  int _segment = 0;
  bool _unreadOnly = false;
  List<ChatDmPreview> _dms = const [];
  List<ChatGroupPreview> _groups = const [];
  List<ChatGroupPreview> _discoverGroups = const [];
  List<SuggestedCreatorRow> _suggested = const [];
  bool _loading = false;
  bool _loadingSuggested = false;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _socketDmSub;
  StreamSubscription<Map<String, dynamic>>? _socketGroupSub;
  StreamSubscription<Map<String, dynamic>>? _socketUnreadSub;
  Timer? _retryTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadHub();
    _loadSuggested();
    unawaited(LiveNowStore.instance.refresh());
    AuthSession.instance.refreshUnread();
    AuthSession.instance.refreshWallet();
    final socket = XLiveSocketClient.instance;
    _socketDmSub = socket.onDmMessage.listen((_) {
      _loadHub();
      _loadSuggested();
    });
    _socketGroupSub = socket.onGroupMessage.listen((_) => _loadHub());
    _socketUnreadSub = socket.onUnreadUpdated.listen((_) => _loadHub());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _socketDmSub?.cancel();
    _socketGroupSub?.cancel();
    _socketUnreadSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && AuthSession.instance.isSignedIn) {
      _loadHub(silent: true);
    }
  }

  Future<void> _loadHub({bool silent = false}) async {
    if (!AuthSession.instance.isSignedIn) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _dms = const [];
        _groups = const [];
        _discoverGroups = const [];
        _error = null;
      });
      return;
    }
    if (!silent && _dms.isEmpty && _groups.isEmpty) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (!silent) {
      setState(() => _error = null);
    }
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final dmThreads = await _chatsRepo.listChats();
        final myGroups = await _groupsRepo.listMyGroups();
        final discover = await _groupsRepo.discoverGroups(limit: 5);
        if (!mounted) return;
        final myGroupIds = myGroups.map((g) => g.id).toSet();
        _retryTimer?.cancel();
        await LiveNowStore.instance.refresh();
        if (!mounted) return;
        setState(() {
          _dms = dmThreads.map((t) {
            final peer = t.otherUser;
            return ChatDmPreview(
              chatId: t.id,
              peerUserId: peer?.id,
              name: peer?.name ?? 'User',
              avatarUrl: peer?.avatarUrl ?? '',
              preview: t.preview ?? 'No messages yet',
              timeLabel: t.timeLabel,
              unread: t.unread > 0 ? t.unread : null,
              isLive: LiveNowStore.instance.isLive(peer?.id),
            );
          }).toList();
          _groups = myGroups.map(_groupPreviewFromSummary).toList();
          _discoverGroups = discover
              .where((g) => !myGroupIds.contains(g.id))
              .map((g) => ChatGroupPreview(
                    groupId: g.id,
                    name: g.name,
                    avatarUrl: g.iconUrl ?? '',
                    preview: '${g.memberCount} followers',
                    memberCount: g.memberCount,
                  ))
              .toList();
          _loading = false;
          _error = null;
        });
        _loadSuggested();
        _hydratePreviews();
        return;
      } catch (e) {
        lastError = e;
        if (attempt < 2 && _isTransientNetworkError(e)) {
          await Future<void>.delayed(Duration(milliseconds: 350 * (attempt + 1)));
          continue;
        }
        break;
      }
    }
    if (!mounted) return;
    final hasCachedLists = _dms.isNotEmpty || _groups.isNotEmpty;
    if (hasCachedLists && lastError != null && _isTransientNetworkError(lastError)) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = false;
      _error = _friendlyHubLoadError(lastError);
    });
    if (!hasCachedLists && lastError != null && _isTransientNetworkError(lastError)) {
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _error != null) _loadHub(silent: true);
      });
    }
  }

  static bool _isTransientNetworkError(Object e) {
    final msg = e.toString().toLowerCase();
    return msg.contains('connection abort') ||
        msg.contains('connection reset') ||
        msg.contains('connection closed') ||
        msg.contains('socketexception') ||
        msg.contains('clientexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('timed out') ||
        msg.contains('network is unreachable') ||
        msg.contains('handshake') ||
        msg.contains('broken pipe');
  }

  static String _friendlyHubLoadError(Object? e) {
    if (e == null) return 'Could not load chats.';
    if (_isTransientNetworkError(e)) {
      return 'Connection interrupted. Pull down to refresh or tap Retry.';
    }
    return friendlyApiMessage(e, fallback: 'Could not load chats. Tap Retry.');
  }

  static const _emptyDmPreview = 'No messages yet';

  bool _needsPreview(String preview) {
    final p = preview.trim();
    return p.isEmpty || p == _emptyDmPreview;
  }

  String _previewFromMessage(ChatMessage m) {
    final content = m.content?.trim() ?? '';
    if (content.isNotEmpty) return content;
    if (m.isSticker) return 'Sticker';
    if (m.isImage) return 'Photo';
    if (m.isVideo) return 'Video';
    if (m.isAudio) return 'Voice message';
    if (m.hasMedia) return 'Attachment';
    return _emptyDmPreview;
  }

  Future<void> _hydratePreviews() async {
    final dmTargets = <int>[];
    for (var i = 0; i < _dms.length; i++) {
      final chatId = _dms[i].chatId;
      if (chatId != null && chatId.isNotEmpty && _needsPreview(_dms[i].preview)) {
        dmTargets.add(i);
      }
    }
    final groupTargets = <int>[];
    for (var i = 0; i < _groups.length; i++) {
      final groupId = _groups[i].groupId;
      final p = _groups[i].preview.trim();
      final isFallback = _needsPreview(p) || p.endsWith(' members');
      if (groupId != null && groupId.isNotEmpty && isFallback) {
        groupTargets.add(i);
      }
    }
    if (dmTargets.isEmpty && groupTargets.isEmpty) return;

    final dmFutures = dmTargets.map((i) async {
      try {
        final msgs = await _chatsRepo.getMessages(_dms[i].chatId!, limit: 1);
        return (i, msgs.isEmpty ? null : msgs.first);
      } catch (_) {
        return (i, null);
      }
    });
    final groupFutures = groupTargets.map((i) async {
      try {
        final msgs = await _groupsRepo.getGroupMessages(_groups[i].groupId!, limit: 1);
        return (i, msgs.isEmpty ? null : msgs.first);
      } catch (_) {
        return (i, null);
      }
    });

    final dmResults = await Future.wait(dmFutures);
    final groupResults = await Future.wait(groupFutures);
    if (!mounted) return;

    setState(() {
      for (final (i, msg) in dmResults) {
        if (msg == null || i >= _dms.length) continue;
        _dms[i] = _dms[i].copyWith(
          preview: _previewFromMessage(msg),
          timeLabel: _dms[i].timeLabel ?? msg.timeLabel,
        );
      }
      for (final (i, msg) in groupResults) {
        if (msg == null || i >= _groups.length) continue;
        final senderName = (msg.senderName ?? '').trim();
        final body = _previewFromMessage(msg);
        final line = body == _emptyDmPreview
            ? body
            : (senderName.isEmpty || msg.isMine ? body : '$senderName: $body');
        _groups[i] = _groups[i].copyWith(
          preview: line,
          timeLabel: _groups[i].timeLabel ?? msg.timeLabel,
        );
      }
    });
  }

  ChatGroupPreview _groupPreviewFromSummary(GroupSummary g) {
    final raw = (g.preview ?? g.description ?? '').trim();
    final fallback = g.memberCount > 0 ? '${g.memberCount} members' : 'No messages yet';
    return ChatGroupPreview(
      groupId: g.id,
      chatId: g.chatId,
      name: g.name,
      avatarUrl: g.iconUrl ?? '',
      preview: raw.isEmpty ? fallback : raw,
      timeLabel: g.timeLabel,
      unread: g.unread > 0 ? g.unread : null,
      memberCount: g.memberCount,
    );
  }

  Future<void> _joinGroupFromDiscover(ChatGroupPreview discover) async {
    final groupId = discover.groupId;
    if (groupId == null || groupId.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final joined = await _groupsRepo.joinGroup(groupId);
      await XLiveSocketClient.instance.joinGroup(groupId);
      if (!mounted) return;
      final preview = _groupPreviewFromSummary(joined);
      setState(() {
        if (!_groups.any((g) => g.groupId == groupId)) {
          _groups = [preview, ..._groups];
        }
        _discoverGroups = _discoverGroups.where((g) => g.groupId != groupId).toList();
      });
      await _loadHub(silent: true);
    } catch (e) {
      if (!mounted) rethrow;
      messenger.showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
      rethrow;
    }
  }

  Future<void> _openExploreGroups() async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const ExploreGroupsScreen()));
    if (!mounted) return;
    await _loadHub(silent: true);
  }

  Future<void> _loadSuggested() async {
    if (!AuthSession.instance.isSignedIn) {
      if (!mounted) return;
      setState(() => _suggested = const []);
      return;
    }
    setState(() => _loadingSuggested = true);
    try {
      final usersRepo = UsersRepository();
      final feedRepo = FeedRepository();
      List<XLiveUser> people;
      try {
        final feed = await feedRepo.followersFeed(limit: 12);
        people = feed
            .where((f) => f.creatorId != null && f.creatorId!.isNotEmpty)
            .map((f) => XLiveUser(id: f.creatorId!, displayName: f.creatorName, avatarUrl: f.creatorAvatarUrl, isCreator: true))
            .toList();
        if (people.isEmpty) throw StateError('empty');
      } catch (_) {
        people = await usersRepo.listOnline(limit: 12);
      }
      final selfId = AuthSession.instance.user?.id;
      final dmPeerIds = _dms.map((d) => d.peerUserId).whereType<String>().toSet();
      await LiveNowStore.instance.refresh();
      final rows = <SuggestedCreatorRow>[];
      for (final user in people) {
        if (user.id.isEmpty || user.id == selfId || dmPeerIds.contains(user.id)) continue;
        final name = user.effectiveDisplayName;
        final live = LiveNowStore.instance.isLive(user.id);
        rows.add(
          SuggestedCreatorRow(
            userId: user.id,
            name: name,
            avatarUrl: user.avatarUrl ?? '',
            subtitle: live ? 'Live now' : (user.isCreator ? 'Creator on Xlive' : 'Online now'),
            actionKind: user.isCreator ? SuggestedActionKind.callPerMin : SuggestedActionKind.sayHi,
            callPricePerMin: user.isCreator ? 300 : null,
            isLive: live,
          ),
        );
        if (rows.length >= 6) break;
      }
      if (!mounted) return;
      setState(() {
        _suggested = rows;
        _loadingSuggested = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _suggested = const [];
        _loadingSuggested = false;
      });
    }
  }

  Future<void> _blockDmUser(ChatDmPreview item) async {
    final userId = item.peerUserId;
    if (userId == null || userId.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Block ${item.name}?'),
        content: const Text('They will not be able to contact you and will be removed from your chats.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE53935)),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _settings.blockUser(userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.name} blocked')));
      _loadHub();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _sayHi(SuggestedCreatorRow item) async {
    try {
      if (await _settings.isUserBlocked(item.userId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user is blocked. You cannot chat with them.')),
        );
        return;
      }
      final thread = await _chatsRepo.createDm(item.userId);
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DmChatScreen(
            chatId: thread.id,
            peerName: item.name,
            peerAvatarUrl: item.avatarUrl.isEmpty ? '' : item.avatarUrl,
            peerUserId: item.userId,
          ),
        ),
      );
      _loadHub();
      _loadSuggested();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _startCall(SuggestedCreatorRow item) async {
    try {
      final thread = await _chatsRepo.createDm(item.userId);
      if (!mounted) return;
      await startDmCall(
        context,
        chatId: thread.id,
        peerName: item.name,
        callType: CallMediaType.audio,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  void _openFabMenu() {
    showAddGroupChoiceSheet(
      context,
      onCreateNew: () {
        showCreateGroupSheet(context, onCreated: (group) {
          if (!mounted || group == null) return;
          _loadHub();
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (_) => GroupChatScreen(
                groupId: group.id,
                groupName: group.name,
                avatarUrl: group.iconUrl ?? '',
                showWelcome: true,
              ),
            ),
          );
        });
      },
      onJoinExisting: _openExploreGroups,
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AuthSession.instance;
    final selfAvatar = session.user?.avatarUrl;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              color: ChatTheme.purple,
              onRefresh: () => _loadHub(),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                slivers: [
                SliverToBoxAdapter(child: _TopBar(avatarUrl: selfAvatar)),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      children: [
                        Expanded(child: _DmGroupSegment(selected: _segment, onChanged: (i) => setState(() => _segment = i))),
                        const SizedBox(width: 8),
                        FilterChip(
                          selected: _unreadOnly,
                          label: const Text('Unread'),
                          onSelected: (v) => setState(() => _unreadOnly = v),
                          selectedColor: ChatTheme.purple.withValues(alpha: 0.15),
                          checkmarkColor: ChatTheme.purple,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: _unreadOnly ? ChatTheme.purple : ChatTheme.black,
                          ),
                          side: BorderSide(color: _unreadOnly ? ChatTheme.purple : Colors.grey.shade300),
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        IconButton(
                          onPressed: () {
                            if (_segment == 0) {
                              openChatSearchPicker(context);
                            } else {
                              _openExploreGroups();
                            }
                          },
                          icon: const Icon(Icons.search_rounded, color: ChatTheme.black),
                        ),
                      ],
                    ),
                  ),
                ),
                if (!session.isSignedIn)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HubMessage(
                      message: 'Sign in to view your chats.',
                      actionLabel: 'Sign in',
                      onAction: () => Navigator.pushNamed(context, '/auth/sign-in'),
                    ),
                  )
                else if (_loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (_error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _HubMessage(message: _error!, actionLabel: 'Retry', onAction: _loadHub),
                  )
                else if (_segment == 0) ..._buildDmSlivers() else ..._buildGroupSlivers(),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
            Positioned(
              right: 20,
              bottom: 18,
              child: Material(
                color: ChatTheme.purple,
                shape: const CircleBorder(),
                elevation: 6,
                shadowColor: Colors.black26,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    if (_segment == 0) {
                      openChatSearchPicker(context);
                    } else {
                      _openFabMenu();
                    }
                  },
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: Icon(_segment == 0 ? Icons.edit_rounded : Icons.add, color: Colors.white, size: _segment == 0 ? 24 : 28),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const MainBottomNav(selected: MainNavItem.chats),
    );
  }

  List<Widget> _buildDmSlivers() {
    final visible = _unreadOnly ? _dms.where((d) => (d.unread ?? 0) > 0).toList() : _dms;
    if (visible.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _HubMessage(
            message: _unreadOnly ? 'No unread chats.' : 'No conversations yet.',
            actionLabel: _unreadOnly ? 'Show all' : 'Find people',
            onAction: _unreadOnly ? () => setState(() => _unreadOnly = false) : () => openChatSearchPicker(context),
          ),
        ),
      ];
    }
    return [
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final d = visible[i];
            return _SwipeableDmRow(
              item: d,
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => DmChatScreen(
                    chatId: d.chatId!,
                    peerName: d.name,
                    peerAvatarUrl: d.avatarUrl,
                    peerUserId: d.peerUserId,
                    online: false,
                  ),
                ),
              ).then((_) {
                if (mounted) _loadHub(silent: true);
              }),
              onBlock: () => _blockDmUser(d),
            );
          },
          childCount: visible.length,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              const Text('Suggested Creators', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/explore'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChatTheme.black,
                  backgroundColor: const Color(0xFFF2F2F2),
                  side: BorderSide.none,
                  shape: StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
      if (_loadingSuggested)
        const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2))))
      else if (_suggested.isEmpty)
        SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Text('No suggestions right now', style: TextStyle(color: Colors.grey.shade600))))
      else
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => _SuggestedRow(
              item: _suggested[i],
              onSayHi: () => _sayHi(_suggested[i]),
              onCall: () => _startCall(_suggested[i]),
            ),
            childCount: _suggested.length,
          ),
        ),
    ];
  }

  List<Widget> _buildGroupSlivers() {
    final groups = _unreadOnly ? _groups.where((g) => (g.unread ?? 0) > 0).toList() : _groups;
    final discover = _unreadOnly
        ? <ChatGroupPreview>[]
        : _discoverGroups
            .where((g) => g.groupId == null || !_groups.any((joined) => joined.groupId == g.groupId))
            .toList();
    final slivers = <Widget>[];

    if (groups.isEmpty) {
      if (_unreadOnly) {
        slivers.add(
          SliverFillRemaining(
            hasScrollBody: false,
            child: _HubMessage(
              message: 'No unread groups.',
              actionLabel: 'Show all',
              onAction: () => setState(() => _unreadOnly = false),
            ),
          ),
        );
        return slivers;
      }
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 8),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(color: ChatTheme.surface, borderRadius: BorderRadius.circular(18)),
                  child: const Icon(Icons.groups_2_outlined, size: 40, color: ChatTheme.black),
                ),
                const SizedBox(height: 16),
                const Text('Create a group', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  'Make a group for whatever you’re into, or follow one below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.45),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _openFabMenu,
                    style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: StadiumBorder()),
                    child: const Text('Create a group', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text('Active Group', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
          ),
        ),
      );
      slivers.add(
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) {
              final g = groups[i];
              return _GroupRow(
                item: g,
                onOpenChat: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => GroupChatScreen(
                      groupId: g.groupId,
                      groupName: g.name,
                      avatarUrl: g.avatarUrl,
                      followers: g.memberCount ?? 0,
                      showWelcome: false,
                    ),
                  ),
                ).then((_) {
                  if (mounted) _loadHub(silent: true);
                }),
                onOpenInfo: () => openGroupInfoScreen(
                  context,
                  groupId: g.groupId,
                  groupName: g.name,
                  avatarUrl: g.avatarUrl,
                  memberCount: g.memberCount ?? 0,
                ),
              );
            },
            childCount: groups.length,
          ),
        ),
      );
    }

    if (discover.isEmpty) {
      if (_groups.isEmpty) {
        slivers.add(SliverFillRemaining(hasScrollBody: false, child: const SizedBox.shrink()));
      }
      return slivers;
    }

    slivers.add(
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              Text('Find groups to join', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
              const Spacer(),
              OutlinedButton(
                onPressed: _openExploreGroups,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ChatTheme.black,
                  backgroundColor: const Color(0xFFF2F2F2),
                  side: BorderSide.none,
                  shape: StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                ),
                child: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              ),
            ],
          ),
        ),
      ),
    );
    slivers.add(
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final g = discover[i];
            return _DiscoverGroupRow(
              name: g.name,
              avatarUrl: g.avatarUrl,
              followers: g.memberCount ?? 0,
              onOpenInfo: () async {
                final joined = await openGroupInfoScreen(
                  context,
                  groupId: g.groupId,
                  groupName: g.name,
                  avatarUrl: g.avatarUrl,
                  memberCount: g.memberCount ?? 0,
                );
                if (!mounted) return;
                if (joined == true) await _loadHub(silent: true);
              },
              onFollow: () => showJoinGroupSheet(
                context,
                groupName: g.name,
                onJoin: () => _joinGroupFromDiscover(g),
              ),
            );
          },
          childCount: discover.length,
        ),
      ),
    );
    return slivers;
  }
}

class _HubMessage extends StatelessWidget {
  const _HubMessage({required this.message, this.actionLabel, this.onAction});

  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, fontSize: 15)),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({this.avatarUrl});

  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/profile/me', (r) => false),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: UserAvatar(radius: 20, imageUrl: avatarUrl),
              ),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: const Color(0xFFF6F6F6), borderRadius: BorderRadius.circular(999)),
            child: Row(
              children: [
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => Navigator.pushNamed(context, '/wallet/xlive'),
                    borderRadius: BorderRadius.circular(999),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.monetization_on_rounded, size: 18, color: Color(0xFFFFD700)),
                          const SizedBox(width: 4),
                          Text('${AuthSession.instance.walletBalance ?? '—'}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                        ],
                      ),
                    ),
                  ),
                ),
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Material(
                      color: ChatTheme.black,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => Navigator.pushNamed(context, '/wallet/xlive'),
                        child: const SizedBox(width: 32, height: 32, child: Icon(Icons.add, color: Colors.white, size: 18)),
                      ),
                    ),
                    Positioned(
                      right: -1,
                      top: -1,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(color: ChatTheme.redBadge, shape: BoxShape.circle),
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
  }
}

class _DmGroupSegment extends StatelessWidget {
  const _DmGroupSegment({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: ChatTheme.segmentBg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: [
          Expanded(
            child: _SegCell(label: "DM's", active: selected == 0, onTap: () => onChanged(0)),
          ),
          Expanded(
            child: _SegCell(label: 'Group', active: selected == 1, onTap: () => onChanged(1)),
          ),
        ],
      ),
    );
  }
}

class _SegCell extends StatelessWidget {
  const _SegCell({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, 2))] : null,
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: active ? FontWeight.w800 : FontWeight.w500, fontSize: 15, color: ChatTheme.black)),
        ),
      ),
    );
  }
}

class _SwipeableDmRow extends StatefulWidget {
  const _SwipeableDmRow({required this.item, required this.onTap, required this.onBlock});

  final ChatDmPreview item;
  final VoidCallback onTap;
  final VoidCallback onBlock;

  @override
  State<_SwipeableDmRow> createState() => _SwipeableDmRowState();
}

class _SwipeableDmRowState extends State<_SwipeableDmRow> {
  double _offset = 0;
  static const _actionWidth = 88.0;

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _offset = (_offset + details.delta.dx).clamp(-_actionWidth, 0.0));
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _offset = _offset < -_actionWidth / 2 ? -_actionWidth : 0);
  }

  void _close() => setState(() => _offset = 0);

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: Stack(
        children: [
          Positioned.fill(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Material(
                  color: const Color(0xFFE53935),
                  child: InkWell(
                    onTap: () {
                      _close();
                      widget.onBlock();
                    },
                    child: SizedBox(
                      width: _actionWidth,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.block_rounded, color: Colors.white, size: 22),
                          SizedBox(height: 4),
                          Text('Block', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            onTap: _offset == 0 ? widget.onTap : _close,
            child: Transform.translate(
              offset: Offset(_offset, 0),
              child: ColoredBox(
                color: Colors.white,
                child: _DmRow(item: widget.item),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmRow extends StatelessWidget {
  const _DmRow({required this.item});

  final ChatDmPreview item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          UserAvatar(radius: 26, imageUrl: item.avatarUrl.isEmpty ? null : item.avatarUrl, isLive: item.isLive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (item.dateLabel != null)
                Text(item.dateLabel!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600))
              else if (item.timeLabel != null)
                Text(item.timeLabel!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              if (item.unread != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: const BoxDecoration(color: ChatTheme.redBadge, shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                  alignment: Alignment.center,
                  child: Text('${item.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.item,
    required this.onOpenChat,
    required this.onOpenInfo,
  });

  final ChatGroupPreview item;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenInfo;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenChat,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onOpenInfo,
                behavior: HitTestBehavior.opaque,
                child: GroupAvatar(radius: 26, imageUrl: item.avatarUrl.isEmpty ? null : item.avatarUrl),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: onOpenInfo,
                      behavior: HitTestBehavior.opaque,
                      child: Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 4),
                    Text(item.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.timeLabel != null) Text(item.timeLabel!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                  if (item.unread != null) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: const BoxDecoration(color: ChatTheme.redBadge, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                      alignment: Alignment.center,
                      child: Text('${item.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestedRow extends StatelessWidget {
  const _SuggestedRow({required this.item, required this.onSayHi, required this.onCall});

  final SuggestedCreatorRow item;
  final VoidCallback onSayHi;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(radius: 26, imageUrl: item.avatarUrl.isEmpty ? null : item.avatarUrl, isLive: item.isLive),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(item.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (item.actionKind == SuggestedActionKind.callPerMin)
            OutlinedButton(
              onPressed: onCall,
              style: OutlinedButton.styleFrom(
                foregroundColor: ChatTheme.black,
                side: const BorderSide(color: ChatTheme.black, width: 1.2),
                shape: StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Call', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  if (item.callPricePerMin != null) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.monetization_on_rounded, size: 14, color: Color(0xFFFFD700)),
                    Text(' ${item.callPricePerMin} coins/min', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  ],
                ],
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: onSayHi,
              icon: const Icon(Icons.waving_hand_outlined, size: 18),
              label: const Text('Say Hi', style: TextStyle(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: ChatTheme.black,
                side: const BorderSide(color: ChatTheme.black, width: 1.1),
                shape: StadiumBorder(),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiscoverGroupRow extends StatelessWidget {
  const _DiscoverGroupRow({
    required this.name,
    required this.avatarUrl,
    required this.followers,
    required this.onOpenInfo,
    required this.onFollow,
  });

  final String name;
  final String avatarUrl;
  final int followers;
  final VoidCallback onOpenInfo;
  final VoidCallback onFollow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onOpenInfo,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      GroupAvatar(radius: 26, imageUrl: avatarUrl.isEmpty ? null : avatarUrl),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            Text('$followers followers', style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: onFollow,
            style: OutlinedButton.styleFrom(
              foregroundColor: ChatTheme.black,
              backgroundColor: const Color(0xFFF0F0F0),
              side: BorderSide.none,
              shape: StadiumBorder(),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            child: const Text('Join', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
