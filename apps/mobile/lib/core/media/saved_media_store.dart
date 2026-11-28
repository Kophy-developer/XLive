import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_json.dart';
import '../session/auth_session.dart';
import '../../features/social/models/social_models.dart';
import '../../features/videos/videos_repository.dart';

class SavedMediaRef {
  const SavedMediaRef({
    required this.targetId,
    required this.savedAt,
    this.targetType = 'video',
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
      targetType: _normalizeType(ApiJson.pickString(json, ['targetType', 'type']) ?? 'video'),
      targetId: (ApiJson.pickString(json, ['targetId', 'id', '_id', 'videoId']) ?? '').trim(),
      savedAt: DateTime.tryParse(ApiJson.pickString(json, ['savedAt', 'createdAt']) ?? '') ?? DateTime.now().toUtc(),
    );
  }

  factory SavedMediaRef.fromDetail(MediaDetail detail) {
    return SavedMediaRef(
      targetType: detail.targetType,
      targetId: detail.id,
      savedAt: detail.createdAt?.toUtc() ?? DateTime.now().toUtc(),
    );
  }
}

String _normalizeType(String targetType) {
  final t = targetType.trim().toLowerCase();
  if (t.isEmpty || t == 'post' || t == 'reel' || t == 'photo' || t == 'image') return 'video';
  return t;
}

bool canSaveMediaType(String targetType) {
  final t = _normalizeType(targetType);
  return t != 'clip' && t != 'stream';
}

class SavedMediaStore extends ChangeNotifier {
  SavedMediaStore._();

  static final SavedMediaStore instance = SavedMediaStore._();

  static const _storageKeyPrefix = 'xlive_saved_media_v3_';

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

  bool isSavedAll(Iterable<String> targetIds) {
    final ids = _uniqueIds(targetIds);
    if (ids.isEmpty) return false;
    return ids.every((id) => isSaved('video', id));
  }

  static List<String> _uniqueIds(Iterable<String> targetIds) {
    final seen = <String>{};
    final ids = <String>[];
    for (final raw in targetIds) {
      final id = raw.trim();
      if (id.isEmpty || !seen.add(id)) continue;
      ids.add(id);
    }
    return ids;
  }

  Future<void> ensureLoaded({bool force = false}) async {
    if (_loaded && !force) return;
    final existing = _loadFuture;
    if (existing != null && !force) {
      await existing;
      return;
    }
    final future = _sync(force: force);
    _loadFuture = future;
    try {
      await future;
    } finally {
      if (identical(_loadFuture, future)) _loadFuture = null;
    }
  }

  Future<List<MediaDetail>> fetchSavedDetails({int page = 1, int limit = 100}) async {
    final details = await _videos.listSavedVideos(page: page, limit: limit);
    replaceWithDetails(details);
    return details;
  }

  void replaceWithDetails(List<MediaDetail> details) {
    final next = [
      for (final d in details)
        if (d.id.isNotEmpty) SavedMediaRef.fromDetail(d),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    _items
      ..clear()
      ..addAll(next);
    _loaded = true;
    notifyListeners();
    unawaited(_persistLocal());
  }

  Future<void> _sync({bool force = false}) async {
    final userId = AuthSession.instance.user?.id ?? await AuthSession.instance.sessionStore.readUserId();
    if (userId == null || userId.isEmpty) {
      _items.clear();
      _loaded = true;
      notifyListeners();
      return;
    }

    if (!_loaded || force) {
      final local = await _readLocal(userId);
      if (local.isNotEmpty && _items.isEmpty) {
        _items
          ..clear()
          ..addAll(local);
        notifyListeners();
      }
      _loaded = true;
    }

    try {
      final remote = await _videos.listSavedVideos(page: 1, limit: 100);
      final next = [
        for (final d in remote)
          if (d.id.isNotEmpty) SavedMediaRef.fromDetail(d),
      ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
      _items
        ..clear()
        ..addAll(next);
      await _writeLocal(userId, _items);
      notifyListeners();
    } catch (_) {
      if (force && _items.isEmpty) rethrow;
    }
  }

  Future<bool> toggle({
    required String targetType,
    required String targetId,
    required bool canView,
    List<String>? targetIds,
  }) async {
    final ids = _uniqueIds([
      ...?targetIds,
      if (targetId.trim().isNotEmpty) targetId,
    ]);
    return toggleAll(targetType: targetType, targetIds: ids, canView: canView);
  }

  Future<bool> toggleAll({
    required String targetType,
    required List<String> targetIds,
    required bool canView,
  }) async {
    await ensureLoaded();
    if (!canView) return false;
    final type = _normalizeType(targetType);
    final ids = _uniqueIds(targetIds);
    if (ids.isEmpty) return false;
    if (!canSaveMediaType(type)) {
      throw StateError('Only posts and videos can be saved.');
    }
    if (isSavedAll(ids)) {
      await _unsaveMany(type, ids);
      return false;
    }
    await _saveMany(type, ids);
    return true;
  }

  Future<void> save(String targetType, String targetId) async {
    await _saveMany(_normalizeType(targetType), _uniqueIds([targetId]));
  }

  Future<void> unsave(String targetType, String targetId) async {
    await _unsaveMany(_normalizeType(targetType), _uniqueIds([targetId]));
  }

  Future<void> _saveMany(String targetType, List<String> ids) async {
    await ensureLoaded();
    if (ids.isEmpty) return;
    if (!canSaveMediaType(targetType)) {
      throw StateError('Only posts and videos can be saved.');
    }
    final missing = [for (final id in ids) if (!isSaved(targetType, id)) id];
    if (missing.isEmpty) return;

    final now = DateTime.now().toUtc();
    final added = [
      for (final id in missing) SavedMediaRef(targetType: targetType, targetId: id, savedAt: now),
    ];
    _items.insertAll(0, added);
    notifyListeners();
    await _persistLocal();

    try {
      await Future.wait([for (final id in missing) _videos.saveVideo(id)]);
    } catch (_) {
      _items.removeWhere((e) => missing.contains(e.targetId));
      notifyListeners();
      await _persistLocal();
      try {
        await ensureLoaded(force: true);
      } catch (_) {}
      rethrow;
    }
  }

  Future<void> _unsaveMany(String targetType, List<String> ids) async {
    await ensureLoaded();
    if (ids.isEmpty) return;
    final idSet = ids.toSet();
    final removed = _items.where((e) => idSet.contains(e.targetId)).toList();
    _items.removeWhere((e) => idSet.contains(e.targetId));
    notifyListeners();
    await _persistLocal();

    try {
      await Future.wait([for (final id in ids) _videos.unsaveVideo(id)]);
    } catch (_) {
      for (final r in removed.reversed) {
        if (!_items.any((e) => e.targetId == r.targetId)) {
          _items.insert(0, r);
        }
      }
      notifyListeners();
      await _persistLocal();
      try {
        await ensureLoaded(force: true);
      } catch (_) {}
      rethrow;
    }
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
