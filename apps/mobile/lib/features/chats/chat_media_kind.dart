const _messageKindTypes = {
  'message',
  'text',
  'chat',
  'dm',
  'group',
  'system',
  'notification',
  'event',
  'reply',
  'edited',
  'deleted',
};

String? canonicalizeChatMediaToken(String? raw) {
  final t = (raw ?? '').trim().toLowerCase();
  if (t.isEmpty || _messageKindTypes.contains(t)) return null;
  if (t.contains('sticker')) return 'sticker';
  if (t.contains('image') || t.contains('photo') || t.contains('gif') || t.startsWith('image/')) return 'image';
  if (t.contains('video') || t.startsWith('video/')) return 'video';
  if (t.contains('voice')) return 'voice';
  if (t.contains('audio') || t.startsWith('audio/')) return 'audio';
  if (t.contains('doc') ||
      t.contains('pdf') ||
      t.contains('file') ||
      t.contains('sheet') ||
      t.contains('receipt')) {
    return 'document';
  }
  return null;
}

bool looksLikeChatImageUrl(String? url) {
  final u = (url ?? '').toLowerCase();
  if (u.isEmpty) return false;
  if (u.contains('/image/upload/')) return true;
  if (u.contains('image%2f')) return true;
  return RegExp(r'\.(png|jpe?g|gif|webp|heic|heif|avif|bmp)(\?|#|$)', caseSensitive: false).hasMatch(u);
}

bool looksLikeChatVideoUrl(String? url) {
  final u = (url ?? '').toLowerCase();
  if (u.isEmpty) return false;
  if (u.contains('/video/upload/')) return true;
  return RegExp(r'\.(mp4|m4v|mov|webm|mkv|avi)(\?|#|$)', caseSensitive: false).hasMatch(u);
}

bool looksLikeChatAudioUrl(String? url) {
  final u = (url ?? '').toLowerCase();
  if (u.isEmpty) return false;
  return RegExp(r'\.(m4a|aac|mp3|wav|ogg|opus)(\?|#|$)', caseSensitive: false).hasMatch(u);
}

String? resolveChatMediaKind(String? mediaType, String? mediaUrl) {
  final fromType = canonicalizeChatMediaToken(mediaType);
  if (looksLikeChatImageUrl(mediaUrl)) {
    if (fromType == null || fromType == 'image' || fromType == 'sticker' || fromType == 'document') {
      return fromType == 'sticker' ? 'sticker' : 'image';
    }
  }
  if (looksLikeChatVideoUrl(mediaUrl)) {
    if (fromType == null || fromType == 'video' || fromType == 'document') return 'video';
  }
  if (looksLikeChatAudioUrl(mediaUrl)) {
    if (fromType == null || fromType == 'audio' || fromType == 'voice' || fromType == 'document') {
      return fromType == 'audio' ? 'audio' : 'voice';
    }
  }
  if (fromType != null) return fromType;
  if ((mediaUrl ?? '').trim().isNotEmpty) return 'document';
  return null;
}

String? pickChatMediaTypeCandidate({
  String? mediaType,
  String? attachmentType,
  String? fileType,
  String? mimeType,
  String? genericType,
}) {
  for (final candidate in [mimeType, mediaType, attachmentType, fileType, genericType]) {
    final kind = canonicalizeChatMediaToken(candidate);
    if (kind != null) return kind;
  }
  return null;
}
