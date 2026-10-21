import '../../core/media/image_upload.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_json.dart';
import 'models/user_models.dart';

class UsersRepository {
  UsersRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<XLiveUser> getMe() async {
    final json = await _client.apiGet('/api/x-live/users/me');
    return XLiveUser.fromJson(json);
  }

  Future<XLiveUser> updateMe({
    String? displayName,
    String? bio,
    String? language,
    String? gender,
  }) async {
    final body = <String, dynamic>{};
    if (displayName != null) body['displayName'] = displayName;
    if (bio != null) body['bio'] = bio;
    if (language != null) body['language'] = language;
    if (gender != null) body['gender'] = gender;
    final json = await _client.apiPatch('/api/x-live/users/me', body: body);
    return XLiveUser.fromJson(json);
  }

  Future<XLiveUser> uploadAvatar(List<int> bytes, {String filename = 'avatar.jpg'}) async {
    final prepared = await prepareAvatarUpload(bytes);
    final json = await _client.apiUpload(
      '/api/x-live/users/me/avatar',
      fieldName: 'file',
      bytes: prepared.bytes,
      filename: prepared.filename,
    );
    return XLiveUser.fromJson(json);
  }

  Future<void> changePassword(String newPassword) async {
    await _client.apiPatch('/api/x-live/users/me/password', body: {'newPassword': newPassword});
  }

  Future<void> setPasscode(String passcode) async {
    await _client.apiPut('/api/x-live/users/me/passcode', body: {'passcode': passcode});
  }

  Future<void> verifyPasscode(String passcode) async {
    await _client.apiPost('/api/x-live/users/me/passcode/verify', body: {'passcode': passcode});
  }

  Future<void> removePasscode() async {
    await _client.apiDelete('/api/x-live/users/me/passcode');
  }

  Future<List<XLiveUser>> searchUsers(String query, {int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/users/search',
      query: {'q': query, 'limit': '$limit'},
    );
    final items = ApiJson.listItems(json);
    return items.map(XLiveUser.fromJson).where((u) => u.id.isNotEmpty).toList();
  }

  Future<XLiveUser> getUser(String userId) async {
    final json = await _client.apiGet('/api/x-live/users/$userId');
    return XLiveUser.fromJson(json);
  }

  Future<Map<String, dynamic>> getPresence(String userId) async {
    final json = await _client.apiGet('/api/x-live/users/$userId/presence');
    return ApiJson.dataMap(json);
  }

  Future<Map<String, dynamic>> batchPresence(List<String> userIds) async {
    final json = await _client.apiGet(
      '/api/x-live/users/presence',
      query: {'ids': userIds.join(',')},
    );
    return ApiJson.dataMap(json);
  }

  Future<List<XLiveUser>> listOnline({int page = 1, int limit = 20}) async {
    final json = await _client.apiGet(
      '/api/x-live/users/online',
      query: {'page': '$page', 'limit': '$limit'},
    );
    return ApiJson.listItems(json).map(XLiveUser.fromJson).where((u) => u.id.isNotEmpty).toList();
  }
}

class SettingsRepository {
  SettingsRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<AppSettings> getSettings() async {
    final json = await _client.apiGet('/api/x-live/settings');
    return AppSettings.fromJson(json);
  }

  Future<AppSettings> updateSettings(AppSettings settings) async {
    final json = await _client.apiPatch('/api/x-live/settings', body: settings.toPatchJson());
    return AppSettings.fromJson(json);
  }

  Future<List<ContentFilter>> listContentFilters() async {
    final json = await _client.apiGet('/api/x-live/settings/content-filters');
    return ApiJson.listItems(json).map(ContentFilter.fromJson).where((f) => f.keyword.isNotEmpty).toList();
  }

  Future<void> addContentFilter({required String keyword, required List<String> targets}) async {
    await _client.apiPost(
      '/api/x-live/settings/content-filters',
      body: {'keyword': keyword, 'targets': targets},
    );
  }

  Future<void> removeContentFilter(String keyword) async {
    await _client.apiDelete('/api/x-live/settings/content-filters/$keyword');
  }

  Future<List<XLiveUser>> listBlockedUsers() async {
    final json = await _client.apiGet('/api/x-live/settings/blocks');
    return ApiJson.listItems(json).map(_parseBlockedUser).where((u) => u.id.isNotEmpty).toList();
  }

  XLiveUser _parseBlockedUser(Map<String, dynamic> json) {
    final nested = ApiJson.map(json['user']) ?? ApiJson.map(json['blockedUser']);
    if (nested != null) return XLiveUser.fromJson(nested);
    return XLiveUser.fromJson(json);
  }

  Future<void> blockUser(String userId) async {
    await _client.apiPost('/api/x-live/settings/blocks', body: {'userId': userId});
  }

  Future<void> unblockUser(String userId) async {
    await _client.apiDelete('/api/x-live/settings/blocks/$userId');
  }

  Future<bool> isUserBlocked(String userId) async {
    final users = await listBlockedUsers();
    return users.any((u) => u.id == userId);
  }
}

class ContentFilter {
  const ContentFilter({required this.keyword, this.targets = const []});

  final String keyword;
  final List<String> targets;

  factory ContentFilter.fromJson(Map<String, dynamic> json) {
    final targetsRaw = json['targets'];
    final targets = targetsRaw is List ? targetsRaw.map((e) => e.toString()).toList() : <String>[];
    return ContentFilter(
      keyword: ApiJson.pickString(json, ['keyword', 'word']) ?? '',
      targets: targets,
    );
  }
}
