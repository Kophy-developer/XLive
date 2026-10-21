import 'package:flutter/material.dart';

import '../../core/network/api_friendly_messages.dart';
import '../../features/chats/chats_repository.dart';
import '../../features/users/users_repository.dart';
import '../../core/widgets/user_avatar.dart';
import 'dm_chat_screen.dart';

class SelectContactScreen extends StatefulWidget {
  const SelectContactScreen({super.key, this.title = 'Select contact', this.trailingChatIcon = false});

  final String title;
  final bool trailingChatIcon;

  @override
  State<SelectContactScreen> createState() => _SelectContactScreenState();
}

class _ContactRow {
  const _ContactRow({required this.userId, required this.name, required this.avatarUrl});

  final String userId;
  final String name;
  final String avatarUrl;
}

class _SelectContactScreenState extends State<SelectContactScreen> {
  final _search = TextEditingController();
  final _usersRepo = UsersRepository();
  final _chatsRepo = ChatsRepository();
  final _settings = SettingsRepository();
  List<_ContactRow> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().length < 2) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final users = await _usersRepo.searchUsers(q.trim());
      if (!mounted) return;
      setState(() {
        _results = users
            .map((u) => _ContactRow(
                  userId: u.id,
                  name: u.displayName ?? u.username ?? 'User',
                  avatarUrl: u.avatarUrl ?? '',
                ))
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  Future<void> _openDm(_ContactRow contact) async {
    try {
      if (await _settings.isUserBlocked(contact.userId)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('This user is blocked. You cannot chat with them.')),
        );
        return;
      }
      final thread = await _chatsRepo.createDm(contact.userId);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DmChatScreen(
            chatId: thread.id,
            peerName: contact.name,
            peerAvatarUrl: contact.avatarUrl,
            peerUserId: contact.userId,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  Expanded(child: Center(child: Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                onChanged: _runSearch,
                decoration: InputDecoration(
                  hintText: 'Search users',
                  prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade600),
                  filled: true,
                  fillColor: const Color(0xFFF2F2F2),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
            Divider(height: 1, color: Colors.grey.shade200),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _results.isEmpty
                      ? Center(child: Text('Search for someone to message', style: TextStyle(color: Colors.grey.shade600)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final c = _results[i];
                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (widget.trailingChatIcon) {
                                    _openDm(c);
                                  } else {
                                    Navigator.pop(context, (c.userId, c.name, c.avatarUrl));
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  child: Row(
                                    children: [
                                      UserAvatar(radius: 26, imageUrl: c.avatarUrl.isEmpty ? null : c.avatarUrl),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(c.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ),
                                      if (widget.trailingChatIcon)
                                        Icon(Icons.chat_bubble_outline_rounded, color: Colors.grey.shade800, size: 22),
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
      ),
    );
  }
}

Future<void> openChatSearchPicker(BuildContext context) {
  return Navigator.push<void>(
    context,
    MaterialPageRoute<void>(builder: (_) => const SelectContactScreen(title: 'Search', trailingChatIcon: true)),
  );
}
