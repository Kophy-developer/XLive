import 'package:flutter/material.dart';

import '../../features/chats/models/chat_api_models.dart';
import '../../features/groups/groups_repository.dart';
import '../../features/groups/models/group_models.dart';
import '../../core/widgets/user_avatar.dart';
import 'chat_theme.dart';
import 'edit_group_details_screen.dart';
import 'group_dialogs_sheets.dart';
import 'manage_group_screen.dart';

class GroupPreviewScreen extends StatefulWidget {
  const GroupPreviewScreen({
    super.key,
    required this.groupName,
    required this.avatarUrl,
    required this.followers,
    this.groupId,
  });

  final String groupName;
  final String avatarUrl;
  final int followers;
  final String? groupId;

  @override
  State<GroupPreviewScreen> createState() => _GroupPreviewScreenState();
}

class _GroupPreviewScreenState extends State<GroupPreviewScreen> {
  final _groupsRepo = GroupsRepository();
  GroupSummary? _group;
  List<GroupMember> _members = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final groupId = widget.groupId;
    if (groupId == null || groupId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _groupsRepo.getGroup(groupId),
        _groupsRepo.listMembers(groupId, limit: 20),
      ]);
      if (!mounted) return;
      setState(() {
        _group = results[0] as GroupSummary;
        _members = results[1] as List<GroupMember>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  GroupSummary? get _g => _group;

  bool get _isOwner => _g?.isOwner ?? false;

  int get _memberCount => _g?.memberCount ?? widget.followers;

  int get _onlineCount {
    final fromApi = _g?.onlineCount ?? 0;
    if (fromApi > 0) return fromApi;
    return _members.where((m) => m.isOnline).length;
  }

  String get _description {
    final text = _g?.description?.trim() ?? '';
    return text.isEmpty ? 'No description yet.' : text;
  }

  String? get _createdLabel {
    final date = _g?.createdAt;
    if (date == null) return null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final local = date.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String get _iconUrl {
    final fromApi = _g?.iconUrl?.trim() ?? '';
    if (fromApi.isNotEmpty) return fromApi;
    return widget.avatarUrl;
  }

  @override
  Widget build(BuildContext context) {
    final groupId = widget.groupId;
    final group = _g;
    return Scaffold(
      backgroundColor: ChatTheme.chatBg,
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: ChatTheme.purple))
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _GroupProfileHero(
                    groupName: group?.name ?? widget.groupName,
                    iconUrl: _iconUrl,
                    joinPolicyLabel: group?.joinPolicyLabel ?? 'Public',
                    roleLabel: group?.roleLabel ?? 'Member',
                    isMember: group?.isMember ?? true,
                    onlineCount: _onlineCount,
                    memberCount: _memberCount,
                    createdLabel: _createdLabel,
                    membersCanChat: group?.membersCanChat ?? true,
                    onBack: () => Navigator.pop(context),
                    onMenu: _isOwner
                        ? (value) => _handleOwnerMenu(value, groupId, group)
                        : null,
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionCard(
                          title: 'About',
                          child: Text(
                            _description,
                            style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey.shade800),
                          ),
                        ),
                        const SizedBox(height: 14),
                        _SectionCard(
                          title: 'Members',
                          trailing: _members.isNotEmpty
                              ? TextButton(
                                  onPressed: groupId == null || groupId.isEmpty
                                      ? null
                                      : () => Navigator.push<void>(
                                            context,
                                            MaterialPageRoute<void>(
                                              builder: (_) => ManageGroupScreen(args: ManageGroupArgs(groupId: groupId)),
                                            ),
                                          ).then((_) => _load()),
                                  child: const Text('See all'),
                                )
                              : null,
                          child: _members.isEmpty
                              ? Text('No members to show yet.', style: TextStyle(color: Colors.grey.shade600))
                              : Column(
                                  children: [
                                    SizedBox(
                                      height: 72,
                                      child: ListView.separated(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _members.length.clamp(0, 12),
                                        separatorBuilder: (_, index) => const SizedBox(width: 12),
                                        itemBuilder: (_, i) {
                                          final m = _members[i];
                                          return _MemberChip(member: m);
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    ..._members.take(4).map(
                                          (m) => Padding(
                                            padding: const EdgeInsets.only(bottom: 10),
                                            child: _MemberRow(member: m),
                                          ),
                                        ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),
                        if (_isOwner)
                          SizedBox(
                            height: 52,
                            child: FilledButton.icon(
                              onPressed: groupId == null || groupId.isEmpty
                                  ? null
                                  : () => Navigator.push<void>(
                                        context,
                                        MaterialPageRoute<void>(
                                          builder: (_) => ManageGroupScreen(args: ManageGroupArgs(groupId: groupId)),
                                        ),
                                      ).then((_) => _load()),
                              icon: const Icon(Icons.group_rounded, size: 20),
                              label: const Text('Manage members'),
                              style: FilledButton.styleFrom(
                                backgroundColor: ChatTheme.purple,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _handleOwnerMenu(String value, String? groupId, GroupSummary? group) async {
    if (value == 'edit') {
      if (groupId == null || groupId.isEmpty) return;
      final saved = await Navigator.push<bool>(
        context,
        MaterialPageRoute<bool>(builder: (_) => EditGroupDetailsScreen(args: EditGroupDetailsArgs(groupId: groupId))),
      );
      if (saved == true) _load();
    } else if (value == 'settings') {
      if (groupId == null || groupId.isEmpty || group == null) return;
      await showGroupSettingsSheet(
        context,
        groupId: groupId,
        joinPolicy: group.joinPolicy,
        membersCanChat: group.membersCanChat,
      );
      _load();
    } else if (value == 'delete') {
      final leave = await showLeaveGroupDialog(context, groupName: widget.groupName);
      if (!mounted || leave != true) return;
      Navigator.pop(context);
    }
  }
}

class _GroupProfileHero extends StatelessWidget {
  const _GroupProfileHero({
    required this.groupName,
    required this.iconUrl,
    required this.joinPolicyLabel,
    required this.roleLabel,
    required this.isMember,
    required this.onlineCount,
    required this.memberCount,
    required this.createdLabel,
    required this.membersCanChat,
    required this.onBack,
    this.onMenu,
  });

  final String groupName;
  final String iconUrl;
  final String joinPolicyLabel;
  final String roleLabel;
  final bool isMember;
  final int onlineCount;
  final int memberCount;
  final String? createdLabel;
  final bool membersCanChat;
  final VoidCallback onBack;
  final ValueChanged<String>? onMenu;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF7C3AED), Color(0xFFDB2777)],
            ),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  ),
                  const Spacer(),
                  if (onMenu != null)
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                      onSelected: onMenu,
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit details')),
                        PopupMenuItem(value: 'settings', child: Text('Settings')),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                ],
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
                  boxShadow: [BoxShadow(color: ChatTheme.purple.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 8))],
                ),
                child: GroupAvatar(radius: 48, imageUrl: iconUrl.isEmpty ? null : iconUrl),
              ),
              const SizedBox(height: 14),
              Text(groupName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: ChatTheme.black)),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(label: joinPolicyLabel, tone: _BadgeTone.purple),
                  if (isMember) _Badge(label: 'Joined', tone: _BadgeTone.green),
                  _Badge(label: roleLabel, tone: _BadgeTone.neutral),
                ],
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(child: _StatTile(icon: Icons.circle, iconColor: const Color(0xFF22C55E), label: 'Online', value: '$onlineCount')),
                    const SizedBox(width: 10),
                    Expanded(child: _StatTile(icon: Icons.groups_rounded, iconColor: ChatTheme.purple, label: 'Members', value: '$memberCount')),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.calendar_today_rounded,
                        iconColor: const Color(0xFF6366F1),
                        label: 'Created',
                        value: createdLabel ?? '—',
                        compact: true,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _InfoChip(
                        icon: membersCanChat ? Icons.chat_bubble_rounded : Icons.chat_bubble_outline_rounded,
                        label: membersCanChat ? 'Members can chat' : 'Chat restricted',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _InfoChip(
                        icon: joinPolicyLabel == 'Public' ? Icons.public_rounded : Icons.lock_rounded,
                        label: joinPolicyLabel,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _BadgeTone { purple, green, neutral }

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.tone});

  final String label;
  final _BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color fg;
    switch (tone) {
      case _BadgeTone.purple:
        bg = ChatTheme.purple.withValues(alpha: 0.12);
        fg = ChatTheme.purpleDeep;
      case _BadgeTone.green:
        bg = const Color(0xFFDCFCE7);
        fg = const Color(0xFF15803D);
      case _BadgeTone.neutral:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
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

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ChatTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: ChatTheme.purple),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: ChatTheme.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ChatTheme.black)),
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            UserAvatar(radius: 26, imageUrl: member.avatarUrl),
            if (member.isOnline)
              Positioned(
                right: -1,
                bottom: -1,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 56,
          child: Text(
            member.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
          ),
        ),
      ],
    );
  }
}

class _MemberRow extends StatelessWidget {
  const _MemberRow({required this.member});

  final GroupMember member;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(radius: 20, imageUrl: member.avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(member.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              if (member.role != null)
                Text(
                  member.role![0].toUpperCase() + member.role!.substring(1),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
            ],
          ),
        ),
        if (member.isOnline)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(999)),
            child: const Text('Online', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF15803D))),
          ),
      ],
    );
  }
}
