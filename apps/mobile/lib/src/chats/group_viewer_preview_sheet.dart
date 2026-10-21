import 'package:flutter/material.dart';

import '../../features/groups/groups_repository.dart';
import '../../core/widgets/user_avatar.dart';
import 'chat_theme.dart';
import 'group_dialogs_sheets.dart';

Future<void> showViewerGroupPreviewSheet(
  BuildContext context, {
  required String groupName,
  required String avatarUrl,
  required int followers,
  String? groupId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ViewerGroupPreviewSheet(
      groupName: groupName,
      avatarUrl: avatarUrl,
      followers: followers,
      groupId: groupId,
    ),
  );
}

class _ViewerGroupPreviewSheet extends StatefulWidget {
  const _ViewerGroupPreviewSheet({
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
  State<_ViewerGroupPreviewSheet> createState() => _ViewerGroupPreviewSheetState();
}

class _ViewerGroupPreviewSheetState extends State<_ViewerGroupPreviewSheet> {
  final _groupsRepo = GroupsRepository();
  String _description = '';
  int _members = 0;

  @override
  void initState() {
    super.initState();
    _members = widget.followers;
    _load();
  }

  Future<void> _load() async {
    final groupId = widget.groupId;
    if (groupId == null || groupId.isEmpty) return;
    try {
      final group = await _groupsRepo.getGroup(groupId);
      if (!mounted) return;
      setState(() {
        _description = group.description?.trim() ?? '';
        _members = group.memberCount;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.62,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100)))),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Center(child: GroupAvatar(radius: 48, imageUrl: widget.avatarUrl.isEmpty ? null : widget.avatarUrl)),
            const SizedBox(height: 14),
            Text(widget.groupName, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('$_members followers', textAlign: TextAlign.center, style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
            const SizedBox(height: 22),
            Center(
              child: _LeaveAction(onTap: () async {
                final ok = await showLeaveGroupDialog(context, groupName: widget.groupName);
                if (ok == true && context.mounted) {
                  Navigator.pop(context);
                }
              }),
            ),
            if (_description.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: ChatTheme.surface, borderRadius: BorderRadius.circular(18)),
                child: Text(
                  _description,
                  style: TextStyle(fontSize: 15, height: 1.45, color: Colors.grey.shade700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LeaveAction extends StatelessWidget {
  const _LeaveAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ChatTheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.logout_rounded, size: 24, color: ChatTheme.black),
              SizedBox(height: 8),
              Text('Leave', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
