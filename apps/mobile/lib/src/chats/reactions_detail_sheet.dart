import 'package:flutter/material.dart';

class ReactionUserRow {
  const ReactionUserRow({required this.name, required this.avatarUrl, required this.emoji});
  final String name;
  final String avatarUrl;
  final String emoji;
}

Future<void> showReactionsDetailSheet(BuildContext context) {
  const rows = [
    ReactionUserRow(name: 'Ricky Doyle', avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200', emoji: '❤️'),
    ReactionUserRow(name: 'Ron Kuhic', avatarUrl: 'https://images.unsplash.com/photo-1472099645785-5658abf4ff4e?w=200', emoji: '😍'),
    ReactionUserRow(name: 'Gregory Haag', avatarUrl: 'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?w=200', emoji: '💯'),
    ReactionUserRow(name: 'Guadalupe Parker', avatarUrl: 'https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200', emoji: '❤️'),
    ReactionUserRow(name: 'Dwight Bednar', avatarUrl: 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=200', emoji: '❤️'),
    ReactionUserRow(name: 'Matt Runte', avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200', emoji: '😍'),
    ReactionUserRow(name: 'Eugene Brown', avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200', emoji: '😍'),
  ];

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.55),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 8),
            child: Row(
              children: [
                const Expanded(child: Center(child: Text('Reactions', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.shade200),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.45),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: rows.length,
              separatorBuilder: (_, index) => SizedBox(height: 1, child: Divider(height: 1, color: Colors.grey.shade100)),
              itemBuilder: (_, i) {
                final r = rows[i];
                return ListTile(
                  leading: CircleAvatar(backgroundImage: NetworkImage(r.avatarUrl)),
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                  trailing: Text(r.emoji, style: const TextStyle(fontSize: 22)),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
