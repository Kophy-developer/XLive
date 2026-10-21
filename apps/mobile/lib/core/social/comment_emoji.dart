class CommentEmojiSpec {
  const CommentEmojiSpec(this.code, this.glyph);
  final String code;
  final String glyph;
}

const commentEmojiPack = <CommentEmojiSpec>[
  CommentEmojiSpec('grin', '😀'),
  CommentEmojiSpec('smiley', '😃'),
  CommentEmojiSpec('smile', '😄'),
  CommentEmojiSpec('laugh', '😆'),
  CommentEmojiSpec('joy', '😂'),
  CommentEmojiSpec('rofl', '🤣'),
  CommentEmojiSpec('wink', '😉'),
  CommentEmojiSpec('blush', '😊'),
  CommentEmojiSpec('innocent', '😇'),
  CommentEmojiSpec('hearts', '🥰'),
  CommentEmojiSpec('heart_eyes', '😍'),
  CommentEmojiSpec('star_struck', '🤩'),
  CommentEmojiSpec('kiss', '😘'),
  CommentEmojiSpec('think', '🤔'),
  CommentEmojiSpec('shush', '🤫'),
  CommentEmojiSpec('neutral', '😐'),
  CommentEmojiSpec('expressionless', '😑'),
  CommentEmojiSpec('smirk', '😏'),
  CommentEmojiSpec('unamused', '😒'),
  CommentEmojiSpec('roll', '🙄'),
  CommentEmojiSpec('sleep', '😴'),
  CommentEmojiSpec('sick', '🤒'),
  CommentEmojiSpec('hot', '🥵'),
  CommentEmojiSpec('cold', '🥶'),
  CommentEmojiSpec('woozy', '🥴'),
  CommentEmojiSpec('exploding', '🤯'),
  CommentEmojiSpec('party', '🥳'),
  CommentEmojiSpec('cool', '😎'),
  CommentEmojiSpec('nerd', '🤓'),
  CommentEmojiSpec('confused', '😕'),
  CommentEmojiSpec('worried', '😟'),
  CommentEmojiSpec('open_mouth', '😮'),
  CommentEmojiSpec('hush', '😯'),
  CommentEmojiSpec('astonished', '😲'),
  CommentEmojiSpec('flush', '😳'),
  CommentEmojiSpec('pleading', '🥺'),
  CommentEmojiSpec('frown', '😢'),
  CommentEmojiSpec('sob', '😭'),
  CommentEmojiSpec('scream', '😱'),
  CommentEmojiSpec('rage', '😡'),
  CommentEmojiSpec('thumbsup', '👍'),
  CommentEmojiSpec('thumbsdown', '👎'),
  CommentEmojiSpec('clap', '👏'),
  CommentEmojiSpec('pray', '🙏'),
  CommentEmojiSpec('ok', '👌'),
  CommentEmojiSpec('muscle', '💪'),
  CommentEmojiSpec('fire', '🔥'),
  CommentEmojiSpec('hundred', '💯'),
  CommentEmojiSpec('sparkles', '✨'),
  CommentEmojiSpec('star', '⭐'),
  CommentEmojiSpec('boom', '💥'),
  CommentEmojiSpec('heart', '❤️'),
  CommentEmojiSpec('orange_heart', '🧡'),
  CommentEmojiSpec('yellow_heart', '💛'),
  CommentEmojiSpec('green_heart', '💚'),
  CommentEmojiSpec('blue_heart', '💙'),
  CommentEmojiSpec('purple_heart', '💜'),
  CommentEmojiSpec('black_heart', '🖤'),
  CommentEmojiSpec('white_heart', '🤍'),
  CommentEmojiSpec('broken_heart', '💔'),
  CommentEmojiSpec('two_hearts', '💕'),
  CommentEmojiSpec('tada', '🎉'),
  CommentEmojiSpec('crown', '👑'),
  CommentEmojiSpec('trophy', '🏆'),
  CommentEmojiSpec('rose', '🌹'),
  CommentEmojiSpec('sun', '☀️'),
  CommentEmojiSpec('moon', '🌙'),
  CommentEmojiSpec('dog', '🐶'),
  CommentEmojiSpec('cat', '🐱'),
  CommentEmojiSpec('unicorn', '🦄'),
  CommentEmojiSpec('pizza', '🍕'),
  CommentEmojiSpec('burger', '🍔'),
  CommentEmojiSpec('coffee', '☕'),
  CommentEmojiSpec('music', '🎵'),
  CommentEmojiSpec('camera', '📷'),
  CommentEmojiSpec('gift', '🎁'),
  CommentEmojiSpec('money', '💰'),
  CommentEmojiSpec('eyes', '👀'),
  CommentEmojiSpec('wave', '👋'),
  CommentEmojiSpec('peace', '✌️'),
];

final _tokenRe = RegExp(r'\[\[xl:(e|r):([a-z0-9_]+)(?::[^\]]+)?\]\]');
final _reactionRe = RegExp(r'^\[\[xl:r:([a-z0-9_]+)(?::([^\]]+))?\]\]$');
final _byCode = {for (final item in commentEmojiPack) item.code: item.glyph};
final _byGlyph = [...commentEmojiPack]..sort((a, b) => b.glyph.length.compareTo(a.glyph.length));

List<CommentEmojiSpec> get commentEmojiPackList => commentEmojiPack;

String encodeCommentText(String raw) {
  var out = raw;
  for (final item in _byGlyph) {
    if (!out.contains(item.glyph)) continue;
    out = out.replaceAll(item.glyph, '[[xl:e:${item.code}]]');
  }
  return out;
}

String decodeCommentText(String raw) {
  return raw.replaceAllMapped(_tokenRe, (m) => _byCode[m.group(2)] ?? '');
}

String emojiToken(String code, {String kind = 'e'}) => '[[xl:$kind:$code]]';

String reactionToken(String code, String parentId) => '[[xl:r:$code:$parentId]]';

({String code, String? parentId})? parseReaction(String raw) {
  final match = _reactionRe.firstMatch(raw.trim());
  if (match == null) return null;
  final parent = match.group(2);
  return (code: match.group(1)!, parentId: parent != null && parent.isNotEmpty ? parent : null);
}

String? reactionCodeFromContent(String raw) => parseReaction(raw)?.code;

bool isReactionComment(String raw) => parseReaction(raw) != null;

String glyphForCode(String code) => _byCode[code] ?? '';

final _mediaRe = RegExp(r'\[\[xl:m:(https?:\/\/[^\]]+)\]\]');

String mediaToken(String url) => '[[xl:m:${url.trim()}]]';

String composeCommentContent(String caption, [String? mediaUrl]) {
  final text = encodeCommentText(caption.trim());
  if (mediaUrl == null || mediaUrl.trim().isEmpty) return text;
  return text.isEmpty ? mediaToken(mediaUrl) : '$text ${mediaToken(mediaUrl)}';
}

List<String> extractMediaUrls(String raw) =>
    _mediaRe.allMatches(raw).map((m) => m.group(1)!).toList();

String textWithoutMedia(String raw) {
  return decodeCommentText(raw.replaceAll(_mediaRe, ' ')).trim();
}

const quickReactionCodes = <String>[
  'heart',
  'thumbsup',
  'joy',
  'open_mouth',
  'frown',
  'fire',
  'clap',
  'tada',
];

String? codeForGlyph(String glyph) {
  for (final item in commentEmojiPack) {
    if (item.glyph == glyph) return item.code;
  }
  return null;
}
