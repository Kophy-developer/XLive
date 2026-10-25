import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/features/chats/chat_media_kind.dart';
import 'package:xlive_mobile/features/chats/models/chat_api_models.dart';

void main() {
  test('ignores message-kind type and detects Cloudinary image upload path', () {
    final kind = resolveChatMediaKind(
      pickChatMediaTypeCandidate(genericType: 'message'),
      'https://res.cloudinary.com/demo/image/upload/v1/x-live/abc',
    );
    expect(kind, 'image');
  });

  test('accepts Image and image/jpeg media types', () {
    expect(resolveChatMediaKind('Image', null), 'image');
    expect(resolveChatMediaKind('image/jpeg', null), 'image');
    expect(resolveChatMediaKind('photo', null), 'image');
  });

  test('ChatMessage.fromJson keeps caption and still marks Cloudinary url as image', () {
    final message = ChatMessage.fromJson({
      'id': '1',
      'content': 'hello caption',
      'type': 'message',
      'mediaUrl': 'https://res.cloudinary.com/demo/image/upload/v1/folder/photo',
      'senderId': 'u1',
    });
    expect(message.content, 'hello caption');
    expect(message.hasMedia, isTrue);
    expect(message.isImage, isTrue);
    expect(message.isDocument, isFalse);
  });

  test('extensionless non-cloudinary url with mediaType image stays image', () {
    final message = ChatMessage.fromJson({
      'id': '2',
      'content': 'cap',
      'mediaType': 'image',
      'mediaUrl': 'https://cdn.example.com/uploads/abc123',
    });
    expect(message.isImage, isTrue);
  });
}
