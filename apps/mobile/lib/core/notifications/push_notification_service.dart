import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/notifications/notifications_repository.dart';
import '../../src/chats/dm_chat_screen.dart';
import '../../src/chats/group_chat_screen.dart';
import '../../src/integration/push_inbox_screen.dart';
import '../../src/live/live_stream_flow.dart';
import '../firebase/firebase_bootstrap.dart';
import '../navigation/app_navigator.dart';
import '../network/api_friendly_messages.dart';
import '../session/auth_session.dart';
import 'in_app_notification_store.dart';

const _androidChannelId = 'xlive_push';

class PushRegistrationSnapshot {
  const PushRegistrationSnapshot({
    required this.firebaseReady,
    required this.serviceReady,
    required this.signedIn,
    required this.serverEnabled,
    required this.permission,
    required this.tokenPreview,
    required this.registered,
    required this.lastError,
    required this.lastSyncAt,
  });

  final bool firebaseReady;
  final bool serviceReady;
  final bool signedIn;
  final bool? serverEnabled;
  final String permission;
  final String? tokenPreview;
  final bool registered;
  final String? lastError;
  final DateTime? lastSyncAt;
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await FirebaseBootstrap.ensureInitialized();
  if (message.notification != null) return;

  final title = message.data['title']?.toString() ?? 'Xlive';
  final body = message.data['body']?.toString();
  if (body == null || body.isEmpty) return;

  final local = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosInit = DarwinInitializationSettings();
  await local.initialize(settings: const InitializationSettings(android: androidInit, iOS: iosInit));

  if (!kIsWeb && Platform.isAndroid) {
    await local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _androidChannelId,
            'Xlive',
            description: 'Push notifications from Xlive',
            importance: Importance.high,
          ),
        );
  }

  await local.show(
    id: message.hashCode,
    title: title,
    body: body,
    notificationDetails: const NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelId,
        'Xlive',
        channelDescription: 'Push notifications from Xlive',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    ),
  );
}

class PushNotificationService extends ChangeNotifier {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  static const _deviceIdKey = 'xlive_push_device_id';
  static const _tokenKey = 'xlive_fcm_token';

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final NotificationsRepository _repo = NotificationsRepository();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void>? _startFuture;
  bool _ready = false;
  bool? _serverEnabled;
  bool _registered = false;
  String _permission = 'unknown';
  String? _tokenPreview;
  String? _lastError;
  DateTime? _lastSyncAt;

  bool get isReady => FirebaseBootstrap.isInitialized && _ready;

  PushRegistrationSnapshot get snapshot => PushRegistrationSnapshot(
        firebaseReady: FirebaseBootstrap.isInitialized,
        serviceReady: _ready,
        signedIn: AuthSession.instance.isSignedIn,
        serverEnabled: _serverEnabled,
        permission: _permission,
        tokenPreview: _tokenPreview,
        registered: _registered,
        lastError: _lastError,
        lastSyncAt: _lastSyncAt,
      );

  Future<void> start() {
    final existing = _startFuture;
    if (existing != null) return existing;
    late final Future<void> future;
    future = () async {
      try {
        await _startInternal();
      } catch (e, st) {
        if (identical(_startFuture, future)) _startFuture = null;
        _lastError = friendlyApiMessage(e, fallback: e.toString());
        notifyListeners();
        debugPrint('PushNotificationService.start failed: $e');
        Error.throwWithStackTrace(e, st);
      }
    }();
    _startFuture = future;
    return future;
  }

  Future<void> _startInternal() async {
    await FirebaseBootstrap.ensureInitialized();
    if (!FirebaseBootstrap.isInitialized) {
      throw StateError('Firebase failed to initialize');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (_) => _openInbox(),
    );

    if (!kIsWeb && Platform.isAndroid) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _androidChannelId,
              'Xlive',
              description: 'Push notifications from Xlive',
              importance: Importance.high,
            ),
          );
    }

    final messaging = FirebaseMessaging.instance;
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageOpened);
    messaging.onTokenRefresh.listen(_onTokenRefresh);

    final saved = await _storage.read(key: _tokenKey);
    if (saved != null && saved.isNotEmpty) {
      _tokenPreview = _previewToken(saved);
    }

    _ready = true;
    _lastError = null;
    notifyListeners();

    unawaited(_consumeInitialMessage());
  }

  Future<void> _consumeInitialMessage() async {
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (initial == null) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _onMessageOpened(initial));
    } catch (e) {
      debugPrint('PushNotificationService initial message failed: $e');
    }
  }

  Future<PushRegistrationSnapshot> syncRegistration({bool force = false}) async {
    try {
      if (!FirebaseBootstrap.isInitialized) {
        await FirebaseBootstrap.ensureInitialized();
      }
      if (!FirebaseBootstrap.isInitialized) {
        _lastError = 'Firebase is not initialized on this build.';
        _registered = false;
        _lastSyncAt = DateTime.now();
        notifyListeners();
        return snapshot;
      }
      if (!_ready) await start();
      if (!AuthSession.instance.isSignedIn) {
        _lastError = 'Sign in to register this device for push.';
        _registered = false;
        _lastSyncAt = DateTime.now();
        notifyListeners();
        return snapshot;
      }

      try {
        final status = await _repo.getStatus();
        _serverEnabled = status.enabled || status.configured;
      } catch (e) {
        _serverEnabled = null;
        debugPrint('Push status check failed: $e');
      }

      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      _permission = settings.authorizationStatus.name;
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        _lastError = 'Notification permission denied.';
        _registered = false;
        _lastSyncAt = DateTime.now();
        notifyListeners();
        return snapshot;
      }

      if (!kIsWeb && Platform.isAndroid) {
        final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        final granted = await android?.requestNotificationsPermission();
        if (granted == false) {
          _permission = 'denied';
          _lastError = 'Android notification permission denied.';
          _registered = false;
          _lastSyncAt = DateTime.now();
          notifyListeners();
          return snapshot;
        }
      }

      if (!AuthSession.instance.isSignedIn) {
        _lastError = 'Sign in to register this device for push.';
        _registered = false;
        _lastSyncAt = DateTime.now();
        notifyListeners();
        return snapshot;
      }

      final token = await messaging.getToken();
      if (token == null || token.isEmpty) {
        _lastError = 'FCM token is empty. Check google-services / GoogleService-Info setup.';
        _tokenPreview = null;
        _registered = false;
        _lastSyncAt = DateTime.now();
        notifyListeners();
        return snapshot;
      }

      final previous = await _storage.read(key: _tokenKey);
      _tokenPreview = _previewToken(token);
      await _storage.write(key: _tokenKey, value: token);
      if (force || previous != token || !_registered) {
        await _registerToken(token);
      }
      _registered = true;
      _lastError = null;
      _lastSyncAt = DateTime.now();
      notifyListeners();
      debugPrint('PushNotificationService registered token $_tokenPreview');
      return snapshot;
    } catch (e) {
      _registered = false;
      _lastError = friendlyApiMessage(e, fallback: e.toString());
      _lastSyncAt = DateTime.now();
      notifyListeners();
      debugPrint('PushNotificationService.syncRegistration failed: $e');
      return snapshot;
    }
  }

  Future<void> unregister() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      if (token == null || token.isEmpty) return;
      await _repo.removeDevice(token: token);
      _registered = false;
      notifyListeners();
    } catch (e) {
      _lastError = friendlyApiMessage(e, fallback: e.toString());
      notifyListeners();
      debugPrint('PushNotificationService.unregister failed: $e');
    }
  }

  Future<void> showLocalTestNotification() async {
    if (!_ready) await start();
    await _local.show(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: 'Xlive test',
      body: 'Local notifications are working on this device.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          'Xlive',
          channelDescription: 'Push notifications from Xlive',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  Future<void> _onTokenRefresh(String token) async {
    try {
      await _storage.write(key: _tokenKey, value: token);
      _tokenPreview = _previewToken(token);
      if (AuthSession.instance.isSignedIn) {
        await _registerToken(token);
        _registered = true;
        _lastError = null;
      }
      notifyListeners();
    } catch (e) {
      _lastError = friendlyApiMessage(e, fallback: e.toString());
      notifyListeners();
      debugPrint('PushNotificationService token refresh failed: $e');
    }
  }

  Future<void> _registerToken(String token) async {
    final deviceId = await _ensureDeviceId();
    await _repo.registerDevice(
      token: token,
      platform: Platform.isIOS ? 'ios' : 'android',
      deviceId: deviceId,
    );
  }

  Future<String> _ensureDeviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    await _storage.write(key: _deviceIdKey, value: id);
    return id;
  }

  String _previewToken(String token) {
    if (token.length <= 16) return token;
    return '${token.substring(0, 8)}…${token.substring(token.length - 6)}';
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    try {
      final title = message.notification?.title ??
          message.data['title']?.toString() ??
          'Xlive';
      final body = message.notification?.body ?? message.data['body']?.toString();

      InAppNotificationStore.instance.ingestRemotePush(
        title: title,
        body: body,
        data: Map<String, dynamic>.from(message.data),
      );

      if (kIsWeb || Platform.isIOS) return;

      await _local.show(
        id: message.hashCode,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _androidChannelId,
            'Xlive',
            channelDescription: 'Push notifications from Xlive',
            importance: Importance.high,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.messageId,
      );
    } catch (e) {
      debugPrint('PushNotificationService foreground message failed: $e');
    }
  }

  void _onMessageOpened(RemoteMessage message) {
    try {
      final title = message.notification?.title ??
          message.data['title']?.toString() ??
          'Xlive';
      final body = message.notification?.body ?? message.data['body']?.toString();
      final data = Map<String, dynamic>.from(message.data);
      InAppNotificationStore.instance.ingestRemotePush(
        title: title,
        body: body,
        data: data,
      );
      _openFromPayload(data);
    } catch (e) {
      debugPrint('PushNotificationService open message failed: $e');
    }
  }

  void _openFromPayload(Map<String, dynamic> data) {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    final type = (data['type'] ?? data['event'] ?? data['kind'] ?? '').toString();
    final streamId = (data['streamId'] ?? '').toString();
    final chatId = (data['chatId'] ?? data['dmChatId'] ?? '').toString();
    final groupId = (data['groupId'] ?? '').toString();

    if (type.contains('stream_invite_incoming') || type == 'stream_invite_incoming') {
      navigator.pushNamed('/live');
      return;
    }
    if (streamId.isNotEmpty &&
        (type.contains('stream') || type.contains('gift') || type.contains('invite') || type.contains('live'))) {
      final role = (data['role'] ?? '').toString().toLowerCase();
      navigator.pushNamed(
        '/live/during',
        arguments: LiveDuringArgs(
          streamId: streamId,
          isCohost: role == 'cohost' || role == 'co-host',
        ),
      );
      return;
    }
    if (chatId.isNotEmpty) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => DmChatScreen(
            chatId: chatId,
            peerName: (data['senderName'] ?? data['peerName'] ?? 'Chat').toString(),
            peerAvatarUrl: (data['senderAvatarUrl'] ?? data['avatarUrl'] ?? '').toString(),
            peerUserId: data['senderId']?.toString() ?? data['peerUserId']?.toString(),
          ),
        ),
      );
      return;
    }
    if (groupId.isNotEmpty) {
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => GroupChatScreen(
            groupId: groupId,
            groupName: (data['groupName'] ?? data['name'] ?? 'Group').toString(),
            avatarUrl: (data['groupAvatarUrl'] ?? data['avatarUrl'] ?? '').toString(),
          ),
        ),
      );
      return;
    }
    _openInbox();
  }

  void _openInbox() {
    final navigator = rootNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.push(
      MaterialPageRoute<void>(builder: (_) => const PushInboxScreen()),
    );
  }
}
