import 'package:flutter/material.dart';

import '../../features/chats/models/chat_api_models.dart';

const chatAlbumMergeWindow = Duration(minutes: 2);
const _chatAlbumPrefix = '\u2063xlive_chat_album:';
const _chatAlbumSuffix = '\u2063';

String newChatAlbumId() {
  final rand = DateTime.now().microsecondsSinceEpoch & 0x7fffffff;
  return '${DateTime.now().millisecondsSinceEpoch}_$rand';
}

String wrapChatAlbumContent(String caption, String? albumId) {
  final body = caption.trim();
  if (albumId == null || albumId.isEmpty) return body;
  return '$_chatAlbumPrefix$albumId$_chatAlbumSuffix$body';
}

String? chatAlbumIdFromContent(String? content) {
  final raw = content ?? '';
  if (!raw.startsWith(_chatAlbumPrefix)) return null;
  final end = raw.indexOf(_chatAlbumSuffix, _chatAlbumPrefix.length);
  if (end <= _chatAlbumPrefix.length) return null;
  final id = raw.substring(_chatAlbumPrefix.length, end);
  return id.isEmpty ? null : id;
}

String stripChatAlbum(String? content) {
  final raw = content ?? '';
  final id = chatAlbumIdFromContent(raw);
  if (id == null) return raw;
  final marker = '$_chatAlbumPrefix$id$_chatAlbumSuffix';
  if (raw.startsWith(marker)) return raw.substring(marker.length);
  return raw;
}

String visibleChatCaption(String? content) {
  return stripChatAlbum(content).trim();
}

class ChatAlbumMediaItem {
  const ChatAlbumMediaItem({required this.url, this.isVideo = false});

  final String url;
  final bool isVideo;
}

class ChatAlbumRow {
  const ChatAlbumRow({
    required this.message,
    required this.media,
  });

  final ChatMessage message;
  final List<ChatMessage> media;

  bool get isAlbum => media.length > 1;

  List<ChatAlbumMediaItem> get mediaItems {
    final out = <ChatAlbumMediaItem>[];
    for (final m in media) {
      final url = m.mediaUrl?.trim() ?? '';
      if (url.isEmpty) continue;
      out.add(ChatAlbumMediaItem(url: url, isVideo: m.isVideo));
    }
    return out;
  }

  List<String> get imageUrls => mediaItems.map((e) => e.url).toList();

  Set<String> get messageIds => media.map((m) => m.id).toSet()..add(message.id);

  String? get caption {
    for (final m in media) {
      final c = visibleChatCaption(m.content);
      if (c.isNotEmpty) return c;
    }
    final own = visibleChatCaption(message.content);
    return own.isEmpty ? null : own;
  }
}

bool isChatAlbumOverlayCaption(String? caption) {
  final text = caption?.trim() ?? '';
  if (text.isEmpty) return true;
  final lines = text.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).length;
  if (lines > 2) return false;
  final painter = TextPainter(
    text: TextSpan(text: text, style: const TextStyle(fontSize: 14, height: 1.25)),
    maxLines: 3,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 220);
  return painter.computeLineMetrics().length <= 2;
}

bool isChatAlbumMediaCandidate(ChatMessage m) {
  if (!m.hasMedia || m.isSticker || m.isAudio) return false;
  if (!(m.isImage || m.isVideo)) return false;
  final reply = m.replyToMessageId?.trim() ?? '';
  if (reply.isNotEmpty) return false;
  return true;
}

bool _sameSender(ChatMessage a, ChatMessage b) {
  if (a.isMine != b.isMine) return false;
  final sa = a.senderId?.trim() ?? '';
  final sb = b.senderId?.trim() ?? '';
  if (sa.isNotEmpty && sb.isNotEmpty) return sa == sb;
  return a.isMine && b.isMine;
}

bool _captionsCompatible(ChatMessage a, ChatMessage b) {
  final ca = a.content?.trim() ?? '';
  final cb = b.content?.trim() ?? '';
  if (ca.isNotEmpty && cb.isNotEmpty) return false;
  return true;
}

bool _withinWindow(ChatMessage a, ChatMessage b) {
  final ta = a.createdAt;
  final tb = b.createdAt;
  if (ta == null || tb == null) return true;
  return ta.difference(tb).abs() <= chatAlbumMergeWindow;
}

bool canJoinChatAlbum(ChatMessage a, ChatMessage b) {
  if (!isChatAlbumMediaCandidate(a) || !isChatAlbumMediaCandidate(b)) return false;
  if (!_sameSender(a, b)) return false;
  final albumA = chatAlbumIdFromContent(a.content);
  final albumB = chatAlbumIdFromContent(b.content);
  if (albumA != null && albumB != null && albumA == albumB) return true;
  return _captionsCompatible(a, b) && _withinWindow(a, b);
}

List<ChatMessage> _sortChronological(List<ChatMessage> slides) {
  final copy = [...slides];
  copy.sort((a, b) {
    final ta = a.createdAt;
    final tb = b.createdAt;
    if (ta != null && tb != null) return ta.compareTo(tb);
    return 0;
  });
  return copy;
}

List<ChatAlbumRow> coalesceChatImageAlbums(
  List<ChatMessage> messages, {
  required bool newestFirst,
}) {
  if (messages.isEmpty) return const [];
  final out = <ChatAlbumRow>[];
  var i = 0;
  while (i < messages.length) {
    final current = messages[i];
    if (!isChatAlbumMediaCandidate(current)) {
      out.add(ChatAlbumRow(message: current, media: const []));
      i++;
      continue;
    }
    final cluster = <ChatMessage>[current];
    var j = i + 1;
    while (j < messages.length) {
      final next = messages[j];
      if (!canJoinChatAlbum(cluster.last, next)) break;
      cluster.add(next);
      j++;
    }
    if (cluster.length > 1) {
      final chronological = _sortChronological(cluster);
      final lead = newestFirst ? cluster.first : cluster.last;
      out.add(ChatAlbumRow(message: lead, media: chronological));
      i = j;
      continue;
    }
    out.add(ChatAlbumRow(message: current, media: const []));
    i++;
  }
  return out;
}

String resolveChatAlbumKeyId(List<ChatAlbumRow> rows, String messageId) {
  for (final row in rows) {
    if (row.messageIds.contains(messageId)) return row.message.id;
  }
  return messageId;
}

class ChatMediaSendBatch {
  const ChatMediaSendBatch({required this.items, this.sharedCaption});

  final List<({String path, bool isVideo, String? caption})> items;
  final String? sharedCaption;

  bool get isAlbum => items.length > 1;
}

List<ChatMediaSendBatch> planChatMediaSendBatches(
  List<({String path, bool isVideo, String? caption})> items,
) {
  if (items.isEmpty) return const [];
  if (items.length == 1) {
    return [ChatMediaSendBatch(items: items, sharedCaption: items.first.caption)];
  }

  final captions = items.map((e) => e.caption?.trim() ?? '').toList();
  final captionedCount = captions.where((c) => c.isNotEmpty).length;
  final nonEmpty = captions.where((c) => c.isNotEmpty).toSet();

  if (nonEmpty.isEmpty) {
    final albumId = newChatAlbumId();
    return [
      ChatMediaSendBatch(
        items: [
          for (final i in items)
            (path: i.path, isVideo: i.isVideo, caption: wrapChatAlbumContent('', albumId)),
        ],
      ),
    ];
  }

  if (captionedCount == 1) {
    final cap = nonEmpty.first;
    final uncaptionedImages = [
      for (var i = 0; i < items.length; i++)
        if (!(items[i].isVideo) && captions[i].isEmpty) items[i],
    ];
    final albumId = uncaptionedImages.length > 1 ? newChatAlbumId() : null;
    return [
      ChatMediaSendBatch(
        items: [
          for (var i = 0; i < items.length; i++)
            (
              path: items[i].path,
              isVideo: items[i].isVideo,
              caption: captions[i] == cap
                  ? cap
                  : (albumId != null && !items[i].isVideo
                      ? wrapChatAlbumContent('', albumId)
                      : captions[i].isEmpty
                          ? null
                          : captions[i]),
            ),
        ],
        sharedCaption: cap,
      ),
    ];
  }

  final empties = <({String path, bool isVideo, String? caption})>[];
  final batches = <ChatMediaSendBatch>[];
  for (final item in items) {
    final cap = item.caption?.trim() ?? '';
    if (cap.isEmpty) {
      empties.add((path: item.path, isVideo: item.isVideo, caption: null));
    } else {
      batches.add(ChatMediaSendBatch(items: [(path: item.path, isVideo: item.isVideo, caption: cap)], sharedCaption: cap));
    }
  }
  if (empties.length == 1) {
    batches.add(ChatMediaSendBatch(items: empties));
  } else if (empties.length > 1) {
    final albumId = newChatAlbumId();
    batches.add(
      ChatMediaSendBatch(
        items: [
          for (final e in empties)
            (path: e.path, isVideo: e.isVideo, caption: wrapChatAlbumContent('', albumId)),
        ],
      ),
    );
  }
  return batches;
}
