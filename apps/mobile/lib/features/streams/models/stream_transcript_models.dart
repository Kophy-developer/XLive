import '../../../core/network/api_json.dart';

class StreamTranscriptLine {
  const StreamTranscriptLine({
    required this.segmentId,
    required this.text,
    required this.mode,
    required this.lang,
    required this.isFinal,
    this.timestamp,
  });

  final String segmentId;
  final String text;
  final String mode;
  final String lang;
  final bool isFinal;
  final int? timestamp;

  factory StreamTranscriptLine.fromJson(Map<String, dynamic> json) {
    return StreamTranscriptLine(
      segmentId: ApiJson.pickString(json, ['segmentId', 'id', '_id']) ?? '',
      text: ApiJson.pickString(json, ['text', 'content', 'transcript']) ?? '',
      mode: ApiJson.pickString(json, ['mode']) ?? 'original',
      lang: ApiJson.pickString(json, ['lang', 'language', 'sourceLang']) ?? '',
      isFinal: ApiJson.boolValue(json['isFinal'], fallback: true),
      timestamp: ApiJson.pickInt(json, ['timestamp', 'ts', 'at']),
    );
  }
}
