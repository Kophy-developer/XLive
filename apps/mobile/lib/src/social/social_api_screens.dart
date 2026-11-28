import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/user_avatar.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/groups/groups_repository.dart';
import '../../features/groups/models/group_models.dart';
import '../../features/hashtags/hashtags_repository.dart';
import '../../features/social/social_repository.dart';
import '../../features/streams/models/stream_models.dart';
import '../../features/streams/streams_repository.dart';
import '../../features/users/models/user_models.dart';
import '../../features/users/users_repository.dart';
import '../feed/feed_reel_viewer_screen.dart';
import '../profile/user_profile_preview_screens.dart';
import '../live/widgets/stream_invite_dialog.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _light = Color(0xFFF6F6F6);

class XLiveSubpage extends StatelessWidget {
  const XLiveSubpage({super.key, required this.title, required this.body, this.actions});

  final String title;
  final Widget body;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
        actions: actions,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: body,
    );
  }
}

class FollowListArgs {
  const FollowListArgs({required this.userId, required this.followers});

  final String userId;
  final bool followers;
}

class FollowListScreen extends StatefulWidget {
  const FollowListScreen({super.key, required this.args});

  final FollowListArgs args;

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  final _social = SocialRepository();
  final _scroll = ScrollController();
  List<XLiveUser> _users = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore || _loading) return;
    if (!_scroll.hasClients) return;
    if (_scroll.position.pixels < _scroll.position.maxScrollExtent - 240) return;
    unawaited(_loadMore());
  }

  Future<List<XLiveUser>> _fetchPage(int page) {
    return widget.args.followers
        ? _social.getFollowers(widget.args.userId, page: page, limit: 20)
        : _social.getFollowing(widget.args.userId, page: page, limit: 20);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
      _hasMore = true;
    });
    try {
      final users = await _fetchPage(1);
      if (!mounted) return;
      setState(() {
        _users = users;
        _loading = false;
        _hasMore = users.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final next = _page + 1;
    try {
      final users = await _fetchPage(next);
      if (!mounted) return;
      final existing = _users.map((u) => u.id).toSet();
      final merged = [..._users, ...users.where((u) => !existing.contains(u.id))];
      setState(() {
        _users = merged;
        _page = next;
        _hasMore = users.length >= 20;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: widget.args.followers ? 'Followers' : 'Following',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _users.isEmpty
                  ? const Center(child: Text('No users yet'))
                  : ListView.separated(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _users.length + (_loadingMore ? 1 : 0),
                      separatorBuilder: (_, index) => Divider(height: 1, color: Colors.grey.shade200, indent: 72),
                      itemBuilder: (_, i) {
                        if (i >= _users.length) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          );
                        }
                        final u = _users[i];
                        return ListTile(
                          leading: UserAvatar(radius: 20, imageUrl: u.avatarUrl),
                          title: Text(u.effectiveDisplayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: u.username == null ? null : Text('@${u.username}'),
                          trailing: const Icon(Icons.chevron_right_rounded, color: Colors.black38),
                          onTap: () => Navigator.pushNamed(
                            context,
                            '/profile/other-user',
                            arguments: OtherUserProfileArgs(userId: u.id),
                          ),
                        );
                      },
                    ),
    );
  }
}

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  final _settings = SettingsRepository();
  List<XLiveUser> _users = const [];
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
      final users = await _settings.listBlockedUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
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

  Future<void> _unblock(XLiveUser user) async {
    try {
      await _settings.unblockUser(user.id);
      if (!mounted) return;
      setState(() => _users = _users.where((u) => u.id != user.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: 'Blocked accounts',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _users.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.block_rounded, size: 48, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('No blocked accounts', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _users.length,
                      separatorBuilder: (_, index) => Divider(height: 1, color: Colors.grey.shade200, indent: 72),
                      itemBuilder: (_, i) {
                        final u = _users[i];
                        return ListTile(
                          leading: UserAvatar(radius: 20, imageUrl: u.avatarUrl),
                          title: Text(u.effectiveDisplayName),
                          subtitle: u.username == null || u.username!.isEmpty
                              ? null
                              : Text('@${u.username}'),
                          trailing: TextButton(onPressed: () => _unblock(u), child: const Text('Unblock')),
                        );
                      },
                    ),
    );
  }
}

class StreamInvitesScreen extends StatefulWidget {
  const StreamInvitesScreen({super.key});

  @override
  State<StreamInvitesScreen> createState() => _StreamInvitesScreenState();
}

class _StreamInvitesScreenState extends State<StreamInvitesScreen> {
  final _streamsRepo = StreamsRepository();
  List<StreamInvite> _invites = const [];
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
      var items = await _streamsRepo.myInvites();
      items = await Future.wait(items.map((invite) async {
        if (!invite.isPending) return invite;
        if (invite.isStreamEnded || invite.isStreamLiveOrScheduled) return invite;
        final streamId = invite.streamId?.trim();
        if (streamId == null || streamId.isEmpty) {
          return invite.copyWith(streamStatus: 'ended');
        }
        try {
          final stream = await _streamsRepo.getStream(streamId);
          final status = (stream.status ?? '').trim();
          return invite.copyWith(
            streamStatus: status.isNotEmpty ? status : (stream.isLive ? 'live' : 'ended'),
          );
        } catch (_) {
          return invite.copyWith(streamStatus: 'ended');
        }
      }));
      if (!mounted) return;
      setState(() {
        _invites = items;
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

  Future<void> _accept(StreamInvite invite) async {
    final accepted = await showStreamInviteAcceptDialog(context, invite: invite);
    if (accepted && mounted) await _load();
  }

  Future<void> _decline(StreamInvite invite) async {
    try {
      await _streamsRepo.declineInvite(invite.id);
      if (!mounted) return;
      setState(() => _invites = _invites.where((i) => i.id != invite.id).toList());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = _invites.where((i) => i.isPending).toList();
    return XLiveSubpage(
      title: 'Live invites',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : pending.isEmpty
                  ? const Center(child: Text('No pending invites'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: pending.length,
                      separatorBuilder: (_, index) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final invite = pending[i];
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _light,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0x1A0A0A0A)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(invite.streamTitle ?? 'Live stream', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                              const SizedBox(height: 4),
                              Text(
                                invite.isCohostRole
                                    ? 'From ${invite.hostName ?? 'a creator'} · Co-host invite'
                                    : 'From ${invite.hostName ?? 'a creator'}',
                                style: TextStyle(color: Colors.grey.shade700),
                              ),
                              if (invite.scheduleLabel != null) ...[
                                const SizedBox(height: 6),
                                Text(invite.scheduleLabel!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                              ],
                              const SizedBox(height: 14),
                              if (invite.isStreamEnded)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'Live has ended',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontWeight: FontWeight.w700, color: _black),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(onPressed: () => _decline(invite), child: const Text('Decline')),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(colors: [_purple, _sky]),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: ElevatedButton(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                                          onPressed: () => _accept(invite),
                                          child: const Text('Answer', style: TextStyle(color: Colors.white)),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }
}

class GroupJoinCodeScreen extends StatefulWidget {
  const GroupJoinCodeScreen({super.key});

  @override
  State<GroupJoinCodeScreen> createState() => _GroupJoinCodeScreenState();
}

class _GroupJoinCodeScreenState extends State<GroupJoinCodeScreen> {
  final _codeCtrl = TextEditingController();
  final _groupsRepo = GroupsRepository();
  bool _busy = false;

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final code = _codeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _groupsRepo.joinByInviteCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Joined group')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: 'Join with code',
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Enter the invite code shared by a group admin.', style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
            const SizedBox(height: 24),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Invite code',
                filled: true,
                fillColor: _light,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_purple, _sky]),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                  onPressed: _busy ? null : _join,
                  child: _busy
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Join group', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GroupMembersArgs {
  const GroupMembersArgs({required this.groupId, required this.groupName});

  final String groupId;
  final String groupName;
}

class GroupMembersScreen extends StatefulWidget {
  const GroupMembersScreen({super.key, required this.args});

  final GroupMembersArgs args;

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final _groupsRepo = GroupsRepository();
  List<GroupMember> _members = const [];
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
      final members = await _groupsRepo.listMembers(widget.args.groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
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

  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _groupsRepo.leaveGroup(widget.args.groupId);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: widget.args.groupName,
      actions: [
        TextButton(onPressed: _leave, child: const Text('Leave')),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _members.length,
                  separatorBuilder: (_, index) => Divider(height: 1, color: Colors.grey.shade200, indent: 72),
                  itemBuilder: (_, i) {
                    final m = _members[i];
                    return ListTile(
                      leading: UserAvatar(radius: 20, imageUrl: m.avatarUrl),
                      title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: m.role == null ? null : Text(m.role!),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/profile/other-user',
                        arguments: OtherUserProfileArgs(userId: m.id),
                      ),
                    );
                  },
                ),
    );
  }
}

class HashtagDiscoverScreen extends StatefulWidget {
  const HashtagDiscoverScreen({super.key});

  @override
  State<HashtagDiscoverScreen> createState() => _HashtagDiscoverScreenState();
}

class _HashtagDiscoverScreenState extends State<HashtagDiscoverScreen> {
  final _hashtagsRepo = HashtagsRepository();
  final _search = TextEditingController();
  List<HashtagItem> _trending = const [];
  List<HashtagItem> _results = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _hashtagsRepo.trending();
      if (!mounted) return;
      setState(() {
        _trending = items;
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

  Future<void> _searchTags(String q) async {
    if (q.trim().isEmpty) {
      setState(() => _results = const []);
      return;
    }
    try {
      final items = await _hashtagsRepo.search(q.trim());
      if (!mounted) return;
      setState(() => _results = items);
    } catch (_) {}
  }

  void _openTag(String tag) {
    Navigator.pushNamed(context, '/social/hashtag-feed', arguments: HashtagFeedArgs(tag: tag));
  }

  @override
  Widget build(BuildContext context) {
    final showingSearch = _search.text.trim().isNotEmpty;
    final list = showingSearch ? _results : _trending;
    return XLiveSubpage(
      title: 'Hashtags',
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _searchTags,
              decoration: InputDecoration(
                hintText: 'Search hashtags',
                prefixIcon: const Icon(Icons.tag_rounded),
                filled: true,
                fillColor: _light,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? _ErrorBody(message: _error!, onRetry: _loadTrending)
                    : list.isEmpty
                        ? const Center(child: Text('No hashtags found'))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: list.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 8),
                            itemBuilder: (_, i) {
                              final item = list[i];
                              return Material(
                                color: _light,
                                borderRadius: BorderRadius.circular(14),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openTag(item.tag),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.tag_rounded, color: _purple),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text('#${item.tag}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                        ),
                                        Text('${item.postCount}', style: TextStyle(color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}

class HashtagFeedArgs {
  const HashtagFeedArgs({required this.tag});

  final String tag;
}

class HashtagFeedScreen extends StatefulWidget {
  const HashtagFeedScreen({super.key, required this.args});

  final HashtagFeedArgs args;

  @override
  State<HashtagFeedScreen> createState() => _HashtagFeedScreenState();
}

class _HashtagFeedScreenState extends State<HashtagFeedScreen> {
  final _hashtagsRepo = HashtagsRepository();
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
      final items = await _hashtagsRepo.feed(widget.args.tag);
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
    final tag = widget.args.tag.replaceAll('#', '');
    return XLiveSubpage(
      title: '#$tag',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _ErrorBody(message: _error!, onRetry: _load)
              : _items.isEmpty
                  ? const Center(child: Text('No posts for this hashtag yet'))
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
                            loadMoreFeed: (page) => _hashtagsRepo.feed(widget.args.tag, page: page),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (item.thumbnailUrl != null)
                                  Image.network(item.thumbnailUrl!, fit: BoxFit.cover)
                                else
                                  Container(color: Colors.grey.shade300),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  right: 8,
                                  child: Text(
                                    item.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, shadows: [Shadow(color: Colors.black54, blurRadius: 8)]),
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

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});

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
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
