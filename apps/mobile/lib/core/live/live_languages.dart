const liveLangs = <String>['en', 'es', 'fr', 'zh'];

String normalizeLiveLang(String? input) {
  if (input == null) return '';
  final raw = input.trim().toLowerCase().replaceAll('_', '-');
  if (raw.isEmpty) return '';
  final base = raw.split('-').first;
  if (base == 'zh' || raw.startsWith('zh') || raw.contains('cmn') || raw.contains('mandarin')) {
    return 'zh';
  }
  if (liveLangs.contains(base)) return base;
  return '';
}

String speechLocaleForLang(String? input) {
  switch (normalizeLiveLang(input)) {
    case 'es':
      return 'es_ES';
    case 'fr':
      return 'fr_FR';
    case 'zh':
      return 'zh_CN';
    case 'en':
    default:
      return 'en_US';
  }
}

bool needsLiveTranslation(String? source, String? target) {
  final from = normalizeLiveLang(source);
  final to = normalizeLiveLang(target);
  if (to.isEmpty) return false;
  if (from.isEmpty) return true;
  return from != to;
}
