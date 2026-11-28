import 'dart:convert';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../live/live_languages.dart';
import '../session/auth_session.dart';

class TranslationResult {
  const TranslationResult({required this.text, required this.translated, this.sourceCode, this.provider});

  final String text;
  final bool translated;
  final String? sourceCode;
  final String? provider;
}

class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  final Map<String, String> _cache = {};
  final http.Client _http = http.Client();

  String get _targetCode {
    final lang = AuthSession.instance.user?.language;
    if (lang != null && lang.trim().isNotEmpty) {
      final normalized = normalizeLiveLang(lang);
      if (normalized.isNotEmpty) return normalized;
      return lang.trim().toLowerCase().split('-').first;
    }
    final locale = ui.PlatformDispatcher.instance.locale.languageCode;
    return locale.isEmpty ? 'en' : locale.toLowerCase();
  }

  Future<TranslationResult> translate(
    String text, {
    String? sourceLang,
    String? targetLang,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return TranslationResult(text: text, translated: false);

    final normalizedTarget = normalizeLiveLang(targetLang);
    final normalizedProfile = normalizeLiveLang(_targetCode);
    final target = normalizedTarget.isNotEmpty
        ? normalizedTarget
        : (normalizedProfile.isNotEmpty ? normalizedProfile : _targetCode);
    final source = normalizeLiveLang(sourceLang);

    if (source.isNotEmpty && source == target) {
      return TranslationResult(text: trimmed, translated: false, sourceCode: source);
    }
    if (!needsLiveTranslation(source.isEmpty ? null : source, target)) {
      return TranslationResult(text: trimmed, translated: false, sourceCode: source.isEmpty ? null : source);
    }

    final cacheKey = '${source.isEmpty ? 'auto' : source}|$target|$trimmed';
    final hit = _cache[cacheKey];
    if (hit != null) {
      return TranslationResult(
        text: hit,
        translated: hit != trimmed,
        sourceCode: source.isEmpty ? null : source,
        provider: 'cache',
      );
    }

    final proxied = await _translateViaWebProxy(trimmed, source: source, target: target);
    if (proxied != null) {
      _remember(cacheKey, proxied.text);
      return proxied;
    }

    final fallback = await _translateViaMyMemory(trimmed, source: source, target: target);
    if (fallback != null) {
      _remember(cacheKey, fallback.text);
      return fallback;
    }

    return TranslationResult(text: trimmed, translated: false, sourceCode: source.isEmpty ? null : source);
  }

  void _remember(String key, String value) {
    _cache[key] = value;
    if (_cache.length > 200) {
      _cache.remove(_cache.keys.first);
    }
  }

  Future<TranslationResult?> _translateViaWebProxy(
    String text, {
    required String source,
    required String target,
  }) async {
    final base = const ApiConfig().webAppBaseUrl.trim();
    if (base.isEmpty) return null;
    try {
      final uri = Uri.parse('$base/api/live/translate');
      final res = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'text': text,
              'source': source.isEmpty ? 'auto' : source,
              'target': target,
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      final out = (body['text'] ?? '').toString().trim();
      if (out.isEmpty) return null;
      return TranslationResult(
        text: out,
        translated: body['translated'] == true && out != text,
        sourceCode: normalizeLiveLang(body['source']?.toString()).isEmpty
            ? (source.isEmpty ? null : source)
            : normalizeLiveLang(body['source']?.toString()),
        provider: body['provider']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<TranslationResult?> _translateViaMyMemory(
    String text, {
    required String source,
    required String target,
  }) async {
    try {
      final from = source.isEmpty ? 'autodetect' : source;
      final uri = Uri.https('api.mymemory.translated.net', '/get', {
        'q': text,
        'langpair': '$from|$target',
      });
      final res = await _http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      final body = jsonDecode(res.body);
      if (body is! Map) return null;
      final responseData = body['responseData'];
      final out = responseData is Map ? (responseData['translatedText'] ?? '').toString().trim() : '';
      if (out.isEmpty || body['responseStatus'] != 200) return null;
      if (RegExp(r'^\s*invalid|query length|my memory', caseSensitive: false).hasMatch(out)) {
        return null;
      }
      return TranslationResult(
        text: out,
        translated: out != text,
        sourceCode: source.isEmpty ? null : source,
        provider: 'mymemory',
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    _http.close();
  }
}
