import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../session/session_store.dart';
import 'api_exception.dart';
import 'api_friendly_messages.dart';

class ApiClient {
  ApiClient({
    ApiConfig config = ApiConfig.staging,
    SessionStore? sessionStore,
    http.Client? httpClient,
  })  : _config = config,
        _session = sessionStore ?? SessionStore(),
        _http = httpClient ?? http.Client();

  final ApiConfig _config;
  final SessionStore _session;
  final http.Client _http;

  static const _requestTimeout = Duration(seconds: 20);

  /// Called once when a token-bearing request is rejected with 401.
  static Future<void> Function()? onUnauthorized;
  static bool _handlingUnauthorized = false;

  static void _emitUnauthorized() {
    if (_handlingUnauthorized) return;
    _handlingUnauthorized = true;
    final callback = onUnauthorized;
    if (callback == null) {
      _handlingUnauthorized = false;
      return;
    }
    scheduleMicrotask(() async {
      try {
        await callback();
      } finally {
        _handlingUnauthorized = false;
      }
    });
  }

  Map<String, dynamic> _handleResponse(http.Response response, {String? token}) {
    try {
      return _parseResponse(response);
    } on ApiException catch (e) {
      if (e.statusCode == 401 && token != null && token.isNotEmpty) {
        _emitUnauthorized();
      }
      rethrow;
    }
  }

  SessionStore get sessionStore => _session;

  Future<Map<String, dynamic>> authPost(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
  }) {
    return _request(
      baseUrl: _config.authBaseUrl,
      method: 'POST',
      path: path,
      body: body,
      query: query,
      auth: false,
    );
  }

  Future<Map<String, dynamic>> apiGet(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request(
      baseUrl: _config.apiBaseUrl,
      method: 'GET',
      path: path,
      query: query,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> apiPost(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request(
      baseUrl: _config.apiBaseUrl,
      method: 'POST',
      path: path,
      body: body,
      query: query,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> apiPatch(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request(
      baseUrl: _config.apiBaseUrl,
      method: 'PATCH',
      path: path,
      body: body,
      query: query,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> apiPut(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _request(
      baseUrl: _config.apiBaseUrl,
      method: 'PUT',
      path: path,
      body: body,
      query: query,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> apiDelete(
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _request(
      baseUrl: _config.apiBaseUrl,
      method: 'DELETE',
      path: path,
      body: body,
      query: query,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> apiUpload(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    MediaType? contentType,
    bool auth = true,
  }) {
    return apiUploadMultipart(
      path,
      fieldName: fieldName,
      bytes: bytes,
      filename: filename,
      contentType: contentType,
      auth: auth,
    );
  }

  Future<Map<String, dynamic>> apiUploadMultipart(
    String path, {
    required String fieldName,
    required List<int> bytes,
    required String filename,
    MediaType? contentType,
    Map<String, String> fields = const {},
    bool auth = true,
    Duration timeout = const Duration(minutes: 10),
    int maxAttempts = 3,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return _withUploadRetries(
      maxAttempts: maxAttempts,
      attempt: () async {
        final request = await _buildMultipartUploadRequest(
          path,
          fields: fields,
          auth: auth,
        );
        request.files.add(http.MultipartFile.fromBytes(
          fieldName,
          bytes,
          filename: filename,
          contentType: contentType ?? _contentTypeForFilename(filename),
        ));
        return _executeMultipartUpload(
          request,
          timeout: timeout,
          onSendProgress: onSendProgress,
        );
      },
    );
  }

  Future<Map<String, dynamic>> apiUploadMultipartFile(
    String path, {
    required String fieldName,
    required String filePath,
    required String filename,
    MediaType? contentType,
    Map<String, String> fields = const {},
    bool auth = true,
    Duration timeout = const Duration(minutes: 20),
    int maxAttempts = 3,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    return _withUploadRetries(
      maxAttempts: maxAttempts,
      attempt: () async {
        final request = await _buildMultipartUploadRequest(
          path,
          fields: fields,
          auth: auth,
        );
        request.files.add(await http.MultipartFile.fromPath(
          fieldName,
          filePath,
          filename: filename,
          contentType: contentType ?? _contentTypeForFilename(filename),
        ));
        return _executeMultipartUpload(
          request,
          timeout: timeout,
          onSendProgress: onSendProgress,
        );
      },
    );
  }

  Future<http.MultipartRequest> _buildMultipartUploadRequest(
    String path, {
    required Map<String, String> fields,
    required bool auth,
  }) async {
    final uri = Uri.parse('${_config.apiBaseUrl}$path');
    final request = http.MultipartRequest('POST', uri);
    request.headers['Accept'] = 'application/json';
    if (auth) {
      final token = await _session.readJwt();
      if (token == null || token.isEmpty) {
        throw ApiException('Not signed in', statusCode: 401);
      }
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.fields.addAll(fields);
    return request;
  }

  Future<Map<String, dynamic>> _executeMultipartUpload(
    http.MultipartRequest request, {
    required Duration timeout,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    final streamed = await _sendMultipart(request, onSendProgress: onSendProgress).timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);
    final authorization = request.headers['Authorization'];
    final token = authorization != null && authorization.startsWith('Bearer ')
        ? authorization.substring(7)
        : null;
    return _handleResponse(response, token: token);
  }

  Future<T> _withUploadRetries<T>({
    required int maxAttempts,
    required Future<T> Function() attempt,
  }) async {
    Object? lastError;
    for (var i = 0; i < maxAttempts; i++) {
      try {
        return await attempt();
      } catch (e) {
        lastError = e;
        if (!isRetryableNetworkError(e) || i == maxAttempts - 1) rethrow;
        await Future<void>.delayed(Duration(seconds: 1 << i));
      }
    }
    throw lastError!;
  }

  Future<http.StreamedResponse> _sendMultipart(
    http.MultipartRequest request, {
    void Function(int sent, int total)? onSendProgress,
  }) async {
    if (onSendProgress == null) {
      return _http.send(request);
    }
    final total = request.contentLength;
    var sent = 0;
    final byteStream = request.finalize();
    final streamedRequest = http.StreamedRequest(request.method, request.url);
    streamedRequest.contentLength = total;
    request.headers.forEach((key, value) {
      streamedRequest.headers[key] = value;
    });
    byteStream.listen(
      (chunk) {
        streamedRequest.sink.add(chunk);
        sent += chunk.length;
        onSendProgress(sent, total > 0 ? total : sent);
      },
      onDone: streamedRequest.sink.close,
      onError: streamedRequest.sink.addError,
      cancelOnError: true,
    );
    return _http.send(streamedRequest);
  }

  Future<Map<String, dynamic>> _request({
    required String baseUrl,
    required String method,
    required String path,
    Map<String, dynamic>? body,
    Map<String, String>? query,
    required bool auth,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{'Accept': 'application/json'};
    if (body != null) {
      headers['Content-Type'] = 'application/json';
    }
    String? token;
    if (auth) {
      token = await _session.readJwt();
      if (token == null || token.isEmpty) {
        throw ApiException('Not signed in', statusCode: 401);
      }
      headers['Authorization'] = 'Bearer $token';
    }

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await _http.get(uri, headers: headers).timeout(_requestTimeout);
        case 'POST':
          response = await _http
              .post(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(_requestTimeout);
        case 'PATCH':
          response = await _http
              .patch(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(_requestTimeout);
        case 'PUT':
          response = await _http
              .put(uri, headers: headers, body: body == null ? null : jsonEncode(body))
              .timeout(_requestTimeout);
        case 'DELETE':
          response = await _http
              .delete(
                uri,
                headers: headers,
                body: body == null ? null : jsonEncode(body),
              )
              .timeout(_requestTimeout);
        default:
          throw ApiException('Unsupported method $method');
      }
    } on TimeoutException {
      throw ApiException(connectionErrorMessage, statusCode: 408);
    }

    return _handleResponse(response, token: token);
  }

  Map<String, dynamic> _parseResponse(http.Response response) {
    Map<String, dynamic>? json;
    if (response.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          json = decoded;
        }
      } catch (_) {}
    }

    final ok = response.statusCode >= 200 && response.statusCode < 300;
    if (ok) {
      if (json != null && json['status'] == false) {
        final code = json['statusCode'];
        final statusCode = code is int
            ? code
            : int.tryParse('$code') ?? response.statusCode;
        final message =
            _messageFrom(json) ?? _plainBodyMessage(response, json) ?? 'Request failed ($statusCode)';
        throw ApiException(message, statusCode: statusCode, details: json);
      }
      return json ?? <String, dynamic>{};
    }

    final message = _messageFrom(json) ?? _plainBodyMessage(response, json) ?? 'Request failed (${response.statusCode})';
    throw ApiException(message, statusCode: response.statusCode, details: json);
  }

  String? _plainBodyMessage(http.Response response, Map<String, dynamic>? json) {
    if (json != null) return null;
    final body = response.body.trim();
    if (body.isEmpty) return null;
    final lower = body.toLowerCase();
    if (lower.contains('client closed request') || lower.contains('request timeout')) {
      return 'Upload timed out. Try a shorter or smaller video.';
    }
    if (body.length > 200) return null;
    return body;
  }

  String? _messageFrom(Map<String, dynamic>? json) {
    if (json == null) return null;

    String? clean(Object? value) {
      if (value is! String) return null;
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      final lower = trimmed.toLowerCase();
      if (lower == 'success' || lower == 'error' || lower == 'ok') return null;
      if (RegExp(r'^status\s*code\s*:?\s*\d+$').hasMatch(lower)) return null;
      if (RegExp(r'^statuscode\s*:?\s*\d+$').hasMatch(lower.replaceAll(' ', ''))) return null;
      return trimmed;
    }

    final topMessage = clean(json['message']);
    if (topMessage != null) return topMessage;

    final error = json['error'];
    if (error is String) {
      final fromError = clean(error);
      if (fromError != null) return fromError;
    }
    if (error is Map) {
      final nested = clean(error['message']);
      if (nested != null) return nested;
      const skip = {
        'statuscode',
        'status_code',
        'status',
        'code',
        'errorcode',
        'error_code',
        'message',
      };
      final parts = <String>[];
      error.forEach((key, value) {
        final k = key.toString();
        if (skip.contains(k.toLowerCase().replaceAll('_', ''))) return;
        if (value is List && value.isNotEmpty) {
          parts.add('$k: ${value.first}');
        } else if (value != null && value.toString().trim().isNotEmpty) {
          parts.add('$k: $value');
        }
      });
      if (parts.isNotEmpty) return parts.join(', ');
    }

    return null;
  }

  MediaType? _contentTypeForFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    if (lower.endsWith('.heic')) return MediaType('image', 'heic');
    if (lower.endsWith('.heif')) return MediaType('image', 'heif');
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return MediaType('video', 'mp4');
    if (lower.endsWith('.mov')) return MediaType('video', 'quicktime');
    if (lower.endsWith('.webm')) return MediaType('video', 'webm');
    if (lower.endsWith('.avi')) return MediaType('video', 'x-msvideo');
    if (lower.endsWith('.mkv')) return MediaType('video', 'x-matroska');
    if (lower.endsWith('.m4a')) return MediaType('audio', 'mp4');
    if (lower.endsWith('.aac')) return MediaType('audio', 'aac');
    if (lower.endsWith('.mp3')) return MediaType('audio', 'mpeg');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    if (lower.endsWith('.doc')) return MediaType('application', 'msword');
    if (lower.endsWith('.docx')) return MediaType('application', 'vnd.openxmlformats-officedocument.wordprocessingml.document');
    if (lower.endsWith('.xls')) return MediaType('application', 'vnd.ms-excel');
    if (lower.endsWith('.xlsx')) return MediaType('application', 'vnd.openxmlformats-officedocument.spreadsheetml.sheet');
    if (lower.endsWith('.txt')) return MediaType('text', 'plain');
    if (lower.endsWith('.csv')) return MediaType('text', 'csv');
    if (lower.endsWith('.zip')) return MediaType('application', 'zip');
    return null;
  }
}
