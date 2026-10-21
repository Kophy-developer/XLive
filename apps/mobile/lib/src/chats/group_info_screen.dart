import 'package:flutter/material.dart';

import '../../core/network/api_friendly_messages.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/groups/groups_repository.dart';
import 'chat_theme.dart';
import 'group_chat_screen.dart';
import 'group_dialogs_sheets.dart';

class GroupInfoArgs {
  const GroupInfoArgs({
    required this.groupId,
    required this.groupName,
    this.avatarUrl = '',
    this.memberCount = 0,
  });

  final String groupId;
  final String groupName;
  final String avatarUrl;
  final int memberCount;
}

Future<bool?> openGroupInfoScreen(
  BuildContext context, {
  required String? groupId,
  required String groupName,
  String avatarUrl = '',
  int memberCount = 0,
}) {
  final id = groupId?.trim() ?? '';
  if (id.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group details unavailable.')),
    );
    return Future.value();
  }
  return Navigator.push<bool>(
    context,
    MaterialPageRoute<bool>(
      builder: (_) => GroupInfoScreen(
        args: GroupInfoArgs(
          groupId: id,
          groupName: groupName,
          avatarUrl: avatarUrl,
          memberCount: memberCount,
        ),
      ),
    ),
  );
}

class GroupInfoScreen extends StatefulWidget {
  const GroupInfoScreen({super.key, required this.args});

  final GroupInfoArgs args;

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final _groupsRepo = GroupsRepository();
  GroupSummary? _group;
  bool _loading = true;
  bool _joining = false;
  bool _didJoin = false;
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
      final group = await _groupsRepo.getGroup(widget.args.groupId);
      if (!mounted) return;
      setState(() {
        _group = group;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load group details.';
      });
    }
  }

  String get _name => _group?.name.trim().isNotEmpty == true ? _group!.name : widget.args.groupName;

  String get _iconUrl {
    final fromApi = _group?.iconUrl?.trim() ?? '';
    if (fromApi.isNotEmpty) return fromApi;
    return widget.args.avatarUrl;
  }

  String get _about {
    final text = _group?.description?.trim() ?? '';
    return text.isEmpty ? 'No description yet.' : text;
  }

  int get _memberCount => _group?.memberCount ?? widget.args.memberCount;

  int get _onlineCount => _group?.onlineCount ?? 0;

  bool get _isMember => _group?.isMember ?? false;

  bool get _canJoin {
    if (_isMember) return false;
    final policy = (_group?.joinPolicy ?? 'everyone').toLowerCase();
    return policy != 'invite_only';
  }

  String? get _createdLabel {
    final date = _group?.createdAt;
    if (date == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  void _popWithResult() {
    Navigator.pop(context, _didJoin);
  }

  Future<void> _openChat() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => GroupChatScreen(
          groupId: widget.args.groupId,
          groupName: _name,
          avatarUrl: _iconUrl,
          followers: _memberCount,
          showWelcome: _didJoin,
        ),
      ),
    );
  }

  Future<void> _joinGroup() async {
    if (_joining || _isMember || !_canJoin) return;
    await showJoinGroupSheet(
      context,
      groupName: _name,
      onJoin: () async {
        setState(() => _joining = true);
        try {
          final joined = await _groupsRepo.joinGroup(widget.args.groupId);
          await XLiveSocketClient.instance.joinGroup(widget.args.groupId);
          if (!mounted) return;
          setState(() {
            _group = joined;
            _didJoin = true;
            _joining = false;
          });
        } catch (e) {
          if (!mounted) rethrow;
          setState(() => _joining = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyApiMessage(e))),
          );
          rethrow;
        }
      },
    );
  }

  Widget _bottomAction() {
    if (_loading || _error != null) return const SizedBox.shrink();

    if (_isMember) {
      return _ActionBar(
        child: FilledButton(
          onPressed: _openChat,
          style: FilledButton.styleFrom(
            backgroundColor: ChatTheme.purple,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            elevation: 0,
          ),
          child: const Text('Open chat', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
      );
    }

    if (!_canJoin) {
      return _ActionBar(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'This group is invite only. Ask an admin for an invite to join.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.35, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
          ),
        ),
      );
    }

    return _ActionBar(
      child: FilledButton(
        onPressed: _joining ? null : _joinGroup,
        style: FilledButton.styleFrom(
          backgroundColor: ChatTheme.purple,
          foregroundColor: Colors.white,
          disabledBackgroundColor: ChatTheme.purple.withValues(alpha: 0.55),
          minimumSize: const Size.fromHeight(52),
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: _joining
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
              )
            : const Text('Join group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final joinPolicy = _group?.joinPolicyLabel ?? 'Public';
    final isMember = _isMember;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _popWithResult();
      },
      child: Scaffold(
      backgroundColor: ChatTheme.chatBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ChatTheme.purple))
          : Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                    slivers: [
                      if (_error != null)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                                  const SizedBox(height: 12),
                                  TextButton(onPressed: _load, child: const Text('Retry')),
                                  TextButton(onPressed: _popWithResult, child: const Text('Back')),
                                ],
                              ),
                            ),
                          ),
                        )
                      else ...[
                        SliverToBoxAdapter(
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                decoration: const BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
                                  ),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(28),
                                    bottomRight: Radius.circular(28),
                                  ),
                                ),
                                child: SafeArea(
                                  bottom: false,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: IconButton(
                                        onPressed: _popWithResult,
                                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: const Offset(0, -44),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color: ChatTheme.purple.withValues(alpha: 0.25),
                                            blurRadius: 24,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: GroupAvatar(radius: 48, imageUrl: _iconUrl.isEmpty ? null : _iconUrl),
                                    ),
                                    const SizedBox(height: 14),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Text(
                                        _name,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ChatTheme.black),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: [
                                        _InfoBadge(label: joinPolicy, tone: _InfoBadgeTone.purple),
                                        if (isMember) const _InfoBadge(label: 'Joined', tone: _InfoBadgeTone.green),
                                      ],
                                    ),
                                    const SizedBox(height: 18),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: _InfoStatTile(
                                              icon: Icons.circle,
                                              iconColor: const Color(0xFF22C55E),
                                              label: 'Online',
                                              value: '$_onlineCount',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _InfoStatTile(
                                              icon: Icons.groups_rounded,
                                              iconColor: ChatTheme.purple,
                                              label: 'Members',
                                              value: '$_memberCount',
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _InfoStatTile(
                                              icon: Icons.calendar_today_rounded,
                                              iconColor: const Color(0xFF6366F1),
                                              label: 'Created',
                                              value: _createdLabel ?? '—',
                                              compact: true,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + bottomInset),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: ChatTheme.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.03),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('About', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ChatTheme.black)),
                                  const SizedBox(height: 10),
                                  Text(
                                    _about,
                                    style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey.shade800),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _bottomAction(),
              ],
            ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: child,
        ),
      ),
    );
  }
}

enum _InfoBadgeTone { purple, green }

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({required this.label, required this.tone});

  final String label;
  final _InfoBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final bg = tone == _InfoBadgeTone.purple ? ChatTheme.purple.withValues(alpha: 0.12) : const Color(0xFFDCFCE7);
    final fg = tone == _InfoBadgeTone.purple ? ChatTheme.purpleDeep : const Color(0xFF15803D);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _InfoStatTile extends StatelessWidget {
  const _InfoStatTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.compact = false,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: ChatTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Icon(icon, size: compact ? 16 : 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: compact ? 13 : 18, fontWeight: FontWeight.w800, color: ChatTheme.black),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}
