import 'package:flutter_test/flutter_test.dart';

bool shouldShowSenderName({
  required bool isMine,
  required String? senderName,
  required String? senderId,
  required bool previousIsMine,
  required String? previousSenderId,
  required String? previousSenderName,
  required bool hasPrevious,
}) {
  if (isMine) return false;
  final name = senderName?.trim() ?? '';
  if (name.isEmpty) return false;
  if (!hasPrevious || previousIsMine) return true;
  final prevId = previousSenderId?.trim() ?? '';
  final curId = senderId?.trim() ?? '';
  if (curId.isNotEmpty && prevId.isNotEmpty) return curId != prevId;
  return (previousSenderName?.trim() ?? '') != name;
}

void main() {
  test('shows name when sender changes', () {
    expect(
      shouldShowSenderName(
        isMine: false,
        senderName: 'Ada',
        senderId: '2',
        previousIsMine: false,
        previousSenderId: '1',
        previousSenderName: 'Bob',
        hasPrevious: true,
      ),
      isTrue,
    );
  });

  test('hides name for consecutive messages from same sender', () {
    expect(
      shouldShowSenderName(
        isMine: false,
        senderName: 'Ada',
        senderId: '2',
        previousIsMine: false,
        previousSenderId: '2',
        previousSenderName: 'Ada',
        hasPrevious: true,
      ),
      isFalse,
    );
  });

  test('shows name after own message', () {
    expect(
      shouldShowSenderName(
        isMine: false,
        senderName: 'Ada',
        senderId: '2',
        previousIsMine: true,
        previousSenderId: 'me',
        previousSenderName: 'Me',
        hasPrevious: true,
      ),
      isTrue,
    );
  });

  test('never shows name on own messages', () {
    expect(
      shouldShowSenderName(
        isMine: true,
        senderName: 'Me',
        senderId: 'me',
        previousIsMine: false,
        previousSenderId: '2',
        previousSenderName: 'Ada',
        hasPrevious: true,
      ),
      isFalse,
    );
  });
}
