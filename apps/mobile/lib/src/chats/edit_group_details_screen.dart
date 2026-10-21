import 'package:flutter/material.dart';

import '../../core/widgets/user_avatar.dart';
import '../../features/groups/groups_repository.dart';
import 'chat_theme.dart';
import '../../core/network/api_friendly_messages.dart';

class EditGroupDetailsArgs {
  const EditGroupDetailsArgs({required this.groupId});

  final String groupId;
}

class EditGroupDetailsScreen extends StatefulWidget {
  const EditGroupDetailsScreen({super.key, this.args});

  final EditGroupDetailsArgs? args;

  @override
  State<EditGroupDetailsScreen> createState() => _EditGroupDetailsScreenState();
}

class _EditGroupDetailsScreenState extends State<EditGroupDetailsScreen> {
  final _groupsRepo = GroupsRepository();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _avatarUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final group = await _groupsRepo.getGroup(groupId);
      if (!mounted) return;
      setState(() {
        _name.text = group.name;
        _desc.text = group.description ?? '';
        _avatarUrl = group.iconUrl;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final groupId = widget.args?.groupId;
    if (groupId == null || groupId.isEmpty) return;
    setState(() => _saving = true);
    try {
      await _groupsRepo.updateGroup(groupId, name: _name.text.trim(), description: _desc.text.trim());
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: ChatTheme.black,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        title: const Text('Edit group details', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              children: [
                Center(
                  child: GroupAvatar(radius: 56, imageUrl: _avatarUrl),
                ),
                const SizedBox(height: 28),
                Text('Group Name', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                TextField(
                  controller: _name,
                  maxLength: 20,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => Align(
                    alignment: Alignment.centerRight,
                    child: Text('$currentLength/20', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                  decoration: const InputDecoration(border: UnderlineInputBorder(), focusedBorder: UnderlineInputBorder()),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 20),
                Text('Description', style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                TextField(
                  controller: _desc,
                  maxLines: 5,
                  decoration: const InputDecoration(border: UnderlineInputBorder(), focusedBorder: UnderlineInputBorder()),
                  style: const TextStyle(fontSize: 15, height: 1.4),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: const StadiumBorder()),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
            ),
          ),
        ),
      ),
    );
  }
}
