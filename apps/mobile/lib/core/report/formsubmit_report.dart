import 'dart:convert';

import 'package:http/http.dart' as http;

const formSubmitReportUrl = 'https://formsubmit.co/ajax/diligentsamuel@gmail.com';

Future<void> sendProfileReport({
  required String reportedUserId,
  required String reportedHandle,
  String? reportedName,
  required String reason,
  String? reporterId,
  String? reporterHandle,
}) async {
  final trimmed = reason.trim();
  if (trimmed.length < 8) {
    throw Exception('Please explain what happened.');
  }
  final handle = reportedHandle.startsWith('@') ? reportedHandle : '@$reportedHandle';
  final res = await http.post(
    Uri.parse(formSubmitReportUrl),
    headers: const {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({
      '_subject': 'XLive report · $handle',
      '_template': 'table',
      '_captcha': 'false',
      'name': 'XLive App Report',
      'email': 'reports@xlive.app',
      'platform': 'app',
      'reported_handle': handle,
      'reported_name': reportedName ?? '',
      'reported_user_id': reportedUserId,
      'reporter_handle': reporterHandle ?? '',
      'reporter_user_id': reporterId ?? '',
      'reason': trimmed,
      'message':
          'Reported: $handle (${reportedName ?? 'n/a'})\nUser ID: $reportedUserId\nReporter: ${reporterHandle ?? 'unsigned'} (${reporterId ?? 'n/a'})\nPlatform: app\n\n$trimmed',
    }),
  );
  if (res.statusCode < 200 || res.statusCode >= 300) {
    throw Exception('Could not send report.');
  }
  final body = jsonDecode(res.body);
  if (body is Map && body['success'] == false) {
    throw Exception('Could not send report.');
  }
}
