import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/core/utils/relative_time.dart';
import 'package:xlive_mobile/core/network/chat_message_limits.dart';

void main() {
  test('chat max length constant matches staging backend', () {
    expect(kChatMessageMaxLength, 2000);
    expect(isChatMessageTooLong('x' * 2000), isFalse);
    expect(isChatMessageTooLong('x' * 2001), isTrue);
  });

  test('formatRelativeTime matches Instagram-style short units', () {
    final now = DateTime(2026, 8, 6, 12);
    expect(formatRelativeTime(now.subtract(const Duration(minutes: 3)), now: now), '3m');
    expect(formatRelativeTime(now.subtract(const Duration(hours: 5)), now: now), '5h');
    expect(formatRelativeTime(now.subtract(const Duration(days: 2)), now: now), '2d');
  });
}
