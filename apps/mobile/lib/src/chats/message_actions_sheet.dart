import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'chat_theme.dart';

enum MessageAction { reply, forward, react, copy, translate, edit, delete }

Future<MessageAction?> showMessageActionsSheet(
  BuildContext context, {
  bool canEdit = false,
  bool canDelete = false,
  bool canCopy = true,
  bool canTranslate = false,
  bool canReply = true,
  bool canForward = true,
}) {
  return showModalBottomSheet<MessageAction>(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 8),
          if (canReply)
            ListTile(
              leading: const Icon(Icons.reply_rounded, color: ChatTheme.purple),
              title: const Text('Reply'),
              onTap: () => Navigator.pop(context, MessageAction.reply),
            ),
          if (canForward)
            ListTile(
              leading: const Icon(Icons.shortcut_rounded, color: ChatTheme.black),
              title: const Text('Forward'),
              onTap: () => Navigator.pop(context, MessageAction.forward),
            ),
          ListTile(
            leading: const Icon(Icons.add_reaction_outlined, color: ChatTheme.purple),
            title: const Text('React'),
            onTap: () => Navigator.pop(context, MessageAction.react),
          ),
          if (canCopy)
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: ChatTheme.black),
              title: const Text('Copy'),
              onTap: () => Navigator.pop(context, MessageAction.copy),
            ),
          if (canTranslate)
            ListTile(
              leading: const Icon(Icons.translate_rounded, color: ChatTheme.black),
              title: const Text('Translate'),
              onTap: () => Navigator.pop(context, MessageAction.translate),
            ),
          if (canEdit)
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: ChatTheme.black),
              title: const Text('Edit'),
              onTap: () => Navigator.pop(context, MessageAction.edit),
            ),
          if (canDelete)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935)),
              title: const Text('Delete', style: TextStyle(color: Color(0xFFE53935))),
              onTap: () => Navigator.pop(context, MessageAction.delete),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

Future<void> copyMessageText(BuildContext context, String text) async {
  if (text.trim().isEmpty) return;
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Copied')));
}

Future<String?> showEditMessageDialog(BuildContext context, {required String initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Edit message', style: TextStyle(fontWeight: FontWeight.w800)),
      content: TextField(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 6,
        decoration: InputDecoration(
          hintText: 'Message',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: ChatTheme.purple, width: 1.4)),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: ChatTheme.purple,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: const Text('Save'),
        ),
      ],
    ),
  );
}

Future<bool?> confirmDeleteMessage(BuildContext context) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete message?', style: TextStyle(fontWeight: FontWeight.w800)),
      content: const Text('This message will be removed from the conversation.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFE53935),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}
