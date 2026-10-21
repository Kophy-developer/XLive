import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/src/chats/chat_album.dart';

void main() {
  test('stripChatAlbum never leaves album marker visible', () {
    const raw = '\u2063xlive_chat_album:1790674091097_751233552\u2063';
    expect(visibleChatCaption(raw), '');
    expect(visibleChatCaption('${raw}hello'), 'hello');
    expect(chatAlbumIdFromContent(raw), '1790674091097_751233552');
  });

  test('wrapChatAlbumContent round-trips', () {
    final id = newChatAlbumId();
    final wrapped = wrapChatAlbumContent('', id);
    expect(chatAlbumIdFromContent(wrapped), id);
    expect(visibleChatCaption(wrapped), '');
  });

  test('planChatMediaSendBatches tags multi uncaptioned images with album id', () {
    final batches = planChatMediaSendBatches([
      (path: 'a.jpg', isVideo: false, caption: null),
      (path: 'b.jpg', isVideo: false, caption: null),
      (path: 'c.jpg', isVideo: false, caption: null),
    ]);
    expect(batches, hasLength(1));
    expect(batches.first.items, hasLength(3));
    final ids = batches.first.items.map((e) => chatAlbumIdFromContent(e.caption)).toSet();
    expect(ids.length, 1);
    expect(ids.single, isNotNull);
  });
}
