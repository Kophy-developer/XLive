import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../users/models/user_models.dart';
import 'models/auth_models.dart';

/// Client for the XLive backend auth endpoints (`/api/x-live/auth/*`).
///
/// Every response uses the envelope `{ message, status, statusCode, data, error }`;
/// [ApiClient] turns non-2xx / `status: false` responses into [ApiException]
/// carrying the server's message. `POST /auth/token` is dev/test only and unused.
class AuthRepository {
  AuthRepository({ApiClient? client}) : _client = client ?? ApiClient();

  final ApiClient _client;

  static const _authPath = '/api/x-live/auth';

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body, {bool auth = false}) {
    return _client.apiPost('$_authPath$path', body: body, auth: auth);
  }

  /// `POST /auth/check` → `data: { exists, matchedBy }`. Matches email or phone only.
  Future<bool> checkExists(String variable) async {
    final json = await _post('/check', {'variable': variable.trim()});
    return (json['data'] as Map<String, dynamic>)['exists'] == true;
  }

  /// Throws an [ApiException] with status 409 when the email or phone is already registered.
  Future<void> checkAvailability(String variable) async {
    if (await checkExists(variable)) {
      throw ApiException('This account already exists.', statusCode: 409);
    }
  }

  /// `POST /auth/create`: emails a 6-digit verification code; no token until verified.
  /// Duplicate email/username errors come back as [ApiException] with the server's message.
  Future<void> register({
    required String email,
    required String firstName,
    required String lastName,
    required String username,
    required String phone,
    required String password,
  }) async {
    await _post('/create', {
      'email': email.trim(),
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'username': username.trim(),
      'phone': phone.trim(),
      'password': password,
    });
  }

  Future<void> resendVerification(String email) async {
    await _post('/resend-verification', {'email': email.trim()});
  }

  /// `POST /auth/verify-email` → `data: { token, user }`.
  Future<AuthTokenResult> verifyEmail({required String email, required String code}) async {
    final json = await _post('/verify-email', {'email': email.trim(), 'code': code.trim()});
    return _tokenResult(json, identifier: email.trim());
  }

  /// `POST /auth/login` with email, username or phone → `data: { token, user }`.
  /// Throws [EmailNotVerifiedException] on 403 (email not verified yet); the body
  /// carries the account email even for username/phone logins.
  Future<AuthTokenResult> login({required String identifier, required String password}) async {
    final id = identifier.trim();
    final compactPhone = id.replaceAll(RegExp(r'[\s\-()]'), '');
    final key = id.contains('@')
        ? 'email'
        : RegExp(r'^\+?\d{7,}$').hasMatch(compactPhone)
            ? 'phone'
            : 'username';
    try {
      final json = await _post('/login', {key: key == 'phone' ? compactPhone : id, 'password': password});
      return _tokenResult(json, identifier: id);
    } on ApiException catch (e) {
      if (e.statusCode == 403) {
        final error = (e.details as Map<String, dynamic>)['error'] as Map<String, dynamic>;
        throw EmailNotVerifiedException(message: e.message, email: error['email'] as String);
      }
      rethrow;
    }
  }

  /// `POST /auth/forgot-password` → `data: { sent, expiresInMinutes }`.
  Future<void> forgotPassword(String email) async {
    await _post('/forgot-password', {'email': email.trim()});
  }

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    await _post('/reset-password', {
      'email': email.trim(),
      'code': code.trim(),
      'newPassword': newPassword,
    });
  }

  /// `POST /auth/change-password` (Bearer).
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    await _post(
      '/change-password',
      {'currentPassword': currentPassword, 'newPassword': newPassword},
      auth: true,
    );
  }

  AuthTokenResult _tokenResult(Map<String, dynamic> json, {required String identifier}) {
    final data = json['data'] as Map<String, dynamic>;
    final user = XLiveUser.fromJson(data['user'] as Map<String, dynamic>);
    return AuthTokenResult(
      token: data['token'] as String,
      userId: user.id,
      identifier: identifier,
      user: user,
    );
  }
}
