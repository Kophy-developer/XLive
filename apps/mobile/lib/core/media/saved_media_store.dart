import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';
import '../network/api_json.dart';
import '../session/auth_session.dart';

class SavedMediaRef {
  const SavedMediaRef({
    required this.targetType,
    required this.targetId,
    required this.savedAt,
  });

  final String targetType;
  final String targetId;
  final DateTime savedAt;

  String get key => '$targetType:$targetId';

  Map<String, dynamic> toJson() => {
        'targetType': targetType,
        'targetId': targetId,
        'savedAt': savedAt.toUtc().toIso8601String(),
      };

  factory SavedMediaRef.fromJson(Map<String, dynamic> json) {
    return SavedMediaRef(
      targetType: (ApiJson.pickString(json, ['targetType', 'type']) ?? 'video').trim(),
      targetId: (ApiJson.pickString(json, ['targetId', 'id', '_id']) ?? '').trim(),
      savedAt: DateTime.tryParse(ApiJson.pickString(json, ['savedAt', 'createdAt']) ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

class SavedMediaStore extends ChangeNotifier {
  SavedMediaStore._();

  static final SavedMediaStore instance = SavedMediaStore._();

  static const _storageKeyPrefix = 'xlive_saved_media_v1_';
  static const _settingsField = 'savedMediaIds';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final ApiClient _client = ApiClient();
  final List<SavedMediaRef> _items = [];
  bool _loaded = false;
  bool _settingsSyncSupported = true;

  List<SavedMediaRef> get items => List.unmodifiable(_items);

  bool isSaved(String targetType, String targetId) {
    final key = '$targetType:$targetId';
    return _items.any((e) => e.key == key);
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) {
      _items.clear();
      _loaded = true;
      return;
    }
    final local = await _readLocal(userId);
    _items
      ..clear()
      ..addAll(local);
    _loaded = true;
    notifyListeners();
    if (_settingsSyncSupported) {
      try {
        await _pullFromSettings(userId);
      } catch (_) {
        _settingsSyncSupported = false;
      }
    }
  }

  Future<bool> toggle({
    required String targetType,
    required String targetId,
    required bool canView,
  }) async {
    await ensureLoaded();
    if (!canView) return false;
    final type = targetType.trim().isEmpty ? 'video' : targetType.trim();
    final id = targetId.trim();
    if (id.isEmpty) return false;
    if (isSaved(type, id)) {
      await unsave(type, id);
      return false;
    }
    await save(type, id);
    return true;
  }

  Future<void> save(String targetType, String targetId) async {
    await ensureLoaded();
    final type = targetType.trim().isEmpty ? 'video' : targetType.trim();
    final id = targetId.trim();
    if (id.isEmpty) return;
    if (isSaved(type, id)) return;
    _items.insert(0, SavedMediaRef(targetType: type, targetId: id, savedAt: DateTime.now().toUtc()));
    notifyListeners();
    await _persist();
  }

  Future<void> unsave(String targetType, String targetId) async {
    await ensureLoaded();
    final key = '$targetType:$targetId';
    _items.removeWhere((e) => e.key == key);
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) return;
    await _writeLocal(userId, _items);
    if (_settingsSyncSupported) {
      try {
        await _pushToSettings();
      } catch (_) {
        _settingsSyncSupported = false;
      }
    }
  }

  Future<List<SavedMediaRef>> _readLocal(String userId) async {
    final raw = await _storage.read(key: '$_storageKeyPrefix$userId');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => SavedMediaRef.fromJson(Map<String, dynamic>.from(e)))
          .where((e) => e.targetId.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _writeLocal(String userId, List<SavedMediaRef> items) async {
    await _storage.write(
      key: '$_storageKeyPrefix$userId',
      value: jsonEncode([for (final i in items.take(500)) i.toJson()]),
    );
  }

  Future<void> _pullFromSettings(String userId) async {
    final json = await _client.apiGet('/api/x-live/settings');
    final data = ApiJson.dataMap(json);
    final raw = data[_settingsField] ?? json[_settingsField];
    if (raw is! List) return;
    final remote = raw
        .whereType<Map>()
        .map((e) => SavedMediaRef.fromJson(Map<String, dynamic>.from(e)))
        .where((e) => e.targetId.isNotEmpty)
        .toList();
    if (remote.isEmpty) return;
    final byKey = <String, SavedMediaRef>{
      for (final i in _items) i.key: i,
      for (final i in remote) i.key: i,
    };
    final merged = byKey.values.toList()
      ..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    _items
      ..clear()
      ..addAll(merged.take(500));
    await _writeLocal(userId, _items);
    notifyListeners();
  }

  Future<void> _pushToSettings() async {
    await _client.apiPatch(
      '/api/x-live/settings',
      body: {
        _settingsField: [for (final i in _items.take(500)) i.toJson()],
      },
    );
  }
}
