import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';

import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/push_notification_service.dart';
import 'src/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await FirebaseBootstrap.ensureInitialized();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stack,
        library: 'FirebaseBootstrap',
        informationCollector: () => [
          DiagnosticsNode.message('App will run without push until Firebase is available.'),
        ],
      ),
    );
  }

  runApp(const XLiveApp());

  if (FirebaseBootstrap.isInitialized) {
    unawaited(PushNotificationService.instance.start());
  }
}
