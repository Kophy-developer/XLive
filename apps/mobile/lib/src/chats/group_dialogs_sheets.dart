import 'package:flutter/material.dart';

import '../../core/widgets/user_avatar.dart';
import '../../features/chats/models/chat_api_models.dart';
import '../../features/groups/groups_repository.dart';
import 'chat_theme.dart';
import '../../core/network/api_friendly_messages.dart';

Future<void> showAddGroupChoiceSheet(BuildContext context, {required VoidCallback onCreateNew, required VoidCallback onJoinExisting}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _AddGroupChoiceSheet(onCreateNew: onCreateNew, onJoinExisting: onJoinExisting),
  );
}

class _AddGroupChoiceSheet extends StatelessWidget {
  const _AddGroupChoiceSheet({required this.onCreateNew, required this.onJoinExisting});

  final VoidCallback onCreateNew;
  final VoidCallback onJoinExisting;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: ChatTheme.surface, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.groups_2_outlined, size: 32, color: ChatTheme.black),
          ),
          const SizedBox(height: 20),
          const Text('Add a Group', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: ChatTheme.black, letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Text('Choose what you would like to do below', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Colors.grey.shade600, height: 1.35)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(context);
                onCreateNew();
              },
              style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: StadiumBorder(), elevation: 0),
              child: const Text('Create a new group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                onJoinExisting();
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: ChatTheme.black,
                side: const BorderSide(color: ChatTheme.border),
                shape: const StadiumBorder(),
              ),
              child: const Text('Join an existing group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showCreateGroupSheet(BuildContext context, {required void Function(GroupSummary? group) onCreated}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _CreateGroupSheet(onCreated: onCreated),
  );
}

class _CreateGroupSheet extends StatefulWidget {
  const _CreateGroupSheet({required this.onCreated});

  final void Function(GroupSummary? group) onCreated;

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _groupsRepo = GroupsRepository();
  final _name = TextEditingController();
  final _description = TextEditingController();
  int _joinRule = 0;
  bool _allowChat = true;
  bool _creating = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    if (name.isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      final group = await _groupsRepo.createGroup(
        name: name,
        description: _description.text.trim(),
        joinPolicy: _joinRule == 0 ? 'everyone' : 'followers',
        membersCanChat: _allowChat,
      );
      if (!mounted) return;
      Navigator.pop(context);
      widget.onCreated(group);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(20, 8, 12, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const SizedBox(width: 40),
                const Expanded(child: Center(child: Text('Create a Group', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
              ],
            ),
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(shape: BoxShape.circle, color: ChatTheme.segmentBg, border: Border.all(color: ChatTheme.border)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_camera_outlined, color: Colors.grey.shade500, size: 28),
                    const SizedBox(height: 6),
                    Text('Upload Cover', style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              decoration: InputDecoration(
                hintText: 'Name your group…',
                filled: true,
                fillColor: ChatTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Add a description',
                filled: true,
                fillColor: ChatTheme.surface,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 24),
            Text('SETTINGS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade600, letterSpacing: 0.6)),
            const SizedBox(height: 12),
            const Text('Who can join the group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                _RadioChip(label: 'Everyone', selected: _joinRule == 0, onTap: () => setState(() => _joinRule = 0)),
                const SizedBox(width: 20),
                _RadioChip(label: 'My Subscriber', selected: _joinRule == 1, onTap: () => setState(() => _joinRule = 1)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Allow members to chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(
                        'This allows users to comment and send messages in this group',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                      ),
                    ],
                  ),
                ),
                Switch(value: _allowChat, onChanged: (v) => setState(() => _allowChat = v), activeTrackColor: ChatTheme.purple, thumbColor: const WidgetStatePropertyAll(Colors.white)),
              ],
            ),
            const SizedBox(height: 28),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: _creating ? null : _create,
                style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: StadiumBorder()),
                child: Text(_creating ? 'Creating…' : 'Create', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RadioChip extends StatelessWidget {
  const _RadioChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? ChatTheme.purple : Colors.transparent,
              border: Border.all(color: selected ? ChatTheme.purple : ChatTheme.border, width: 1.5),
            ),
            child: selected ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.white)) : null,
          ),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

Future<void> showGroupSettingsSheet(
  BuildContext context, {
  required String groupId,
  required String joinPolicy,
  required bool membersCanChat,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _GroupSettingsSheet(
      groupId: groupId,
      joinPolicy: joinPolicy,
      membersCanChat: membersCanChat,
    ),
  );
}

class _GroupSettingsSheet extends StatefulWidget {
  const _GroupSettingsSheet({
    required this.groupId,
    required this.joinPolicy,
    required this.membersCanChat,
  });

  final String groupId;
  final String joinPolicy;
  final bool membersCanChat;

  @override
  State<_GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<_GroupSettingsSheet> {
  final _groupsRepo = GroupsRepository();
  late int _joinRule;
  late bool _allowChat;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _joinRule = widget.joinPolicy == 'followers' || widget.joinPolicy == 'subscribers' || widget.joinPolicy == 'invite_only' ? 1 : 0;
    _allowChat = widget.membersCanChat;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await _groupsRepo.updateGroup(
        widget.groupId,
        joinPolicy: _joinRule == 0 ? 'everyone' : 'followers',
        membersCanChat: _allowChat,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 12, 16, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(width: 40, height: 4, alignment: Alignment.center, child: Container(decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100)))),
          Row(
            children: [
              const Expanded(child: Center(child: Text('Setting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Who can join the group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Row(
            children: [
              _RadioChip(label: 'Everyone', selected: _joinRule == 0, onTap: () => setState(() => _joinRule = 0)),
              const SizedBox(width: 20),
              _RadioChip(label: 'My Subscriber', selected: _joinRule == 1, onTap: () => setState(() => _joinRule = 1)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Allow members to chat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    Text(
                      'This allows users to comment, react and send messages in this group',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                    ),
                  ],
                ),
              ),
              Switch(value: _allowChat, onChanged: (v) => setState(() => _allowChat = v), activeTrackColor: ChatTheme.purple, thumbColor: const WidgetStatePropertyAll(Colors.white)),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: const StadiumBorder()),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showJoinGroupSheet(
  BuildContext context, {
  required String groupName,
  required Future<void> Function() onJoin,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _JoinGroupSheet(groupName: groupName, onJoin: onJoin),
  );
}

class _JoinGroupSheet extends StatefulWidget {
  const _JoinGroupSheet({required this.groupName, required this.onJoin});

  final String groupName;
  final Future<void> Function() onJoin;

  @override
  State<_JoinGroupSheet> createState() => _JoinGroupSheetState();
}

class _JoinGroupSheetState extends State<_JoinGroupSheet> {
  bool _joining = false;

  Future<void> _confirmJoin() async {
    if (_joining) return;
    setState(() => _joining = true);
    try {
      await widget.onJoin();
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 24),
          const GroupAvatar(radius: 44),
          const SizedBox(height: 20),
          Text('Join ${widget.groupName}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          Text('Please note you need to be 18+ to join this group', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey.shade600, height: 1.4)),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _joining ? null : _confirmJoin,
              style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: StadiumBorder()),
              child: _joining
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Join group', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _joining ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(foregroundColor: ChatTheme.black, side: const BorderSide(color: ChatTheme.border), shape: const StadiumBorder()),
              child: const Text('No, Cancel', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showLeaveGroupDialog(BuildContext context, {required String groupName}) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Leave Group', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text('Are you sure you want to leave $groupName?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: StadiumBorder()),
            child: const Text('Leave Group', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(shape: const StadiumBorder(), side: const BorderSide(color: ChatTheme.border)),
            child: const Text('No, cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );
}

Future<String?> showEditMessageSheet(
  BuildContext context, {
  required String initialText,
  String hintText = 'Message',
}) {
  final ctrl = TextEditingController(text: initialText);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final pad = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.only(bottom: pad),
        child: Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(child: Center(child: Text('Edit Message', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)))),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: Icon(Icons.close_rounded, color: Colors.grey.shade600)),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: ctrl,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: hintText,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(999), borderSide: BorderSide(color: Colors.grey.shade300)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: ChatTheme.purple,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(ctx, ctrl.text.trim()),
                      child: const SizedBox(width: 44, height: 44, child: Icon(Icons.send_rounded, color: Colors.white, size: 20)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  ).whenComplete(() => ctrl.dispose());
}

Future<bool?> showDeleteMessageDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Delete Message', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text('Are you sure you want to permanently delete this message?', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: ChatTheme.purple, foregroundColor: Colors.white, shape: StadiumBorder()),
            child: const Text('Delete Message', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: OutlinedButton.styleFrom(shape: const StadiumBorder(), side: const BorderSide(color: ChatTheme.border)),
            child: const Text('No, cancel', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    ),
  );
}
