import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../../features/streams/models/stream_transcript_models.dart';

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
    try {
      final ready = await _speech.initialize(
        onStatus: (status) {
          if (!_wanted) return;
          if (status == 'done' || status == 'notListening') {
            unawaited(_listen(lang: lang));
          }
        },
        onError: (_) {
          if (!_wanted) return;
          unawaited(Future<void>.delayed(const Duration(milliseconds: 600), () {
            if (_wanted) unawaited(_listen(lang: lang));
          }));
        },
      );
      if (!ready || !_wanted) return;
      await _listen(lang: lang);
    } finally {
      _starting = false;
    }
  }

  Future<void> _listen({String? lang}) async {
    if (!_wanted || _speech.isListening) return;
    final locale = (lang == null || lang.trim().isEmpty) ? null : lang.trim();
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
              lang: locale ?? '',
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
