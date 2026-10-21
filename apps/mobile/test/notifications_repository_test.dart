import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xlive_mobile/core/network/api_client.dart';
import 'package:xlive_mobile/core/session/session_store.dart';
import 'package:xlive_mobile/features/notifications/notifications_repository.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class _MemoryStorage extends FlutterSecureStorage {
  _MemoryStorage() : super();

  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async =>
      _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    if (value == null) {
      _data.remove(key);
    } else {
      _data[key] = value;
    }
  }

  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    WindowsOptions? wOptions,
    MacOsOptions? mOptions,
  }) async {
    _data.remove(key);
  }
}

void main() {
  test('NotificationsRepository register/remove/status request shapes', () async {
    final calls = <Map<String, dynamic>>[];
    final mock = MockClient((request) async {
      calls.add({
        'method': request.method,
        'path': request.url.path,
        'body': request.body.isEmpty ? null : jsonDecode(request.body),
        'auth': request.headers['authorization'],
      });
      if (request.url.path.endsWith('/notifications/status')) {
        return http.Response(
          jsonEncode({
            'status': true,
            'data': {'enabled': true, 'configured': true},
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        jsonEncode({'status': true, 'data': {}}),
        200,
        headers: {'content-type': 'application/json'},
      );
    });

    final storage = _MemoryStorage();
    await storage.write(key: 'xlive_jwt', value: 'test-jwt');
    final client = ApiClient(
      sessionStore: SessionStore(storage: storage),
      httpClient: mock,
    );
    final repo = NotificationsRepository(client: client);

    final status = await repo.getStatus();
    expect(status.enabled, isTrue);
    expect(status.configured, isTrue);

    await repo.registerDevice(
      token: 'fcm-token-1',
      platform: 'android',
      deviceId: 'device-1',
    );
    await repo.removeDevice(token: 'fcm-token-1');

    expect(calls, hasLength(3));
    expect(calls[0]['method'], 'GET');
    expect(calls[0]['path'], contains('/notifications/status'));
    expect(calls[0]['auth'], 'Bearer test-jwt');

    expect(calls[1]['method'], 'POST');
    expect(calls[1]['path'], contains('/notifications/devices'));
    expect(calls[1]['body'], {
      'token': 'fcm-token-1',
      'platform': 'android',
      'deviceId': 'device-1',
    });

    expect(calls[2]['method'], 'DELETE');
    expect(calls[2]['path'], contains('/notifications/devices'));
    expect(calls[2]['body'], {'token': 'fcm-token-1'});
  });
}
