import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/core/live/live_languages.dart';

void main() {
  test('normalizes live languages', () {
    expect(normalizeLiveLang('en-US'), 'en');
    expect(normalizeLiveLang('ES'), 'es');
    expect(normalizeLiveLang('fr_FR'), 'fr');
    expect(normalizeLiveLang('zh-CN'), 'zh');
    expect(normalizeLiveLang('zh-Hans'), 'zh');
    expect(normalizeLiveLang('mandarin'), 'zh');
    expect(normalizeLiveLang('de'), '');
  });

  test('speech locales', () {
    expect(speechLocaleForLang('es'), 'es_ES');
    expect(speechLocaleForLang('zh'), 'zh_CN');
    expect(speechLocaleForLang('en'), 'en_US');
    expect(speechLocaleForLang('fr'), 'fr_FR');
  });

  test('translation needed matrix for en/es/fr/zh', () {
    const matrix = ['en', 'es', 'fr', 'zh'];
    for (final source in matrix) {
      for (final target in matrix) {
        expect(
          needsLiveTranslation(source, target),
          source != target,
          reason: '$source->$target',
        );
      }
    }
  });
}
