import 'package:flutter/material.dart';

Future<String?> showEmojiReactionPicker(BuildContext context) {
  const emojis = [
    '❤️', '👋', '🙏', '🤣',
    '👀', '😍', '👍', '👎',
    '🙌', '‼️', '🎉', '🫠',
    '💯', '🌶️', '💦', '🚩',
    '❌', '😠', '😱', '🙄',
    '💅', '👱‍♀️', '🔥', '🌊',
    '🤑', '😃', '🤔', '🥲',
  ];

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.paddingOf(ctx).bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(100))),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 1),
            itemCount: emojis.length,
            itemBuilder: (_, i) {
              final e = emojis[i];
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.pop(ctx, e),
                  borderRadius: BorderRadius.circular(12),
                  child: Center(child: Text(e, style: const TextStyle(fontSize: 28))),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}
