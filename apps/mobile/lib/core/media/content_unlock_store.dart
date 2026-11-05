import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../session/auth_session.dart';

class ContentUnlockStore {
  ContentUnlockStore._();

  static final Set<String> _unlocked = {};
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _prefix = 'xlive_unlocked_media_v1_';
  static String? _loadedForUser;
  static Future<void>? _loadFuture;

  static String _key(String targetType, String id) => '$targetType:$id';

  static Future<void> ensureLoaded() async {
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) {
      _unlocked.clear();
      _loadedForUser = null;
      return;
    }
    if (_loadedForUser == userId) return;
    final existing = _loadFuture;
    if (existing != null) {
      await existing;
      if (_loadedForUser == userId) return;
    }
    final future = _load(userId);
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  static Future<void> _load(String userId) async {
    try {
      final raw = await _storage.read(key: '$_prefix$userId');
      _unlocked.clear();
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            final key = e?.toString().trim() ?? '';
            if (key.contains(':')) _unlocked.add(key);
          }
        }
      }
      _loadedForUser = userId;
    } catch (_) {
      _loadedForUser = userId;
    }
  }

  static Future<void> _persist() async {
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) return;
    try {
      await _storage.write(
        key: '$_prefix$userId',
        value: jsonEncode(_unlocked.take(500).toList()),
      );
    } catch (_) {}
  }

  static bool isUnlocked(String targetType, String id) {
    if (targetType.isEmpty || id.isEmpty) return false;
    return _unlocked.contains(_key(targetType, id));
  }

  static void mark(String targetType, String id) {
    if (targetType.isEmpty || id.isEmpty) return;
    _unlocked.add(_key(targetType, id));
    _persist();
  }

  static void clear(String targetType, String id) {
    _unlocked.remove(_key(targetType, id));
    _persist();
  }

  static void clearAll() {
    _unlocked.clear();
    _loadedForUser = null;
    _loadFuture = null;
  }
}
