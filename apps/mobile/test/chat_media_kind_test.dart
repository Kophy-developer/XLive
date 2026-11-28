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

  test('image file extension wins over document-like type token', () {
    final kind = resolveChatMediaKind(
      pickChatMediaTypeCandidate(fileType: 'file', mimeType: 'image/jpeg'),
      'https://store.example.com/uploads/chats/u1/photo.jpg',
    );
    expect(kind, 'image');
  });

  test('real host captioned chat image stays image', () {
    final message = ChatMessage.fromJson({
      '_id': '6af624eca919486116e1f370',
      'content': 'with caption from mobile',
      'mediaType': 'image',
      'mediaUrl':
          'https://xlive-app-bcqre.ondigitalocean.app/uploads/chats/6a3992f1c3d883ed77cd1009/ebc13098-16a9-4fa6-ab03-55b477d8b56c.jpg',
      'fileName': 'crop.jpg',
    });
    expect(message.content, 'with caption from mobile');
    expect(message.isImage, isTrue);
    expect(message.isDocument, isFalse);
  });
}
