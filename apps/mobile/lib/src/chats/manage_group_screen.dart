import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../features/groups/groups_repository.dart';
import '../../features/groups/models/group_models.dart';
import '../../core/widgets/user_avatar.dart';
import 'chat_theme.dart';
import 'select_contact_screen.dart';
import '../../core/network/api_friendly_messages.dart';

class ManageGroupArgs {
  const ManageGroupArgs({required this.groupId});

  final String groupId;
}

class ManageMemberEntry {
  const ManageMemberEntry({
    required this.userId,
    required this.name,
    required this.avatarUrl,
    required this.pending,
    this.role,
  });

  final String userId;
  final String name;
  final String avatarUrl;
  final bool pending;
  final String? role;
}

class ManageGroupScreen extends StatefulWidget {
  const ManageGroupScreen({super.key, this.args});

  final ManageGroupArgs? args;

  @override
  State<ManageGroupScreen> createState() => _ManageGroupScreenState();
}

class _ManageGroupScreenState extends State<ManageGroupScreen> {
  final _groupsRepo = GroupsRepository();
  final _search = TextEditingController();
  int _tab = 0;
  List<ManageMemberEntry> _all = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    setState(() => _loading = true);
    try {
      final members = await _groupsRepo.listMembers(groupId);
      if (!mounted) return;
      setState(() {
        _all = members.map(_mapMember).toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  ManageMemberEntry _mapMember(GroupMember m) {
    final pending = m.role == 'pending' || m.role == 'invited';
    return ManageMemberEntry(
      userId: m.id,
      name: m.name,
      avatarUrl: m.avatarUrl ?? '',
      pending: pending,
      role: m.role,
    );
  }

  List<ManageMemberEntry> get _visible {
    final q = _search.text.trim().toLowerCase();
    var list = _all;
    if (_tab == 1) {
      list = list.where((e) => e.pending).toList();
    } else if (_tab == 2) {
      list = list.where((e) => !e.pending).toList();
    }
    if (q.isEmpty) return list;
    return list.where((e) => e.name.toLowerCase().contains(q)).toList();
  }

  Future<void> _removeMember(ManageMemberEntry entry) async {
    final groupId = widget.args?.groupId;
    if (groupId == null) return;
    try {
      await _groupsRepo.removeMember(groupId, entry.userId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _confirmMember(ManageMemberEntry entry) async {
    final groupId = widget.args?.groupId;
    if (groupId == null) return;
    try {
      await _groupsRepo.updateMemberRole(groupId, entry.userId, role: 'member');
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _transferOwnership(ManageMemberEntry entry) async {
    final groupId = widget.args?.groupId;
    if (groupId == null) return;
    try {
      await _groupsRepo.transferOwnership(groupId, userId: entry.userId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ownership transferred to ${entry.name}')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _addMember() async {
    final picked = await Navigator.push<(String, String, String)?>(
      context,
      MaterialPageRoute<(String, String, String)?>(builder: (_) => const SelectContactScreen(title: 'Add member')),
    );
    final groupId = widget.args?.groupId;
    if (!mounted || picked == null || groupId == null) return;
    try {
      await _groupsRepo.addMember(groupId, picked.$1);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthSession.instance.user?.id;
    final amOwner = _all.any((e) => e.role == 'owner' && e.userId == me);
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 4, 8),
              child: Row(
                children: [
                  const Expanded(child: Center(child: Text('Manage Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
                  if (amOwner) IconButton(onPressed: _addMember, icon: const Icon(Icons.person_add_outlined)),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search',
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  _ManageTab(label: 'All', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
                  _ManageTab(label: 'New', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
                  _ManageTab(label: 'Members', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade300),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _visible.length,
                      itemBuilder: (_, i) {
                        final e = _visible[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              UserAvatar(radius: 24, imageUrl: e.avatarUrl.isEmpty ? null : e.avatarUrl),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                    if (e.role == 'owner') Text('Owner', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              if (amOwner && e.pending)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    FilledButton(
                                      onPressed: () => _confirmMember(e),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: ChatTheme.purple,
                                        foregroundColor: Colors.white,
                                        shape: const StadiumBorder(),
                                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                      ),
                                      child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                                    ),
                                    const SizedBox(width: 8),
                                    Material(
                                      color: Colors.grey.shade200,
                                      shape: const CircleBorder(),
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: () => _removeMember(e),
                                        child: const SizedBox(width: 40, height: 40, child: Icon(Icons.close_rounded, size: 20)),
                                      ),
                                    ),
                                  ],
                                )
                              else if (amOwner && e.userId != me) ...[
                                OutlinedButton(
                                  onPressed: () => _removeMember(e),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: ChatTheme.black,
                                    side: BorderSide(color: Colors.grey.shade400),
                                    shape: const StadiumBorder(),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  ),
                                  child: const Text('Remove', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  onPressed: () => _transferOwnership(e),
                                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                                  tooltip: 'Transfer ownership',
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManageTab extends StatelessWidget {
  const _ManageTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 15, fontWeight: selected ? FontWeight.w800 : FontWeight.w500, color: selected ? ChatTheme.black : ChatTheme.grey)),
            const SizedBox(height: 8),
            if (selected)
              Container(height: 3, width: 28, decoration: const BoxDecoration(color: ChatTheme.black, borderRadius: BorderRadius.vertical(top: Radius.circular(2))))
            else
              const SizedBox(height: 3),
          ],
        ),
      ),
    );
  }
}
