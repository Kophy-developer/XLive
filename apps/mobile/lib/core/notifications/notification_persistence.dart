import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'in_app_notification_store.dart';

class NotificationPersistence {
  NotificationPersistence({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _keyPrefix = 'xlive_inbox_';

  final FlutterSecureStorage _storage;

  String _keyForUser(String? userId) => '$_keyPrefix${userId ?? 'guest'}';

  Future<List<InAppNotification>> load(String? userId) async {
    try {
      final raw = await _storage.read(key: _keyForUser(userId));
      if (raw == null || raw.isEmpty) return const [];
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => InAppNotification.fromJson(Map<String, dynamic>.from(item)))
          .where((n) => n.id.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(String? userId, List<InAppNotification> items) async {
    try {
      final payload = jsonEncode(items.map((n) => n.toJson()).toList());
      await _storage.write(key: _keyForUser(userId), value: payload);
    } catch (_) {}
  }

  Future<void> clear(String? userId) async {
    await _storage.delete(key: _keyForUser(userId));
  }
}
