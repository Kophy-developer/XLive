import 'package:flutter/material.dart';

import '../../core/socket/xlive_socket_client.dart';
import '../../features/groups/groups_repository.dart';
import '../../core/widgets/user_avatar.dart';
import 'chat_models.dart';
import 'chat_theme.dart';
import 'group_info_screen.dart';
import '../../core/network/api_friendly_messages.dart';

class ExploreGroupsScreen extends StatefulWidget {
  const ExploreGroupsScreen({super.key});

  @override
  State<ExploreGroupsScreen> createState() => _ExploreGroupsScreenState();
}

class _ExploreGroupsScreenState extends State<ExploreGroupsScreen> {
  final _search = TextEditingController();
  final _groupsRepo = GroupsRepository();
  List<ExploreGroupRow> _allGroups = const [];
  final Set<String> _following = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _groupsRepo.discoverGroups(limit: 30);
      final myGroups = await _groupsRepo.listMyGroups(limit: 50);
      if (!mounted) return;
      setState(() {
        _allGroups = groups
            .map((g) => ExploreGroupRow(
                  groupId: g.id,
                  name: g.name,
                  avatarUrl: g.iconUrl ?? '',
                  followers: g.memberCount,
                ))
            .toList();
        _following
          ..clear()
          ..addAll(myGroups.map((g) => g.id));
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

  Future<void> _joinGroup(ExploreGroupRow g) async {
    if (g.groupId == null) return;
    try {
      await _groupsRepo.joinGroup(g.groupId!);
      await XLiveSocketClient.instance.joinGroup(g.groupId!);
      if (!mounted) return;
      setState(() => _following.add(g.groupId!));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    final filtered = q.isEmpty ? _allGroups : _allGroups.where((g) => g.name.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        foregroundColor: ChatTheme.black,
        title: const Text('Groups', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            tooltip: 'Join with code',
            onPressed: () => Navigator.pushNamed(context, '/groups/join-code'),
            icon: const Icon(Icons.qr_code_2_rounded),
          ),
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: ChatTheme.divider),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search',
                prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade500),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          Container(height: 1, color: ChatTheme.divider),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Text('Find groups to join', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey.shade600)),
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
                            TextButton(onPressed: _loadGroups, child: const Text('Retry')),
                          ],
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(child: Text('No groups found', style: TextStyle(color: Colors.grey.shade600)))
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: filtered.length,
                            separatorBuilder: (_, index) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final g = filtered[i];
                              final following = g.groupId != null && _following.contains(g.groupId);
                              return Material(
                                color: Colors.transparent,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: InkWell(
                                          onTap: () async {
                                            final joined = await openGroupInfoScreen(
                                              context,
                                              groupId: g.groupId,
                                              groupName: g.name,
                                              avatarUrl: g.avatarUrl,
                                              memberCount: g.followers,
                                            );
                                            if (!mounted) return;
                                            if (joined == true && g.groupId != null) {
                                              setState(() => _following.add(g.groupId!));
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(12),
                                          child: Row(
                                            children: [
                                              GroupAvatar(radius: 28, imageUrl: g.avatarUrl.isEmpty ? null : g.avatarUrl),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(g.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                                    const SizedBox(height: 4),
                                                    Text('${g.followers} followers', style: const TextStyle(fontSize: 14, color: Color(0xFF8E8E93))),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      OutlinedButton(
                                        onPressed: following ? null : () => _joinGroup(g),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: ChatTheme.black,
                                          backgroundColor: following ? Colors.grey.shade200 : const Color(0xFFF0F0F0),
                                          side: BorderSide.none,
                                          shape: const StadiumBorder(),
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                        ),
                                        child: Text(following ? 'Joined' : 'Join', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ),
                                    ],
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
