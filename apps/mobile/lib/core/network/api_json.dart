import 'dart:convert';

class ApiJson {
  static Map<String, dynamic> dataMap(Map<String, dynamic> json) {
    final data = json['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    final msg = json['message'];
    if (msg is Map<String, dynamic>) return msg;
    if (msg is Map) return Map<String, dynamic>.from(msg);
    final item = json['item'];
    if (item is Map<String, dynamic>) return item;
    if (item is Map) return Map<String, dynamic>.from(item);
    return json;
  }

  static List<Map<String, dynamic>> listItems(Map<String, dynamic> json) {
    final raw = json['data'];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList();
    }
    final data = dataMap(json);
    for (final key in ['items', 'docs', 'results', 'data', 'users', 'following', 'videos', 'posts', 'feed', 'creators', 'saved', 'notifications', 'messages', 'chat']) {
      final list = data[key];
      if (list is List) {
        return list.whereType<Map<String, dynamic>>().toList();
      }
    }
    return const [];
  }

  static String? string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int intValue(Object? value, {int fallback = 0}) {
    if (value == null) return fallback;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is List || value is Map) return fallback;
    return int.tryParse(value.toString()) ?? fallback;
  }

  static int? metricIntOrNull(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is List || value is Map) return null;
    return int.tryParse(value.toString());
  }

  static bool boolValue(Object? value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().toLowerCase();
    if (text == 'true' || text == '1') return true;
    if (text == 'false' || text == '0') return false;
    return fallback;
  }

  static Map<String, dynamic>? map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  static String? pickString(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = string(json[key]);
      if (value != null) return value;
    }
    return null;
  }

  static int pickInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0}) {
    for (final key in keys) {
      if (json[key] != null) return intValue(json[key], fallback: fallback);
    }
    return fallback;
  }

  static int pickMetricInt(Map<String, dynamic> json, List<String> keys, {int fallback = 0, int depth = 0}) {
    if (depth > 4) return fallback;
    for (final key in keys) {
      final parsed = metricIntOrNull(json[key]);
      if (parsed != null) return parsed;
    }
    for (final nestedKey in ['stats', 'metrics', 'analytics', 'engagement', 'insights']) {
      final nested = map(json[nestedKey]);
      if (nested == null) continue;
      final value = pickMetricInt(nested, keys, fallback: -1, depth: depth + 1);
      if (value >= 0) return value;
    }
    for (final nestedKey in ['video', 'clip', 'post', 'stream', 'data', 'item', 'content']) {
      final nested = map(json[nestedKey]);
      if (nested == null) continue;
      final value = pickMetricInt(nested, keys, fallback: -1, depth: depth + 1);
      if (value >= 0) return value;
    }
    return fallback;
  }

  static String formatCount(int value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(1)}k';
    return '$value';
  }

  static String? jwtSubject(String? token) {
    if (token == null || token.isEmpty) return null;
    final parts = token.split('.');
    if (parts.length < 2) return null;
    try {
      var payload = parts[1];
      final mod = payload.length % 4;
      if (mod > 0) payload += '=' * (4 - mod);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return string(map['sub']);
    } catch (_) {}
    return null;
  }
}
