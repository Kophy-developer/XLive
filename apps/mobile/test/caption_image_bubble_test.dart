import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/src/chats/chat_composer.dart';

void main() {
  testWidgets('imageUrl with caption renders collage not text-only', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SentMessageBubble(
              text: 'with caption from mobile',
              timeLabel: '2:43 PM',
              imageUrl: 'https://example.com/chat/photo.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatBubbleMediaCollage), findsOneWidget);
    expect(find.text('with caption from mobile'), findsOneWidget);
    expect(tester.getSize(find.byType(ChatBubbleMediaCollage)).height, greaterThan(50));
  });

  testWidgets('caption without imageUrl stays text-only', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SentMessageBubble(
            text: 'with caption from mobile',
            timeLabel: '2:43 PM',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatBubbleMediaCollage), findsNothing);
    expect(find.text('with caption from mobile'), findsOneWidget);
  });
}
