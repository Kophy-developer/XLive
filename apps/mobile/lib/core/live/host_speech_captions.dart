import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../features/streams/models/stream_transcript_models.dart';
import 'live_languages.dart';

class HostSpeechCaptions {
  HostSpeechCaptions({required this.onChunk});

  final void Function(StreamTranscriptLine line) onChunk;

  final SpeechToText _speech = SpeechToText();
  bool _wanted = false;
  bool _starting = false;

  Future<void> start({String? lang}) async {
    _wanted = true;
    if (_starting) return;
    _starting = true;
    final locale = speechLocaleForLang(lang);
    final source = normalizeLiveLang(lang);
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (!_wanted) return;
          if (status == 'done' || status == 'notListening') {
            unawaited(_listen(locale: locale, source: source));
          }
        },
        onError: (_) {
          if (!_wanted) return;
          unawaited(Future<void>.delayed(const Duration(milliseconds: 600), () {
            if (_wanted) unawaited(_listen(locale: locale, source: source));
          }));
        },
      );
      if (!ready || !_wanted) return;
      await _listen(locale: locale, source: source);
    } finally {
      _starting = false;
    }
  }

  Future<void> _listen({required String locale, required String source}) async {
    if (!_wanted || _speech.isListening) return;
    try {
      await _speech.listen(
        onResult: (result) {
          final text = result.recognizedWords.trim();
          if (text.isEmpty) return;
          onChunk(
            StreamTranscriptLine(
              segmentId: 'speech_${DateTime.now().millisecondsSinceEpoch}',
              text: text,
              mode: 'original',
              lang: source.isEmpty ? locale : source,
              isFinal: result.finalResult,
              timestamp: DateTime.now().millisecondsSinceEpoch,
            ),
          );
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          localeId: locale,
        ),
      );
    } catch (_) {}
  }

  Future<void> stop() async {
    _wanted = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }
}
