import 'package:firebase_core/firebase_core.dart';

class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<void>? _pending;

  static bool get isInitialized => Firebase.apps.isNotEmpty;

  static Future<void> ensureInitialized() {
    if (isInitialized) return Future<void>.value();
    final pending = _pending;
    if (pending != null) return pending;

    final future = Firebase.initializeApp().whenComplete(() {
      _pending = null;
    });
    _pending = future;
    return future;
  }
}
