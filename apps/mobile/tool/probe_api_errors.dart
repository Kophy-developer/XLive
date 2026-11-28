import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final api = Platform.environment['XLIVE_API'] ?? 'https://xlive-app-bcqre.ondigitalocean.app';
  final username = args.isNotEmpty ? args.first : 'bruiz_flash';
  stdout.writeln('Probing API errors against $api as $username\n');

  final tokRes = await _call(
    api,
    'POST',
    '/api/x-live/auth/token',
    body: {'username': username},
    auth: null,
  );
  final token = ((tokRes.body['data'] as Map?)?['token'] ?? '').toString();
  if (token.isEmpty) {
    stderr.writeln('Could not get token: ${tokRes.code} ${tokRes.body}');
    exit(1);
  }

  final probes = <_Probe>[
    _Probe('unauthorized feed', 'GET', '/api/x-live/feed/followers', auth: false),
    _Probe('invalid interaction action', 'POST', '/api/x-live/feed/interactions', body: {
      'action': 'not_a_real_action',
      'targetType': 'video',
      'targetId': '000000000000000000000000',
    }),
    _Probe('missing video', 'GET', '/api/x-live/videos/000000000000000000000000'),
    _Probe('missing clip media', 'GET', '/api/x-live/clips/000000000000000000000000/media'),
    _Probe('dm missing chat', 'GET', '/api/x-live/chats/000000000000000000000000/messages'),
  ];

  String? chatId;
  final search = await _call(api, 'GET', '/api/x-live/users/search?q=xlive&limit=3', auth: token);
  final users = search.body['data'];
  if (users is List && users.isNotEmpty) {
    final uid = (users.first as Map)['id']?.toString();
    if (uid != null && uid.isNotEmpty) {
      final dm = await _call(api, 'POST', '/api/x-live/chats/dm', body: {'participantId': uid}, auth: token);
      chatId = ((dm.body['data'] as Map?)?['id'] ?? (dm.body['data'] as Map?)?['_id'])?.toString();
    }
  }

  if (chatId != null && chatId.isNotEmpty) {
    probes.add(
      _Probe(
        'message too long ($chatId)',
        'POST',
        '/api/x-live/chats/$chatId/messages',
        body: {'content': 'x' * 2001},
      ),
    );
    probes.add(
      _Probe(
        'empty message',
        'POST',
        '/api/x-live/chats/$chatId/messages',
        body: {'content': ''},
      ),
    );
  }

  final locked = await _call(api, 'GET', '/api/x-live/feed/for-you?limit=20', auth: token);
  final items = ((locked.body['data'] as Map?)?['items'] as List?) ?? const [];
  for (final raw in items) {
    if (raw is! Map) continue;
    final access = raw['access'];
    if (access is Map && access['allowed'] == false) {
      final id = raw['id']?.toString() ?? '';
      final type = raw['type']?.toString() ?? 'video';
      if (id.isEmpty) continue;
      if (type == 'clip') {
        probes.add(_Probe('locked clip media $id', 'GET', '/api/x-live/clips/$id/media'));
      } else {
        probes.add(_Probe('locked video media $id', 'GET', '/api/x-live/videos/$id/media'));
        probes.add(_Probe('unlock without balance $id', 'POST', '/api/x-live/videos/$id/unlock', body: {}));
      }
      break;
    }
  }

  stdout.writeln('${'case'.padRight(36)} code  raw message / error');
  stdout.writeln('-' * 100);
  for (final probe in probes) {
    final res = await _call(
      api,
      probe.method,
      probe.path,
      body: probe.body,
      auth: probe.auth == false ? null : token,
    );
    final msg = res.body['message'];
    final err = res.body['error'];
    stdout.writeln('${probe.label.padRight(36)} ${res.code.toString().padRight(5)} $msg | $err');
  }

  stdout.writeln('''

How to use this with the app:
1. Run: dart run tool/probe_api_errors.dart
2. Copy raw message/error pairs that are ugly.
3. Add a mapping in lib/core/network/api_friendly_messages.dart
4. Cover with a unit test in test/api_friendly_messages_test.dart
''');
}

class _Probe {
  const _Probe(this.label, this.method, this.path, {this.body, this.auth = true});

  final String label;
  final String method;
  final String path;
  final Map<String, dynamic>? body;
  final Object? auth;
}

class _Res {
  const _Res(this.code, this.body);
  final int code;
  final Map<String, dynamic> body;
}

Future<_Res> _call(
  String api,
  String method,
  String path, {
  Map<String, dynamic>? body,
  String? auth,
}) async {
  final headers = <String, String>{'Accept': 'application/json'};
  if (auth != null && auth.isNotEmpty) headers['Authorization'] = 'Bearer $auth';
  List<int>? data;
  if (body != null) {
    headers['Content-Type'] = 'application/json';
    data = utf8.encode(jsonEncode(body));
  }
  final req = await HttpClient().openUrl(method, Uri.parse('$api$path'));
  headers.forEach(req.headers.set);
  if (data != null) req.add(data);
  final res = await req.close().timeout(const Duration(seconds: 25));
  final text = await res.transform(utf8.decoder).join();
  Map<String, dynamic> json;
  try {
    json = jsonDecode(text) as Map<String, dynamic>;
  } catch (_) {
    json = {'message': text};
  }
  return _Res(res.statusCode, json);
}
