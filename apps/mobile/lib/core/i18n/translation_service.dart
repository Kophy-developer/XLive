import 'dart:ui' as ui;

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

  String get _targetCode {
    final lang = AuthSession.instance.user?.language;
    if (lang != null && lang.trim().isNotEmpty) return lang.trim().toLowerCase().split('-').first;
    final locale = ui.PlatformDispatcher.instance.locale.languageCode;
    return locale.isEmpty ? 'en' : locale.toLowerCase();
  }

  Future<TranslationResult> translate(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return TranslationResult(text: text, translated: false);
    return TranslationResult(text: text, translated: false, sourceCode: _targetCode);
  }

  Future<void> dispose() async {}
}
