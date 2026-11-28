import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/media/content_unlock_store.dart';
import '../../core/notifications/in_app_notification_store.dart';
import '../../core/notifications/push_notification_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../core/session/session_store.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/auth/models/auth_models.dart';
import '../../features/chats/chats_repository.dart';
import '../../features/notifications/notifications_repository.dart';
import '../../features/users/models/user_models.dart';
import '../../features/users/users_repository.dart';
import '../../features/wallet/wallet_repository.dart';
import '../subscriptions/subscription_store.dart';

class AuthSession extends ChangeNotifier {
  AuthSession._({
    ApiClient? client,
    AuthRepository? authRepository,
    UsersRepository? usersRepository,
    SettingsRepository? settingsRepository,
  })  : _client = client ?? ApiClient(),
        _auth = authRepository ?? AuthRepository(),
        _users = usersRepository ?? UsersRepository(),
        _settings = settingsRepository ?? SettingsRepository();

  static final AuthSession instance = AuthSession._();

  final ApiClient _client;
  final AuthRepository _auth;
  final UsersRepository _users;
  final SettingsRepository _settings;

  XLiveUser? _user;
  AppSettings? _settingsState;
  String? _identifier;
  bool _loaded = false;
  bool _busy = false;
  int? _walletBalance;
  int _unreadTotal = 0;
  int _notificationUnread = 0;
  bool _socketRefreshBound = false;
  bool _creatorMode = false;

  XLiveUser? get user => _user;
  AppSettings? get settings => _settingsState;
  String? get identifier => _identifier;
  bool get isLoaded => _loaded;
  bool get isBusy => _busy;
  bool get isSignedIn => _user != null;
  bool get isCreator => _user?.isCreator ?? false;
  bool get creatorMode => _creatorMode;
  int? get walletBalance => _walletBalance;
  int get unreadTotal => _unreadTotal;
  int get notificationUnread => _notificationUnread;

  Future<void> load() async {
    final jwt = await _client.sessionStore.readJwt();
    if (jwt == null || jwt.isEmpty) {
      _loaded = true;
      notifyListeners();
      return;
    }
    _identifier = await _client.sessionStore.readIdentifier();
    _creatorMode = await _client.sessionStore.readCreatorMode();
    try {
      await Future.wait([
        refreshProfile(),
        refreshWallet(),
        refreshUnread(),
        refreshNotificationUnread(),
      ]);
      _bindSocketRefresh();
      InAppNotificationStore.instance.bindSocket();
      unawaited(XLiveSocketClient.instance.connectIfSignedIn());
      unawaited(PushNotificationService.instance.syncRegistration());
      unawaited(SubscriptionStore.instance.refresh());
      unawaited(ContentUnlockStore.ensureLoaded());
    } catch (_) {
      await signOut();
      _loaded = true;
      notifyListeners();
      return;
    }
    _loaded = true;
    notifyListeners();
  }

  /// Signs in with an email, username or phone number and password via
  /// `POST /auth/login`. Throws [EmailNotVerifiedException] on 403 so the UI can
  /// route an email login to the verification screen.
  Future<void> signInWithCredentials({required String identifier, required String password}) async {
    _setBusy(true);
    try {
      await _finishTokenSignIn(await _auth.login(identifier: identifier, password: password));
    } finally {
      _setBusy(false);
    }
  }

  /// Verifies the account email with the 6-digit code (`POST /auth/verify-email`)
  /// and signs in with the returned JWT. Sets [displayName] on a fresh profile.
  Future<void> verifyEmailAndSignIn({
    required String email,
    required String code,
    String? displayName,
  }) async {
    _setBusy(true);
    try {
      await _finishTokenSignIn(await _auth.verifyEmail(email: email, code: code));
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty && (_user?.displayName?.trim() ?? '').isEmpty) {
        _user = await _users.updateMe(displayName: name);
        notifyListeners();
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _finishTokenSignIn(AuthTokenResult result) async {
    await _persistSession(jwt: result.token, userId: result.userId, identifier: result.identifier);
    _user = result.user;
    notifyListeners();
    unawaited(_hydrateSessionInBackground());
  }

  Future<void> _hydrateSessionInBackground() async {
    _bindSocketRefresh();
    InAppNotificationStore.instance.bindSocket();
    unawaited(XLiveSocketClient.instance.connectIfSignedIn());
    unawaited(PushNotificationService.instance.syncRegistration());
    unawaited(SubscriptionStore.instance.refresh());
    unawaited(ContentUnlockStore.ensureLoaded());
    await Future.wait([
      refreshWallet(),
      refreshUnread(),
      refreshNotificationUnread(),
      () async {
        try {
          _settingsState = await _settings.getSettings();
          notifyListeners();
        } catch (_) {}
      }(),
    ]);
  }

  Future<void> refreshProfile() async {
    _user = await _users.getMe();
    try {
      _settingsState = await _settings.getSettings();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> refreshWallet() async {
    if (!isSignedIn) {
      _walletBalance = null;
      notifyListeners();
      return;
    }
    try {
      final wallet = await WalletRepository().getWallet();
      _walletBalance = wallet.balance;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshUnread() async {
    if (!isSignedIn) {
      _unreadTotal = 0;
      notifyListeners();
      return;
    }
    try {
      final summary = await ChatsRepository().unreadSummary();
      _unreadTotal = summary.total;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> refreshNotificationUnread() async {
    if (!isSignedIn) {
      _notificationUnread = 0;
      notifyListeners();
      return;
    }
    try {
      _notificationUnread = await NotificationsRepository().unreadCount();
      notifyListeners();
    } catch (_) {}
  }

  void _bindSocketRefresh() {
    if (_socketRefreshBound) return;
    _socketRefreshBound = true;
    XLiveSocketClient.instance.onUnreadUpdated.listen((_) => refreshUnread());
    XLiveSocketClient.instance.onNotificationCreated.listen((_) => refreshNotificationUnread());
  }

  Future<XLiveUser> saveProfile({
    String? displayName,
    String? bio,
    String? language,
    String? gender,
  }) async {
    _setBusy(true);
    try {
      _user = await _users.updateMe(
        displayName: displayName,
        bio: bio,
        language: language,
        gender: gender,
      );
      notifyListeners();
      return _user!;
    } finally {
      _setBusy(false);
    }
  }

  Future<XLiveUser> uploadAvatar(List<int> bytes, {String filename = 'avatar.jpg'}) async {
    _setBusy(true);
    try {
      _user = await _users.uploadAvatar(bytes, filename: filename);
      notifyListeners();
      return _user!;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> setCreatorMode(bool enabled) async {
    if (_creatorMode == enabled) return;
    _creatorMode = enabled;
    notifyListeners();
    await _client.sessionStore.writeCreatorMode(enabled);
  }

  Future<AppSettings> saveSettings(AppSettings next) async {
    _setBusy(true);
    try {
      _settingsState = await _settings.updateSettings(next);
      notifyListeners();
      return _settingsState!;
    } finally {
      _setBusy(false);
    }
  }

  /// Changes the signed-in user's password via `POST /auth/change-password`.
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {
    _setBusy(true);
    try {
      await _auth.changePassword(currentPassword: currentPassword, newPassword: newPassword);
    } finally {
      _setBusy(false);
    }
  }

  Future<void> setPasscode(String passcode) async {
    await _users.setPasscode(passcode);
    await _client.sessionStore.writePasscodeEnabled(true);
  }

  Future<void> removePasscode() async {
    await _users.removePasscode();
    await _client.sessionStore.writePasscodeEnabled(false);
  }

  Future<bool> passcodeEnabled() => _client.sessionStore.readPasscodeEnabled();

  Future<void> verifyPasscode(String passcode) async {
    await _users.verifyPasscode(passcode);
  }

  Future<void> signOut() async {
    await PushNotificationService.instance.unregister();
    InAppNotificationStore.instance.unbindSocket();
    InAppNotificationStore.instance.resetForSignOut();
    XLiveSocketClient.instance.disconnect();
    SubscriptionStore.instance.clear();
    ContentUnlockStore.clearAll();
    await _client.sessionStore.clear();
    _user = null;
    _settingsState = null;
    _identifier = null;
    _walletBalance = null;
    _unreadTotal = 0;
    _notificationUnread = 0;
    _creatorMode = false;
    notifyListeners();
  }

  AuthRepository get authRepository => _auth;
  UsersRepository get usersRepository => _users;
  SettingsRepository get settingsRepository => _settings;
  SessionStore get sessionStore => _client.sessionStore;

  Future<void> _persistSession({
    required String jwt,
    required String userId,
    required String identifier,
  }) async {
    await _client.sessionStore.writeSession(jwt: jwt, userId: userId, identifier: identifier);
    _identifier = identifier;
  }

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }
}

String authErrorMessage(Object error) {
  if (error is ApiException) {
    final trimmed = error.message.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  if (error is Exception) return error.toString().replaceFirst('Exception: ', '');
  return error.toString();
}

/// Backend password rule (POST /auth/create and /auth/reset-password validation).
const authPasswordMinLength = 8;

const authPasswordMismatchMessage = "Passwords don't match.";

/// Says exactly what to fix when [password] breaks the backend rule, else null.
String? validateAuthPassword(String password) {
  if (password.isEmpty) return 'Enter a password of at least $authPasswordMinLength characters.';
  final missing = authPasswordMinLength - password.length;
  if (missing > 0) {
    return 'Password must be at least $authPasswordMinLength characters. Add $missing more.';
  }
  return null;
}

/// Password text from a 400 validation error: `error.password` on /auth/create,
/// `error[""]` (e.g. "newPassword must be at least 8 characters") on reset/change.
String? serverPasswordError(Object error) {
  if (error is! ApiException) return null;
  final details = error.details;
  final fields = details is Map ? details['error'] : null;
  if (fields is! Map) return null;
  for (final key in ['password', '']) {
    final value = fields[key];
    if (value is String && value.contains('assword')) return value;
  }
  return null;
}

String mapGenderToApi(String uiGender) {
  return switch (uiGender.toLowerCase()) {
    'male' => 'male',
    'female' => 'female',
    _ => 'prefer_not_to_say',
  };
}

String mapGenderFromApi(String? gender) {
  return switch (gender?.toLowerCase()) {
    'male' => 'Male',
    'female' => 'Female',
    'others' || 'other' => 'Not set',
    'prefer_not_to_say' => 'Not set',
    null || '' => 'Not set',
    _ => 'Not set',
  };
}

String mapLanguageToApi(String uiLanguage) {
  final value = uiLanguage.trim().toLowerCase();
  if (value.startsWith('span') || value == 'es') return 'es';
  if (value.startsWith('fren') || value == 'fr') return 'fr';
  if (value.startsWith('mand') || value.startsWith('chin') || value == 'zh') return 'zh';
  return 'en';
}

String mapLanguageFromApi(String? code) {
  switch ((code ?? '').trim().toLowerCase().split('-').first) {
    case 'es':
      return 'Spanish';
    case 'fr':
      return 'French';
    case 'zh':
      return 'Mandarin';
    case 'en':
    default:
      return 'English';
  }
}
