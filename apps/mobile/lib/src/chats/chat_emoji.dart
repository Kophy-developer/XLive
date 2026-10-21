import 'package:flutter/material.dart';

import 'chat_theme.dart';
import 'emoji_catalog.dart';

final RegExp _emojiOnly = RegExp(
  r'^(?:[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}\u{2300}-\u{23FF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}\u{20E3}\u{2122}\u{2139}])+$',
  unicode: true,
);

String? sanitizeEmoji(String value) {
  final t = value.trim();
  if (t.isEmpty || t.runes.length > 8) return null;
  return _emojiOnly.hasMatch(t) ? t : null;
}

const List<String> kChatEmojis = kEmojiSmileysAndEmotion;

const List<String> kChatStickers = [
  '😂', '😍', '🥳', '😎', '🤩', '😭', '😡', '🥺',
  '👍', '👏', '🙌', '🙏', '💪', '🔥', '💯', '🎉',
  '❤️', '💔', '💜', '⭐', '✨', '💥', '🎁', '👻',
  '🤣', '😘', '🤗', '🤔', '😴', '🤤', '🤯', '🥵',
  '🤡', '👻', '💀', '👽', '🤖', '🎃', '😻', '🙈',
  '✊', '🤝', '🫶', '🤘', '🤙', '👌', '✌️', '🤟',
];

const List<String> _categoryIcons = ['😀', '👋', '🐻', '🍔', '✈️', '⚽', '💡', '🔣', '🏁'];

class EmojiStickerPanel extends StatefulWidget {
  const EmojiStickerPanel({
    super.key,
    required this.onEmoji,
    this.onSticker,
    this.bottomInset = 0,
  });

  final ValueChanged<String> onEmoji;
  final ValueChanged<String>? onSticker;
  final double bottomInset;

  @override
  State<EmojiStickerPanel> createState() => _EmojiStickerPanelState();
}

class _EmojiStickerPanelState extends State<EmojiStickerPanel> {
  int _tab = 0;
  int _category = 0;

  List<MapEntry<String, List<String>>> get _groups => kEmojiGroups.entries.toList();

  @override
  Widget build(BuildContext context) {
    final showStickers = widget.onSticker != null;
    return Container(
      height: 300 + widget.bottomInset,
      padding: EdgeInsets.only(top: 8, bottom: widget.bottomInset),
      child: Column(
        children: [
          if (showStickers)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  _tabButton('Emoji', 0),
                  _tabButton('Stickers', 1),
                ],
              ),
            ),
          Expanded(
            child: (_tab == 0 || !showStickers) ? _emojiView() : _stickerView(),
          ),
          if (_tab == 0 || !showStickers) _categoryBar(),
        ],
      ),
    );
  }

  Widget _emojiView() {
    final emojis = _groups[_category].value;
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemCount: emojis.length,
      itemBuilder: (context, i) {
        final e = emojis[i];
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => widget.onEmoji(e),
          child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
        );
      },
    );
  }

  Widget _stickerView() {
    return GridView.count(
      crossAxisCount: 4,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        for (final s in kChatStickers)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => widget.onSticker!(s),
            child: Container(
              decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16)),
              child: Center(child: Text(s, style: const TextStyle(fontSize: 40))),
            ),
          ),
      ],
    );
  }

  Widget _categoryBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < _categoryIcons.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _category = i),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _category == i ? ChatTheme.purple : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    _categoryIcons[i],
                    style: TextStyle(fontSize: 20, color: _category == i ? null : Colors.grey.shade400),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tabButton(String label, int index) {
    final active = _tab == index;
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 4),
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: active ? ChatTheme.purple : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }
}
