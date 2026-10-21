import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionStore {
  SessionStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  static const _jwtKey = 'xlive_jwt';
  static const _userIdKey = 'xlive_user_id';
  static const _identifierKey = 'xlive_identifier';
  static const _passcodeKey = 'xlive_passcode_enabled';
  static const _creatorModeKey = 'xlive_creator_mode';
  static const _captionsEnabledKey = 'xlive_live_captions_enabled';
  static const _aiTranslatorToastShownKey = 'xlive_ai_translator_toast_shown';
  static const _loginAliasPrefix = 'xlive_login_alias_';

  final FlutterSecureStorage _storage;

  Future<String?> readJwt() => _storage.read(key: _jwtKey);

  Future<String?> readUserId() => _storage.read(key: _userIdKey);

  Future<String?> readIdentifier() => _storage.read(key: _identifierKey);

  Future<String?> readLoginAlias(String username) {
    final key = username.trim().toLowerCase();
    if (key.isEmpty) return Future.value(null);
    return _storage.read(key: '$_loginAliasPrefix$key');
  }

  Future<void> writeLoginAlias(String username, String email) async {
    final key = username.trim().toLowerCase();
    final value = email.trim();
    if (key.isEmpty || value.isEmpty) return;
    await _storage.write(key: '$_loginAliasPrefix$key', value: value);
  }

  Future<bool> readCreatorMode() async {
    return (await _storage.read(key: _creatorModeKey)) == '1';
  }

  Future<void> writeCreatorMode(bool enabled) async {
    await _storage.write(key: _creatorModeKey, value: enabled ? '1' : '0');
  }

  Future<bool> readPasscodeEnabled() async {
    return (await _storage.read(key: _passcodeKey)) == '1';
  }

  Future<void> writePasscodeEnabled(bool enabled) async {
    await _storage.write(key: _passcodeKey, value: enabled ? '1' : '0');
  }

  Future<bool> readLiveCaptionsEnabled() async {
    final raw = await _storage.read(key: _captionsEnabledKey);
    if (raw == null) return true;
    return raw == '1';
  }

  Future<void> writeLiveCaptionsEnabled(bool enabled) async {
    await _storage.write(key: _captionsEnabledKey, value: enabled ? '1' : '0');
  }

  Future<bool> readAiTranslatorToastShown() async {
    return (await _storage.read(key: _aiTranslatorToastShownKey)) == '1';
  }

  Future<void> writeAiTranslatorToastShown() async {
    await _storage.write(key: _aiTranslatorToastShownKey, value: '1');
  }

  Future<void> writeSession({
    required String jwt,
    required String userId,
    required String identifier,
  }) async {
    await _storage.write(key: _jwtKey, value: jwt);
    await _storage.write(key: _userIdKey, value: userId);
    await _storage.write(key: _identifierKey, value: identifier);
  }

  Future<void> clear() async {
    await _storage.delete(key: _jwtKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _identifierKey);
    await _storage.delete(key: _creatorModeKey);
  }
}
