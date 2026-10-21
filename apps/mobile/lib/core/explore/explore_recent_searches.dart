import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ExploreRecentSearches {
  ExploreRecentSearches._();

  static final ExploreRecentSearches instance = ExploreRecentSearches._();

  static const _key = 'xlive_explore_recent_searches';
  static const _max = 12;

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final List<String> _items = <String>[];
  bool _loaded = false;

  List<String> get items => List.unmodifiable(_items);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final raw = await _storage.read(key: _key);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      _items
        ..clear()
        ..addAll(decoded.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).take(_max));
    } catch (_) {}
  }

  Future<void> push(String query) async {
    await ensureLoaded();
    final t = query.trim();
    if (t.isEmpty) return;
    _items.remove(t);
    _items.insert(0, t);
    while (_items.length > _max) {
      _items.removeLast();
    }
    try {
      await _storage.write(key: _key, value: jsonEncode(_items));
    } catch (_) {}
  }

  Future<void> remove(String query) async {
    await ensureLoaded();
    _items.remove(query.trim());
    try {
      await _storage.write(key: _key, value: jsonEncode(_items));
    } catch (_) {}
  }
}
