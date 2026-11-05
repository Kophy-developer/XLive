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

  Future<void> signInWithCredentials({
    required String identifier,
    required String password,
    String? email,
    String? phone,
    String? username,
  }) async {
    _setBusy(true);
    try {
      final loginIdentifier = identifier.trim();
      final resolvedUsername = username?.trim();
      var resolvedEmail = email ?? (loginIdentifier.contains('@') ? loginIdentifier : null);
      final resolvedPhone = phone ??
          (!loginIdentifier.contains('@') && RegExp(r'^\+?\d{7,}$').hasMatch(loginIdentifier)
              ? loginIdentifier
              : null);
      final isUsernameLogin = resolvedEmail == null &&
          resolvedPhone == null &&
          !loginIdentifier.contains('@');

      late final AuthLoginResult login;

      if (isUsernameLogin) {
        final usernameKey = resolvedUsername ?? loginIdentifier;
        final cachedEmail = await _client.sessionStore.readLoginAlias(usernameKey);
        if (cachedEmail != null && cachedEmail.isNotEmpty) {
          try {
            login = await _auth.login(identifier: cachedEmail, password: password);
            resolvedEmail = cachedEmail;
          } on ApiException catch (cachedError) {
            final emailFromUsername = await _auth.resolveEmailForUsername(usernameKey);
            if (emailFromUsername == null || emailFromUsername.isEmpty) rethrow;
            if (emailFromUsername == cachedEmail) rethrow;
            resolvedEmail = emailFromUsername;
            await _client.sessionStore.writeLoginAlias(usernameKey, emailFromUsername);
            try {
              login = await _auth.login(identifier: emailFromUsername, password: password);
            } on ApiException {
              throw cachedError;
            }
          }
        } else {
          final emailFromUsername = await _auth.resolveEmailForUsername(usernameKey);
          if (emailFromUsername != null && emailFromUsername.isNotEmpty) {
            resolvedEmail = emailFromUsername;
            await _client.sessionStore.writeLoginAlias(usernameKey, emailFromUsername);
            login = await _auth.login(identifier: emailFromUsername, password: password);
          } else {
            try {
              login = await _auth.login(identifier: loginIdentifier, password: password);
            } on ApiException catch (e) {
              throw ApiException(
                'Username not found. Try signing in with your email.',
                statusCode: e.statusCode,
              );
            }
          }
        }
        if (resolvedEmail != null && resolvedEmail.isNotEmpty) {
          unawaited(_client.sessionStore.writeLoginAlias(usernameKey, resolvedEmail));
        }
      } else {
        login = await _auth.login(identifier: loginIdentifier, password: password);
      }

      if (login.needsVerification) {
        throw VerificationRequiredException(
          userId: login.userId,
          identifier: resolvedEmail ?? loginIdentifier,
          verificationType: resolvedEmail != null ? 'email' : 'phone',
          password: password,
          email: resolvedEmail,
          phone: resolvedPhone,
          username: resolvedUsername ?? (!loginIdentifier.contains('@') ? loginIdentifier : null),
        );
      }
      await _finishBridgeSignIn(
        identifier: resolvedEmail ?? loginIdentifier,
        email: resolvedEmail,
        phone: resolvedPhone,
        username: resolvedUsername ?? (!loginIdentifier.contains('@') && resolvedPhone == null ? loginIdentifier : null),
        authUserId: login.userId,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signInAfterRegistration({
    required String email,
    required String password,
    required String username,
    String? displayName,
  }) async {
    _setBusy(true);
    try {
      final login = await _auth.login(identifier: email, password: password);
      if (login.needsVerification) {
        throw VerificationRequiredException(
          userId: login.userId,
          identifier: email,
          verificationType: 'email',
          password: password,
          email: email,
          username: username,
        );
      }
      await _finishBridgeSignIn(
        identifier: email,
        email: email,
        username: username,
        authUserId: login.userId,
      );
      final name = displayName?.trim();
      if (name != null && name.isNotEmpty) {
        final currentName = _user?.displayName?.trim();
        if (currentName == null || currentName.isEmpty) {
          _user = await _users.updateMe(displayName: name);
          notifyListeners();
        }
      }
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signInAfterVerifyCode({
    required String userId,
    required String code,
    required String verificationType,
    required String identifier,
    required String password,
    String? email,
    String? phone,
    String? username,
  }) async {
    _setBusy(true);
    try {
      await _auth.verifyCode(userId: userId, code: code, type: verificationType);
      final login = await _auth.login(identifier: identifier, password: password);
      if (login.needsVerification) {
        throw ApiException('Account still needs verification');
      }
      await _finishBridgeSignIn(
        identifier: identifier,
        email: email ?? (identifier.contains('@') ? identifier : null),
        phone: phone ?? (identifier.contains('@') ? null : identifier),
        username: username,
        authUserId: login.userId,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _finishBridgeSignIn({
    required String identifier,
    String? email,
    String? phone,
    String? username,
    String? authUserId,
  }) async {
    final bridgeIdentifier = (username ?? email ?? phone ?? identifier).trim();
    final bridge = await _auth.generateBridgeToken(
      identifier: bridgeIdentifier,
      email: email ?? (identifier.contains('@') ? identifier : null),
      phone: phone ?? (identifier.contains('@') ? null : (RegExp(r'^\+?\d{7,}$').hasMatch(identifier) ? identifier : null)),
      username: username ?? (!identifier.contains('@') && !RegExp(r'^\+?\d{7,}$').hasMatch(identifier) ? identifier : null),
      userId: authUserId,
    );
    await _persistSession(
      jwt: bridge.token,
      userId: bridge.userId,
      identifier: identifier,
    );
    if (bridge.user != null && bridge.user!.id.isNotEmpty) {
      _user = bridge.user;
    } else {
      _user = await _users.getMe();
    }
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

  Future<void> signInAfterRegister({
    required String identifier,
    required String password,
    required String userId,
    String? email,
    String? phone,
    String? username,
  }) async {
    final resolvedEmail = email ?? (identifier.contains('@') ? identifier : null);
    if (resolvedEmail != null && username != null && username.isNotEmpty) {
      await signInAfterRegistration(
        email: resolvedEmail,
        password: password,
        username: username,
      );
      return;
    }
    await signInWithCredentials(
      identifier: identifier,
      password: password,
      email: email,
      phone: phone,
      username: username,
    );
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

  Future<void> changePassword(String newPassword) async {
    _setBusy(true);
    try {
      await _users.changePassword(newPassword);
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

bool isAuthAccountExistsError(Object error) {
  if (error is ApiException) {
    if (error.statusCode == 409) return true;
    return error.message.toLowerCase().contains('already exist');
  }
  return false;
}

String? validateAuthPassword(String password) {
  if (password.length < 8) return 'Password must be at least 8 characters.';
  if (password.length > 128) return 'Password must be 128 characters or fewer.';
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
  return uiLanguage.toLowerCase().startsWith('eng') ? 'en' : 'en';
}
