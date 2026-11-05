import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_json.dart';
import '../session/auth_session.dart';
import '../../features/videos/videos_repository.dart';

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
      targetId: (ApiJson.pickString(json, ['targetId', 'id', '_id', 'videoId']) ?? '').trim(),
      savedAt: DateTime.tryParse(ApiJson.pickString(json, ['savedAt', 'createdAt']) ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

class SavedMediaStore extends ChangeNotifier {
  SavedMediaStore._();

  static final SavedMediaStore instance = SavedMediaStore._();

  static const _storageKeyPrefix = 'xlive_saved_media_v2_';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final VideosRepository _videos = VideosRepository();
  final List<SavedMediaRef> _items = [];
  bool _loaded = false;
  Future<void>? _loadFuture;

  List<SavedMediaRef> get items => List.unmodifiable(_items);

  bool isSaved(String targetType, String targetId) {
    final id = targetId.trim();
    if (id.isEmpty) return false;
    return _items.any((e) => e.targetId == id);
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    final existing = _loadFuture;
    if (existing != null && !force) {
      await existing;
      return;
    }
    final future = _load(force: force);
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<void> _load({bool force = false}) async {
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) {
      _items.clear();
      _loaded = true;
      notifyListeners();
      return;
    }

    if (!_loaded || force) {
      final local = await _readLocal(userId);
      _items
        ..clear()
        ..addAll(local);
      _loaded = true;
      notifyListeners();
    }

    try {
      final remote = await _fetchRemoteRefs();
      final byId = <String, SavedMediaRef>{for (final i in remote) i.targetId: i};
      _items
        ..clear()
        ..addAll(byId.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt)));
      await _writeLocal(userId, _items);
      notifyListeners();
    } catch (e) {
      if (force) rethrow;
    }
  }

  Future<List<SavedMediaRef>> _fetchRemoteRefs() async {
    final videos = await _videos.listSavedVideos(page: 1, limit: 100);
    final now = DateTime.now().toUtc();
    return [
      for (final v in videos)
        if (v.id.isNotEmpty)
          SavedMediaRef(
            targetType: 'video',
            targetId: v.id,
            savedAt: now,
          ),
    ];
  }

  Future<bool> toggle({
    required String targetType,
    required String targetId,
    required bool canView,
  }) async {
    await ensureLoaded();
    if (!canView) return false;
    final type = _normalizeType(targetType);
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
    final type = _normalizeType(targetType);
    final id = targetId.trim();
    if (id.isEmpty) return;
    if (isSaved(type, id)) return;

    final ref = SavedMediaRef(targetType: type, targetId: id, savedAt: DateTime.now().toUtc());
    _items.insert(0, ref);
    notifyListeners();
    await _persistLocal();

    try {
      await _videos.saveVideo(id);
    } catch (_) {
      _items.removeWhere((e) => e.targetId == id);
      notifyListeners();
      await _persistLocal();
      rethrow;
    }
  }

  Future<void> unsave(String targetType, String targetId) async {
    await ensureLoaded();
    final id = targetId.trim();
    if (id.isEmpty) return;
    final removed = _items.where((e) => e.targetId == id).toList();
    _items.removeWhere((e) => e.targetId == id);
    notifyListeners();
    await _persistLocal();

    try {
      await _videos.unsaveVideo(id);
    } catch (_) {
      for (final r in removed.reversed) {
        _items.insert(0, r);
      }
      notifyListeners();
      await _persistLocal();
      rethrow;
    }
  }

  String _normalizeType(String targetType) {
    final t = targetType.trim().toLowerCase();
    if (t.isEmpty || t == 'post' || t == 'reel' || t == 'photo') return 'video';
    return t;
  }

  Future<void> _persistLocal() async {
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) return;
    await _writeLocal(userId, _items);
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
}
