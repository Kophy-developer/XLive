import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class GiphyGif {
  const GiphyGif({
    required this.id,
    required this.title,
    required this.previewUrl,
    required this.url,
  });

  final String id;
  final String title;
  final String previewUrl;
  final String url;
}

String _imageUrl(dynamic images, List<String> keys) {
  if (images is! Map) return '';
  for (final key in keys) {
    final node = images[key];
    if (node is Map) {
      final url = node['url']?.toString() ?? '';
      if (url.isNotEmpty) return url;
    }
  }
  return '';
}

GiphyGif? _parse(dynamic raw) {
  if (raw is! Map) return null;
  final id = raw['id']?.toString() ?? '';
  final images = raw['images'];
  final url = _imageUrl(images, const ['downsized', 'fixed_height', 'original']);
  final preview = _imageUrl(images, const ['fixed_width_small', 'preview_gif', 'fixed_height_small']);
  if (id.isEmpty || url.isEmpty) return null;
  return GiphyGif(
    id: id,
    title: raw['title']?.toString() ?? 'GIF',
    previewUrl: preview.isEmpty ? url : preview,
    url: url,
  );
}

Future<List<GiphyGif>> _fetch(String path, Map<String, String> extra) async {
  final key = ApiConfig.staging.giphyApiKey;
  if (key.isEmpty) throw Exception('Giphy is not configured.');
  final params = <String, String>{
    'api_key': key,
    'rating': 'pg-13',
    'limit': '24',
    ...extra,
  };
  final uri = Uri.https('api.giphy.com', '/v1/gifs/$path', params);
  final res = await http.get(uri);
  final body = jsonDecode(res.body);
  if (res.statusCode < 200 || res.statusCode >= 300) {
    final message = body is Map ? body['message']?.toString() : null;
    throw Exception(message ?? 'Could not load GIFs.');
  }
  final data = body is Map ? body['data'] : null;
  if (data is! List) return const [];
  return data.map(_parse).whereType<GiphyGif>().toList();
}

Future<List<GiphyGif>> searchGiphy(String query) {
  final q = query.trim();
  if (q.isEmpty) return listTrendingGiphy();
  return _fetch('search', {'q': q});
}

Future<List<GiphyGif>> listTrendingGiphy() {
  return _fetch('trending', const {});
}
