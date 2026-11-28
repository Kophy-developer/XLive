import 'dart:convert';
import 'dart:io';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';
import 'live_languages.dart';

class LiveHearTranslation {
  LiveHearTranslation._();
  static final LiveHearTranslation instance = LiveHearTranslation._();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _player = AudioPlayer();
  final http.Client _http = http.Client();
  bool _ready = false;
  bool enabled = true;
  String? _lastKey;

  Future<void> ensureReady() async {
    if (_ready) return;
    try {
      await _tts.setSpeechRate(0.48);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _ready = true;
    } catch (_) {}
  }

  Future<void> speak(String text, {String? targetLang}) async {
    if (!enabled) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    await ensureReady();
    final lang = normalizeLiveLang(targetLang);
    final locale = switch (lang) {
      'es' => 'es-ES',
      'fr' => 'fr-FR',
      'zh' => 'zh-CN',
      _ => 'en-US',
    };
    final key = '$locale|$trimmed';
    if (_lastKey == key) return;
    _lastKey = key;

    final played = await _speakViaWebTts(trimmed, lang.isEmpty ? 'en' : lang);
    if (played) return;

    try {
      await _tts.stop();
      await _tts.setLanguage(locale);
      await _tts.speak(trimmed);
    } catch (_) {}
  }

  Future<bool> _speakViaWebTts(String text, String lang) async {
    final base = const ApiConfig().webAppBaseUrl.trim();
    if (base.isEmpty) return false;
    try {
      await _player.stop();
      final uri = Uri.parse('$base/api/live/tts');
      final res = await _http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'text': text, 'lang': lang}),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      if (res.bodyBytes.length < 200) return false;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/xlive_tts_${DateTime.now().millisecondsSinceEpoch}.mp3');
      await file.writeAsBytes(res.bodyBytes, flush: true);
      await _player.setFilePath(file.path);
      await _player.play();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> stop() async {
    _lastKey = null;
    try {
      await _player.stop();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
