import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/api_json.dart';
import '../users/models/user_models.dart';
import 'models/auth_models.dart';

class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  Future<void> checkAvailability(String variable) async {
    await _client.authPost('/auth/check', body: {'variable': variable});
  }

  Future<String> register({
    required String email,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String password,
  }) async {
    final json = await _client.authPost(
      '/auth/create',
      body: {
        'email': email,
        'first_name': firstName,
        'last_name': lastName,
        'username': username,
        'phone': phone,
        'password': password,
      },
    );
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      final result = data['result'];
      if (result is Map<String, dynamic>) {
        final id = result['id']?.toString();
        if (id != null && id.isNotEmpty) return id;
      }
    }
    throw ApiException('Registration succeeded but user id was missing');
  }

  Future<void> requestVerificationCode({required String userId, required String type}) async {
    await _client.authPost('/auth/verify-request', body: {'userid': userId, 'type': type});
  }

  Future<void> verifyCode({required String userId, required String code, required String type}) async {
    await _client.authPost('/auth/verify-code', body: {'userid': userId, 'code': code, 'type': type});
  }

  Future<String?> resolveEmailForUsername(String username) async {
    final query = username.trim();
    if (query.isEmpty) return null;
    final json = await _client.apiGet(
      '/api/x-live/users/search',
      query: {'q': query, 'limit': '5'},
      auth: false,
    );
    final normalized = query.toLowerCase();
    for (final item in ApiJson.listItems(json)) {
      final candidate = ApiJson.pickString(item, ['username'])?.toLowerCase();
      if (candidate == normalized) {
        return ApiJson.pickString(item, ['email']);
      }
    }
    return null;
  }

  Future<AuthLoginResult> login({required String identifier, required String password}) async {
    final json = await _client.authPost('/auth/login', body: {'identifier': identifier, 'password': password});
    final data = json['data'];
    Map<String, dynamic>? result;
    if (data is Map<String, dynamic>) {
      final inner = data['result'];
      if (inner is Map<String, dynamic>) {
        result = inner;
      }
    }
    var userId = result?['userId']?.toString() ?? result?['id']?.toString();
    final rawToken = json['token']?.toString();
    final authToken = (rawToken != null && rawToken.isNotEmpty && rawToken != 'null') ? rawToken : null;
    userId ??= ApiJson.jwtSubject(authToken);
    if (userId == null || userId.isEmpty) {
      throw ApiException('Login succeeded but user id was missing');
    }
    return AuthLoginResult(
      userId: userId,
      identifier: identifier,
      needsVerification: json['needsVerification'] == true,
      emailVerified: result?['email_verified'] == true,
      phoneVerified: result?['phone_verified'] == true,
    );
  }

  Future<void> requestPasswordReset(String email) async {
    await _client.authPost('/password/reset-request', body: {'email': email});
  }

  Future<String?> requestPasswordResetWithMeta(String email) async {
    final json = await _client.authPost('/password/reset-request', body: {'email': email});
    final data = json['data'];
    if (data is Map<String, dynamic>) {
      return data['id']?.toString();
    }
    return null;
  }

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
  }) async {
    await _client.authPost(
      '/password/reset',
      body: {'identifier': identifier, 'code': code, 'password': password},
    );
  }

  Future<BridgeTokenResult> generateBridgeToken({
    String? identifier,
    String? username,
    String? email,
    String? phone,
    String? userId,
  }) async {
    final attempts = <Map<String, dynamic>>[];
    final seen = <String>{};

    void add(Map<String, dynamic> body) {
      final key = body.entries.map((e) => '${e.key}:${e.value}').join('|');
      if (seen.add(key)) attempts.add(body);
    }

    final primary = (identifier ?? username ?? email ?? phone ?? '').trim();
    if (primary.isNotEmpty) add({'identifier': primary});
    if (userId != null && userId.isNotEmpty) add({'id': userId});
    if (username != null && username.isNotEmpty) add({'username': username});
    if (email != null && email.isNotEmpty) add({'email': email});
    if (phone != null && phone.isNotEmpty) add({'phone': phone});
    if (identifier != null && identifier.isNotEmpty && identifier != primary) {
      if (identifier.contains('@')) {
        add({'email': identifier});
      } else if (RegExp(r'^\+?\d{7,}$').hasMatch(identifier)) {
        add({'phone': identifier});
      } else {
        add({'username': identifier});
      }
    }

    if (attempts.isEmpty) {
      throw ApiException('Missing bridge token identifier');
    }

    Object? lastError;
    for (final body in attempts) {
      try {
        final json = await _client.apiPost('/api/x-live/auth/token', body: body, auth: false);
        final data = json['data'];
        final payload = data is Map<String, dynamic> ? data : json;
        final token = payload['token']?.toString();
        final userRaw = payload['user'];
        XLiveUser? user;
        String? bridgeUserId;
        if (userRaw is Map<String, dynamic>) {
          user = XLiveUser.fromJson(userRaw);
          bridgeUserId = user.id.isNotEmpty ? user.id : null;
        } else if (userRaw is Map) {
          final mapped = Map<String, dynamic>.from(userRaw);
          user = XLiveUser.fromJson(mapped);
          bridgeUserId = user.id.isNotEmpty ? user.id : null;
        }
        bridgeUserId ??= payload['userId']?.toString();
        if (token == null || token.isEmpty) {
          throw ApiException(json['message']?.toString() ?? 'Bridge token missing');
        }
        return BridgeTokenResult(
          token: token,
          userId: bridgeUserId ?? userId ?? '',
          user: user,
        );
      } on ApiException catch (e) {
        lastError = e;
        if (e.statusCode == 404 || e.statusCode == 400 || e.statusCode == 422) continue;
        rethrow;
      }
    }

    if (lastError is ApiException) throw lastError;
    throw BridgeUserNotFoundException();
  }
}
