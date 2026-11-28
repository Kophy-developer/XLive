import '../config/api_config.dart';

final _hostXLiveUpload = RegExp(
  r'(?:^|/)(?:api/)?uploads/(x-live/[^/?#]+)',
  caseSensitive: false,
);

bool _isSignedCloudinaryUrl(String url) {
  return RegExp(r'/s--[^/]+--/').hasMatch(url);
}

String? _cloudinaryVideoFromHostUpload(String path) {
  final match = _hostXLiveUpload.firstMatch(path.trim());
  if (match == null) return null;
  final publicId = match.group(1)!.replaceAll(RegExp(r'\.[a-z0-9]+$', caseSensitive: false), '');
  if (publicId.length <= 7) return null;
  final cloud = ApiConfig.staging.cloudinaryCloudName;
  return 'https://res.cloudinary.com/$cloud/video/upload/f_mp4/$publicId';
}

String resolveMediaUrl(String? raw, {String? resourceType}) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  if (resourceType != 'image') {
    final fromHost = _cloudinaryVideoFromHostUpload(trimmed);
    if (fromHost != null) return fromHost;
  }
  if (_isSignedCloudinaryUrl(trimmed)) return trimmed;
  var url = trimmed;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    if (resourceType == 'image' && trimmed.contains('/video/upload/')) {
      url = trimmed.replaceFirst('/video/upload/', '/image/upload/');
    } else if (resourceType == 'video' && trimmed.contains('/image/upload/')) {
      url = trimmed.replaceFirst('/image/upload/', '/video/upload/');
    } else {
      url = trimmed;
    }
  } else if (trimmed.startsWith('//')) {
    url = 'https:$trimmed';
  } else {
    final type = resourceType ?? _inferCloudinaryResourceType(trimmed);
    if (type != null) {
      final cloud = ApiConfig.staging.cloudinaryCloudName;
      final path = trimmed.startsWith('/') ? trimmed.substring(1) : trimmed;
      url = 'https://res.cloudinary.com/$cloud/$type/upload/$path';
    } else {
      final base = ApiConfig.staging.apiBaseUrl;
      url = trimmed.startsWith('/') ? '$base$trimmed' : '$base/$trimmed';
    }
  }

  if (resourceType == 'image') return url;
  if (_shouldDeliverMp4(url, resourceType)) {
    return playbackVideoUrl(url);
  }
  return url;
}

String playbackVideoUrl(String? raw) {
  if (raw == null) return '';
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return '';
  final fromHost = _cloudinaryVideoFromHostUpload(trimmed);
  if (fromHost != null) return fromHost;
  if (_isSignedCloudinaryUrl(trimmed)) return trimmed;
  final match = RegExp(
    r'^(https?://res\.cloudinary\.com/[^/]+)/(?:video|image)/upload/(.*)$',
    caseSensitive: false,
  ).firstMatch(trimmed);
  if (match == null) return trimmed;
  final host = match.group(1)!;
  final rest = match.group(2)!;
  if (RegExp(r'\.m3u8(\?|$)', caseSensitive: false).hasMatch(rest) ||
      RegExp(r'\.mpd(\?|$)', caseSensitive: false).hasMatch(rest)) {
    return trimmed;
  }
  if (RegExp(r'(?:^|/|,)f_mp4(?:,|/|$)', caseSensitive: false).hasMatch(rest)) {
    return '$host/video/upload/$rest';
  }
  return '$host/video/upload/f_mp4/$rest';
}

bool _shouldDeliverMp4(String url, String? resourceType) {
  final lower = url.toLowerCase();
  if (lower.contains('.m3u8') || lower.contains('.mpd')) return false;
  if (resourceType == 'video') return true;
  if (lower.contains('/video/upload/')) return true;
  return RegExp(r'\.(mp4|m4v|mov|webm|mkv)(\?|$)').hasMatch(lower);
}

String? _inferCloudinaryResourceType(String path) {
  final lower = path.toLowerCase();
  if (lower.contains('/image/upload/')) return null;
  if (lower.contains('/video/upload/')) return null;
  if (RegExp(r'\.(png|jpe?g|webp|gif|heic|heif)(\?|$)').hasMatch(lower)) return 'image';
  if (RegExp(r'\.(mp4|m4v|mov|webm|mkv)(\?|$)').hasMatch(lower)) return 'video';
  if (lower.startsWith('x-live/') || lower.contains('/x-live/')) return 'video';
  if (RegExp(r'^[a-f0-9-]{36}$').hasMatch(lower)) return 'video';
  return 'video';
}
