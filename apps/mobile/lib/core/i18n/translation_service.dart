import 'dart:ui' as ui;

import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../session/auth_session.dart';

class TranslationResult {
  const TranslationResult({required this.text, required this.translated, this.sourceCode});

  final String text;
  final bool translated;
  final String? sourceCode;
}

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  final _languageIdentifier = LanguageIdentifier(confidenceThreshold: 0.5);
  final _modelManager = OnDeviceTranslatorModelManager();
  final Map<String, OnDeviceTranslator> _translators = {};

  String get _targetCode {
    final lang = AuthSession.instance.user?.language;
    if (lang != null && lang.trim().isNotEmpty) return lang.trim().toLowerCase().split('-').first;
    final locale = ui.PlatformDispatcher.instance.locale.languageCode;
    return locale.isEmpty ? 'en' : locale.toLowerCase();
  }

  TranslateLanguage? _resolve(String bcpCode) {
    final code = bcpCode.toLowerCase().split('-').first;
    for (final lang in TranslateLanguage.values) {
      if (lang.bcpCode.toLowerCase() == code) return lang;
    }
    return null;
  }

  Future<TranslationResult> translate(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return TranslationResult(text: text, translated: false);

    final targetCode = _targetCode;
    final target = _resolve(targetCode);
    if (target == null) return TranslationResult(text: text, translated: false);

    String sourceCode;
    try {
      sourceCode = await _languageIdentifier.identifyLanguage(trimmed);
    } catch (_) {
      return TranslationResult(text: text, translated: false);
    }
    if (sourceCode == 'und') return TranslationResult(text: text, translated: false);
    final normalizedSource = sourceCode.toLowerCase().split('-').first;
    if (normalizedSource == targetCode) {
      return TranslationResult(text: text, translated: false, sourceCode: sourceCode);
    }

    final source = _resolve(sourceCode);
    if (source == null) return TranslationResult(text: text, translated: false, sourceCode: sourceCode);

    try {
      await _ensureModel(source.bcpCode);
      await _ensureModel(target.bcpCode);
      final key = '${source.bcpCode}>${target.bcpCode}';
      final translator = _translators.putIfAbsent(
        key,
        () => OnDeviceTranslator(sourceLanguage: source, targetLanguage: target),
      );
      final out = await translator.translateText(trimmed);
      if (out.trim().isEmpty) return TranslationResult(text: text, translated: false, sourceCode: sourceCode);
      return TranslationResult(text: out, translated: true, sourceCode: sourceCode);
    } catch (_) {
      return TranslationResult(text: text, translated: false, sourceCode: sourceCode);
    }
  }

  Future<void> _ensureModel(String bcpCode) async {
    final downloaded = await _modelManager.isModelDownloaded(bcpCode);
    if (!downloaded) {
      await _modelManager.downloadModel(bcpCode);
    }
  }

  Future<void> dispose() async {
    for (final t in _translators.values) {
      await t.close();
    }
    _translators.clear();
    await _languageIdentifier.close();
  }
}
