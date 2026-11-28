String truncateSafely(String text, int maxChars, {String ellipsis = '…'}) {
  final runes = text.runes.toList();
  if (runes.length <= maxChars) return text;
  if (maxChars <= 0) return ellipsis;
  return '${String.fromCharCodes(runes.take(maxChars))}$ellipsis';
}
