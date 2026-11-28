import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import '../../core/media/media_url_cache.dart';
import '../clips/models/clip_models.dart';
import '../feed/models/feed_models.dart';
import '../social/models/social_models.dart';

class VideosRepository {
  VideosRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<MediaDetail> uploadVideo(
    List<int> bytes, {
    String filename = 'video.mp4',
    String? title,
    String? caption,
    int? unlockPrice,
    Map<String, String> fields = const {},
  }) async {
    final uploadFields = _buildUploadFields(
      title: title,
      caption: caption,
      unlockPrice: unlockPrice,
      fields: fields,
    );
    final json = await _client.apiUploadMultipart(
      '/api/x-live/videos/upload',
      fieldName: 'file',
      bytes: bytes,
      filename: filename,
      fields: uploadFields,
    );
    return MediaDetail.fromJson(json, FeedContentType.video);
  }

  Future<MediaDetail> uploadVideoFile(
    String filePath, {
    String filename = 'video.mp4',
    String? title,
    String? caption,
    int? unlockPrice,
    Map<String, String> fields = const {},
  }) async {
    final uploadFields = _buildUploadFields(
      title: title,
      caption: caption,
      unlockPrice: unlockPrice,
      fields: fields,
    );
    final json = await _client.apiUploadMultipartFile(
      '/api/x-live/videos/upload',
      fieldName: 'file',
      filePath: filePath,
      filename: filename,
      fields: uploadFields,
    );
    return MediaDetail.fromJson(json, FeedContentType.video);
  }

  Map<String, String> _buildUploadFields({
    String? title,
    String? caption,
    int? unlockPrice,
    Map<String, String> fields = const {},
  }) {
    final uploadFields = Map<String, String>.from(fields);
    if (title != null && title.isNotEmpty) uploadFields['title'] = title;
    if (caption != null && caption.isNotEmpty) uploadFields['caption'] = caption;
    if (unlockPrice != null) uploadFields['unlockPrice'] = '$unlockPrice';
    return uploadFields;
  }

  Future<List<MediaDetail>> listVideos({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet('/api/x-live/videos', query: {'page': '$page', 'limit': '$limit'});
    return ApiJson.listItems(json)
        .map((item) => MediaDetail.fromJson(item, FeedContentType.video))
        .where((v) => v.id.isNotEmpty)
        .toList();
  }

  Future<MediaDetail> getVideo(String videoId) async {
    final json = await _client.apiGet('/api/x-live/videos/$videoId', auth: false);
    return MediaDetail.fromJson(json, FeedContentType.video);
  }

  Future<ClipMediaUrl> getMediaUrl(String videoId) async {
    final cached = MediaUrlCache.peek('video', videoId);
    if (cached != null && (cached.url?.isNotEmpty ?? false)) return cached;
    try {
      final json = await _client.apiGet('/api/x-live/videos/$videoId/media');
      final data = ApiJson.dataMap(json);
      final media = ClipMediaUrl(
        url: ApiJson.pickString(data, ['url', 'mediaUrl', 'videoUrl', 'playbackUrl', 'streamUrl', 'fileUrl']),
        expiresAt: DateTime.tryParse(ApiJson.pickString(data, ['expiresAt', 'expiry']) ?? ''),
      );
      if (media.url != null && media.url!.isNotEmpty) {
        MediaUrlCache.put('video', videoId, media);
        return media;
      }
    } catch (_) {}
    try {
      final detail = await getVideo(videoId);
      if (detail.streamUrl != null && detail.streamUrl!.isNotEmpty) {
        final media = ClipMediaUrl(url: detail.streamUrl, expiresAt: detail.streamExpiresAt);
        MediaUrlCache.put('video', videoId, media);
        return media;
      }
    } catch (_) {}
    return const ClipMediaUrl(url: null);
  }

  Future<MediaDetail> unlockVideo(String videoId) async {
    final json = await _client.apiPost('/api/x-live/videos/$videoId/unlock');
    return MediaDetail.fromJson(json, FeedContentType.video);
  }

  Future<void> saveVideo(String videoId) async {
    await _client.apiPost('/api/x-live/videos/$videoId/save');
  }

  Future<void> unsaveVideo(String videoId) async {
    await _client.apiDelete('/api/x-live/videos/$videoId/save');
  }

  Future<List<MediaDetail>> listSavedVideos({int page = 1, int limit = 50}) async {
    final json = await _client.apiGet(
      '/api/x-live/videos/saved',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json)
        .map((item) => MediaDetail.fromJson(item, FeedContentType.video))
        .where((v) => v.id.isNotEmpty)
        .toList();
  }

  Future<void> deleteVideo(String videoId) async {
    await _client.apiDelete('/api/x-live/videos/$videoId');
  }
}
