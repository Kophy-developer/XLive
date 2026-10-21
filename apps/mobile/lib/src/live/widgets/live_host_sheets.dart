import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/network/api_friendly_messages.dart';
import '../../../core/socket/xlive_socket_client.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../features/streams/models/stream_models.dart';
import '../../../features/streams/streams_repository.dart';
import '../live_theme.dart';

Future<void> showLiveInviteSheet(
  BuildContext context, {
  required String streamId,
  bool allowCohost = false,
  int maxCohosts = 3,
  int remainingCohostSlots = 3,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LiveInviteSheet(
      streamId: streamId,
      allowCohost: allowCohost,
      maxCohosts: maxCohosts,
      remainingCohostSlots: remainingCohostSlots,
    ),
  );
}

Future<void> showLivePeoplePanel(
  BuildContext context, {
  required String streamId,
  int viewerCount = 0,
  bool allowCohost = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LivePeoplePanel(
      streamId: streamId,
      viewerCount: viewerCount,
      allowCohost: allowCohost,
    ),
  );
}

class _LiveInviteSheet extends StatefulWidget {
  const _LiveInviteSheet({
    required this.streamId,
    this.allowCohost = false,
    this.maxCohosts = 3,
    this.remainingCohostSlots = 3,
  });

  final String streamId;
  final bool allowCohost;
  final int maxCohosts;
  final int remainingCohostSlots;

  @override
  State<_LiveInviteSheet> createState() => _LiveInviteSheetState();
}

class _LiveInviteSheetState extends State<_LiveInviteSheet> with SingleTickerProviderStateMixin {
  final _streamsRepo = StreamsRepository();
  final _searchCtrl = TextEditingController();
  late final TabController _tabs;
  List<StreamInviteCandidate> _candidates = const [];
  List<StreamInvite> _sent = const [];
  bool _loading = true;
  String? _error;
  final Set<String> _invited = {};
  Timer? _searchDebounce;
  String? _busyInviteId;
  bool _inviteAsCohost = false;
  int _cohostSplitPercent = 20;
  int _pendingCohostInvites = 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      if (_tabs.indexIsChanging) return;
      _reloadForTab();
    });
    _loadCandidates('followers');
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    _tabs.dispose();
    super.dispose();
  }

  String get _source {
    return switch (_tabs.index) {
      1 => 'following',
      2 => 'search',
      _ => 'followers',
    };
  }

  int get _hostKeepPercent {
    final used = (_pendingCohostInvites * _cohostSplitPercent).clamp(0, 90);
    return (100 - used).clamp(10, 100);
  }

  Future<void> _reloadForTab() async {
    if (_tabs.index == 3) {
      await _loadSent();
      return;
    }
    await _loadCandidates(_source, q: _tabs.index == 2 ? _searchCtrl.text : null);
  }

  Future<void> _loadCandidates(String source, {String? q}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _streamsRepo.inviteCandidates(
        widget.streamId,
        source: source,
        q: source == 'search' ? (q ?? '') : null,
      );
      if (!mounted) return;
      setState(() {
        _candidates = items;
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

  Future<void> _loadSent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _streamsRepo.listStreamInvites(widget.streamId);
      if (!mounted) return;
      setState(() {
        _sent = items;
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

  void _onSearchChanged(String value) {
    if (_tabs.index != 2) {
      setState(() {});
      return;
    }
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      _loadCandidates('search', q: value);
    });
  }

  Future<void> _invite(StreamInviteCandidate user) async {
    final asCohost = widget.allowCohost && _inviteAsCohost;
    if (asCohost) {
      if (_pendingCohostInvites >= widget.remainingCohostSlots || _pendingCohostInvites >= widget.maxCohosts) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Max ${widget.maxCohosts} co-hosts')),
        );
        return;
      }
      final nextTotal = (_pendingCohostInvites + 1) * _cohostSplitPercent;
      if (nextTotal > 90) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Co-host splits can total at most 90%')),
        );
        return;
      }
    }
    try {
      await _streamsRepo.sendInvite(
        widget.streamId,
        user.id,
        role: asCohost ? 'cohost' : null,
        earningsSplitPercent: asCohost ? _cohostSplitPercent : null,
      );
      if (!mounted) return;
      setState(() {
        _invited.add(user.id);
        if (asCohost) _pendingCohostInvites += 1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asCohost ? 'Invited ${user.name} as co-host' : 'Invited ${user.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _cancel(StreamInvite invite) async {
    if (!invite.isPending || _busyInviteId != null) return;
    setState(() => _busyInviteId = invite.id);
    try {
      await _streamsRepo.cancelInvite(invite.id);
      if (!mounted) return;
      setState(() => _sent = _sent.where((i) => i.id != invite.id).toList());
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invite cancelled')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _busyInviteId = null);
    }
  }

  Future<void> _redial(StreamInvite invite) async {
    final userId = invite.inviteeId;
    if (userId == null || userId.isEmpty || _busyInviteId != null) return;
    setState(() => _busyInviteId = invite.id);
    try {
      await _streamsRepo.redialInvite(
        widget.streamId,
        userId,
        role: invite.role,
        earningsSplitPercent: invite.earningsSplitPercent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redialed ${invite.inviteeLabel}')));
      await _loadSent();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _busyInviteId = null);
    }
  }

  List<StreamInviteCandidate> get _visibleCandidates {
    if (_tabs.index == 2) return _candidates;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _candidates;
    return _candidates.where((u) => u.name.toLowerCase().contains(q) || (u.username ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.86,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Invite people', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              if (widget.allowCohost) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Invite selected as co-hosts',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ),
                            Switch.adaptive(
                              value: _inviteAsCohost,
                              activeTrackColor: LiveTheme.purple,
                              onChanged: (v) => setState(() => _inviteAsCohost = v),
                            ),
                          ],
                        ),
                        if (_inviteAsCohost) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Text('Each co-host split', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              Text('$_cohostSplitPercent%', style: const TextStyle(fontWeight: FontWeight.w800)),
                            ],
                          ),
                          Slider(
                            value: _cohostSplitPercent.toDouble(),
                            min: 5,
                            max: 90,
                            divisions: 17,
                            activeColor: LiveTheme.purple,
                            onChanged: (v) => setState(() => _cohostSplitPercent = v.round()),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Host keeps ~$_hostKeepPercent% · max ${widget.maxCohosts} · max 90% total',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              TabBar(
                controller: _tabs,
                isScrollable: true,
                labelColor: LiveTheme.purple,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: LiveTheme.purple,
                tabs: const [
                  Tab(text: 'Followers'),
                  Tab(text: 'Following'),
                  Tab(text: 'Search'),
                  Tab(text: 'Sent'),
                ],
              ),
              if (_tabs.index != 3)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: _tabs.index == 2 ? 'Search people' : 'Filter list',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                TextButton(onPressed: _reloadForTab, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : _tabs.index == 3
                            ? (_sent.isEmpty
                                ? const Center(child: Text('No invites sent yet'))
                                : ListView.separated(
                                    controller: scroll,
                                    itemCount: _sent.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                    itemBuilder: (_, i) {
                                      final invite = _sent[i];
                                      final busy = _busyInviteId == invite.id;
                                      final roleLabel = invite.isCohostRole
                                          ? 'Co-host${invite.earningsSplitPercent != null ? ' · ${invite.earningsSplitPercent}%' : ''}'
                                          : (invite.status ?? 'pending');
                                      return ListTile(
                                        leading: UserAvatar(radius: 22, imageUrl: invite.inviteeAvatarUrl),
                                        title: Text(invite.inviteeLabel),
                                        subtitle: Text(roleLabel),
                                        trailing: invite.isPending
                                            ? Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  TextButton(
                                                    onPressed: busy ? null : () => _redial(invite),
                                                    child: busy
                                                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                        : const Text('Redial'),
                                                  ),
                                                  TextButton(
                                                    onPressed: busy ? null : () => _cancel(invite),
                                                    child: const Text('Cancel'),
                                                  ),
                                                ],
                                              )
                                            : null,
                                      );
                                    },
                                  ))
                            : (_visibleCandidates.isEmpty
                                ? Center(
                                    child: Text(
                                      _tabs.index == 2 ? 'Search for people to invite' : 'No people to invite',
                                    ),
                                  )
                                : ListView.separated(
                                    controller: scroll,
                                    itemCount: _visibleCandidates.length,
                                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                                    itemBuilder: (_, i) {
                                      final user = _visibleCandidates[i];
                                      final sent = _invited.contains(user.id);
                                      return ListTile(
                                        leading: UserAvatar(radius: 22, imageUrl: user.avatarUrl),
                                        title: Text(user.name),
                                        subtitle: user.username == null ? null : Text('@${user.username}'),
                                        trailing: FilledButton(
                                          onPressed: sent ? null : () => _invite(user),
                                          style: FilledButton.styleFrom(
                                            backgroundColor: LiveTheme.purple,
                                            disabledBackgroundColor: Colors.grey.shade300,
                                            shape: const StadiumBorder(),
                                          ),
                                          child: Text(sent ? 'Invited' : (_inviteAsCohost ? 'Invite co-host' : 'Invite')),
                                        ),
                                      );
                                    },
                                  )),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LivePeoplePanel extends StatefulWidget {
  const _LivePeoplePanel({
    required this.streamId,
    this.viewerCount = 0,
    this.allowCohost = false,
  });

  final String streamId;
  final int viewerCount;
  final bool allowCohost;

  @override
  State<_LivePeoplePanel> createState() => _LivePeoplePanelState();
}

class _LivePeoplePanelState extends State<_LivePeoplePanel> {
  final _repo = StreamsRepository();
  StreamCohostsInfo _cohosts = const StreamCohostsInfo();
  List<StreamInvite> _invites = const [];
  bool _loading = true;
  String? _error;
  String? _busyId;

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
      final results = await Future.wait([
        _repo.getCohosts(widget.streamId),
        _repo.listStreamInvites(widget.streamId),
      ]);
      if (!mounted) return;
      setState(() {
        _cohosts = results[0] as StreamCohostsInfo;
        _invites = results[1] as List<StreamInvite>;
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

  Future<void> _redial(StreamInvite invite) async {
    final userId = invite.inviteeId;
    if (userId == null || userId.isEmpty || _busyId != null) return;
    setState(() => _busyId = invite.id);
    try {
      await _repo.redialInvite(
        widget.streamId,
        userId,
        role: invite.role,
        earningsSplitPercent: invite.earningsSplitPercent,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Redialed ${invite.inviteeLabel}')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _removeCohost(StreamCohostMember member) async {
    final userId = member.userId;
    if (userId == null || userId.isEmpty || _busyId != null) return;
    final key = 'cohost_$userId';
    setState(() => _busyId = key);
    try {
      await _repo.removeCohost(widget.streamId, userId);
      await XLiveSocketClient.instance.removeViewer(streamId: widget.streamId, userId: userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${member.label}')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _cancelPending(StreamInvite invite) async {
    if (_busyId != null) return;
    setState(() => _busyId = 'cancel_${invite.id}');
    try {
      await _repo.cancelInvite(invite.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invite cancelled for ${invite.inviteeLabel}')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.94,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Center(
                child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'IN THIS LIVE · ${widget.viewerCount}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: 0.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _error != null
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_error!, textAlign: TextAlign.center),
                                TextButton(onPressed: _load, child: const Text('Retry')),
                              ],
                            ),
                          )
                        : ListView(
                            controller: scroll,
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            children: [
                              const Text('CO-HOSTS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              if (_cohosts.docs.isEmpty)
                                Text(
                                  'No co-hosts yet · host ${_cohosts.hostEarningsPercent}%',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                )
                              else ...[
                                Text(
                                  'Host keeps ${_cohosts.hostEarningsPercent}%',
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                for (final c in _cohosts.docs)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: UserAvatar(radius: 20, imageUrl: c.avatarUrl),
                                    title: Text(c.label),
                                    subtitle: c.username == null ? null : Text('@${c.username}'),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (c.earningsSplitPercent != null)
                                          Container(
                                            margin: const EdgeInsets.only(right: 8),
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${c.earningsSplitPercent}%',
                                              style: const TextStyle(
                                                color: Color(0xFF1DB954),
                                                fontWeight: FontWeight.w800,
                                                fontSize: 12,
                                              ),
                                            ),
                                          ),
                                        TextButton(
                                          onPressed: _busyId == 'cohost_${c.userId}' ? null : () => _removeCohost(c),
                                          child: _busyId == 'cohost_${c.userId}'
                                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                              : const Text('Remove', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w700)),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                              const SizedBox(height: 20),
                              const Text('INVITED VIEWERS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              if (_invites.isEmpty)
                                Text('No invites sent yet', style: TextStyle(color: Colors.grey.shade600, fontSize: 14))
                              else
                                for (final invite in _invites)
                                  ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: UserAvatar(radius: 20, imageUrl: invite.inviteeAvatarUrl),
                                    title: Text(invite.inviteeLabel),
                                    subtitle: Text(
                                      invite.isAccepted
                                          ? (invite.isCohostRole
                                              ? 'Joined · Co-host${invite.earningsSplitPercent != null ? ' · ${invite.earningsSplitPercent}%' : ''}'
                                              : 'Joined')
                                          : invite.isCohostRole
                                              ? 'Co-host pending${invite.earningsSplitPercent != null ? ' · ${invite.earningsSplitPercent}%' : ''}'
                                              : (invite.status ?? 'pending'),
                                    ),
                                    trailing: invite.isPending
                                        ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              TextButton(
                                                onPressed: _busyId == 'cancel_${invite.id}' ? null : () => _cancelPending(invite),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: _busyId == invite.id ? null : () => _redial(invite),
                                                child: _busyId == invite.id
                                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                                    : const Text('Redial'),
                                              ),
                                            ],
                                          )
                                        : null,
                                  ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  showLiveInviteSheet(
                                    context,
                                    streamId: widget.streamId,
                                    allowCohost: widget.allowCohost,
                                    maxCohosts: _cohosts.maxCohosts,
                                    remainingCohostSlots: (_cohosts.maxCohosts - _cohosts.docs.length).clamp(0, _cohosts.maxCohosts),
                                  );
                                },
                                style: FilledButton.styleFrom(backgroundColor: LiveTheme.purple),
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                label: const Text('Invite people'),
                              ),
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> showLiveGiftHistorySheet(
  BuildContext context, {
  required String streamId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _LiveGiftHistorySheet(streamId: streamId),
  );
}

class _LiveGiftHistorySheet extends StatefulWidget {
  const _LiveGiftHistorySheet({required this.streamId});

  final String streamId;

  @override
  State<_LiveGiftHistorySheet> createState() => _LiveGiftHistorySheetState();
}

class _LiveGiftHistorySheetState extends State<_LiveGiftHistorySheet> {
  final _repo = StreamsRepository();
  List<StreamGiftRecord> _gifts = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final gifts = await _repo.giftHistory(widget.streamId);
      if (!mounted) return;
      setState(() {
        _gifts = gifts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Gift history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : _gifts.isEmpty
                        ? const Center(child: Text('No gifts yet'))
                        : ListView.separated(
                            controller: scroll,
                            itemCount: _gifts.length,
                            separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                            itemBuilder: (_, i) {
                              final gift = _gifts[i];
                              return ListTile(
                                leading: gift.iconUrl == null
                                    ? const Icon(Icons.card_giftcard_rounded)
                                    : CircleAvatar(backgroundImage: NetworkImage(gift.iconUrl!)),
                                title: Text(gift.giftName ?? 'Gift'),
                                subtitle: Text(gift.senderName ?? 'Viewer'),
                                trailing: Text('x${gift.quantity}'),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}
