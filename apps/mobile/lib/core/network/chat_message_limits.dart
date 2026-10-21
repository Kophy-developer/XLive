import 'api_exception.dart';

const kChatMessageMaxLength = 2000;

const chatMessageTooLongMessage =
    'This message is too long and won’t be sent. Shorten it and try again.';

bool isChatMessageTooLong(String text) => text.trim().length > kChatMessageMaxLength;

bool isContentTooLongApiError(ApiException e) {
  if (e.statusCode != 400 && e.statusCode != 413 && e.statusCode != 422) return false;
  final details = e.details;
  if (details is Map) {
    final error = details['error'];
    if (error is Map && error.containsKey('content')) {
      final value = '${error['content']}'.toLowerCase();
      if (value.contains('invalid') ||
          value.contains('long') ||
          value.contains('max') ||
          value.contains('length') ||
          value.contains('limit')) {
        return true;
      }
    }
  }
  final msg = e.message.toLowerCase();
  return msg.contains('content: invalid') ||
      msg.contains('too long') ||
      msg.contains('message too long') ||
      msg.contains('max length') ||
      msg.contains('character limit');
}
