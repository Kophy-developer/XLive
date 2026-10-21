import 'package:flutter_test/flutter_test.dart';
import 'package:xlive_mobile/core/notifications/in_app_notification_store.dart';

void main() {
  tearDown(() {
    InAppNotificationStore.instance.resetForSignOut();
  });

  test('ingestRemotePush stores title body and type', () {
    InAppNotificationStore.instance.ingestRemotePush(
      title: 'New message',
      body: 'Hello from FCM',
      data: {'type': 'message_received', 'messageId': 'm1'},
    );

    final items = InAppNotificationStore.instance.notifications;
    expect(items, hasLength(1));
    expect(items.first.type, 'message_received');
    expect(items.first.title, 'New message');
    expect(items.first.body, 'Hello from FCM');
    expect(items.first.id, 'message_received:m1');
  });

  test('ingestRemotePush defaults type to push', () {
    InAppNotificationStore.instance.ingestRemotePush(
      title: 'Xlive',
      body: null,
      data: const {},
    );

    final items = InAppNotificationStore.instance.notifications;
    expect(items, hasLength(1));
    expect(items.first.type, 'push');
    expect(items.first.title, 'Xlive');
    expect(items.first.body, isNull);
  });

  test('ingestRemotePush dedupes by id', () {
    InAppNotificationStore.instance.ingestRemotePush(
      title: 'Invite',
      data: {'type': 'stream_invite_incoming', 'inviteId': 'inv-1'},
    );
    InAppNotificationStore.instance.ingestRemotePush(
      title: 'Invite again',
      data: {'type': 'stream_invite_incoming', 'inviteId': 'inv-1'},
    );

    expect(InAppNotificationStore.instance.notifications, hasLength(1));
    expect(InAppNotificationStore.instance.notifications.first.title, 'Invite');
  });
}
