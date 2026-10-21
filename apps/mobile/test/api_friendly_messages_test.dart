import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/core/network/api_exception.dart';
import 'package:xlive_mobile/core/network/api_friendly_messages.dart';
import 'package:xlive_mobile/core/network/chat_message_limits.dart';

void main() {
  test('client blocks over-limit chat text', () {
    expect(isChatMessageTooLong('a' * kChatMessageMaxLength), isFalse);
    expect(isChatMessageTooLong('a' * (kChatMessageMaxLength + 1)), isTrue);
  });

  test('maps content validation to too-long message', () {
    final e = ApiException(
      'content: Invalid value',
      statusCode: 400,
      details: {
        'message': 'Payload Validation Error',
        'error': {'content': 'Invalid value', 'message': 'Please check your inputs'},
      },
    );
    expect(friendlyApiMessage(e), chatMessageTooLongMessage);
  });

  test('maps insufficient balance from message', () {
    final e = ApiException('Insufficient wallet balance', statusCode: 400);
    expect(friendlyApiMessage(e), 'Not enough coins. Add funds and try again.');
  });

  test('maps insufficient balance when UI only got statusCode text', () {
    final e = ApiException(
      'statusCode: 400',
      statusCode: 400,
      details: {
        'message': 'Insufficient wallet balance',
        'error': {'statusCode': 400},
      },
    );
    expect(friendlyApiMessage(e), 'Not enough coins. Add funds and try again.');
  });

  test('maps raw statusCode-only message to fallback', () {
    final e = ApiException('statusCode: 400', statusCode: 400, details: {'error': {'statusCode': 400}});
    expect(friendlyApiMessage(e, fallback: 'Could not unlock.'), 'Could not unlock.');
  });

  test('maps raw payload validation', () {
    final e = ApiException('Payload Validation Error', statusCode: 400);
    expect(friendlyApiMessage(e), 'Some details look invalid. Check your input and try again.');
  });

  test('maps unauthorized', () {
    final e = ApiException('Unauthorized', statusCode: 401);
    expect(friendlyApiMessage(e), 'Sign in to continue.');
  });

  test('maps locked media 403', () {
    final e = ApiException('Not authorized to stream this video', statusCode: 403);
    expect(friendlyApiMessage(e), 'You don’t have access to this content.');
  });

  test('maps missing video 404', () {
    final e = ApiException('Video not found', statusCode: 404);
    expect(friendlyApiMessage(e), 'This content is no longer available.');
  });

  test('maps chat not found', () {
    final e = ApiException('Chat not found', statusCode: 404);
    expect(friendlyApiMessage(e), 'This conversation is no longer available.');
  });

  test('maps sold out and already owned', () {
    expect(friendlyApiMessage(ApiException('Sold out', statusCode: 400)), 'This clip is sold out.');
    expect(friendlyApiMessage(ApiException('Already purchased', statusCode: 400)), 'You already own this content.');
  });
}
