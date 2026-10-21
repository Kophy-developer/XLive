const _audioExtensions = {'.m4a', '.aac', '.mp3', '.wav', '.ogg', '.opus'};
const _imageExtensions = {'.png', '.jpg', '.jpeg', '.webp', '.gif', '.heic', '.heif'};
const _videoExtensions = {'.mp4', '.mov', '.m4v', '.avi', '.mkv', '.webm'};

String inferChatUploadMediaType(String filename, {String? override}) {
  final explicit = override?.trim();
  if (explicit != null && explicit.isNotEmpty) return explicit;

  final lower = filename.toLowerCase();
  final dot = lower.lastIndexOf('.');
  final ext = dot >= 0 ? lower.substring(dot) : '';

  if (_audioExtensions.contains(ext)) return 'voice';
  if (_imageExtensions.contains(ext)) return 'image';
  if (_videoExtensions.contains(ext)) return 'video';
  return 'file';
}

Map<String, String> buildChatUploadFields({
  required String filename,
  String? content,
  String? replyToMessageId,
  String? mediaType,
}) {
  final fields = <String, String>{};
  final resolvedMediaType = inferChatUploadMediaType(filename, override: mediaType);
  fields['mediaType'] = resolvedMediaType;

  final text = content?.trim() ?? '';
  if (text.isNotEmpty) {
    fields['content'] = text;
  } else if (resolvedMediaType != 'voice') {
    fields['content'] = '';
  }

  if (replyToMessageId != null && replyToMessageId.isNotEmpty) {
    fields['replyToMessageId'] = replyToMessageId;
  }

  return fields;
}
