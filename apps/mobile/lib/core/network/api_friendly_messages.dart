import 'api_exception.dart';
import 'chat_message_limits.dart';

const connectionErrorMessage = 'Connection error. Please retry.';

bool isRetryableNetworkError(Object e) {
  if (e is ApiException) {
    final code = e.statusCode;
    return code == 408 || code == 502 || code == 503 || code == 504;
  }
  final msg = e.toString().toLowerCase();
  if (msg.contains('timeoutexception')) return true;
  if (msg.contains('connection reset') ||
      msg.contains('connection closed') ||
      msg.contains('connection refused') ||
      msg.contains('network is unreachable') ||
      msg.contains('failed host lookup') ||
      msg.contains('software caused connection abort')) {
    return true;
  }
  return msg.contains('socketexception') || msg.contains('clientexception');
}

bool isBlockedUserError(ApiException e) {
  final msg = _exceptionHaystack(e);
  return (e.statusCode == 400 || e.statusCode == 403) &&
      (msg.contains('block') || msg.contains('blocked'));
}

bool _looksLikeRawHttpError(String msg) {
  final lower = msg.toLowerCase().trim();
  final compact = lower.replaceAll(' ', '');
  if (compact.startsWith('statuscode:') || compact.contains('statuscode:')) return true;
  if (RegExp(r'^statuscode:?\d+$').hasMatch(compact)) return true;
  return lower.contains('status code') ||
      lower.contains('request failed (') ||
      lower == 'bad request' ||
      lower == 'unauthorized' ||
      lower == 'forbidden' ||
      lower == 'payload validation error' ||
      lower == 'success' ||
      lower == 'error' ||
      RegExp(r'^\d{3}$').hasMatch(lower);
}

String _exceptionHaystack(ApiException e) {
  final buf = StringBuffer(e.message);
  void walk(Object? value) {
    if (value == null) return;
    if (value is Map) {
      value.forEach((key, nested) {
        buf
          ..write(' ')
          ..write(key)
          ..write(' ');
        walk(nested);
      });
      return;
    }
    if (value is List) {
      for (final nested in value) {
        walk(nested);
      }
      return;
    }
    buf
      ..write(' ')
      ..write(value);
  }

  walk(e.details);
  return buf.toString().toLowerCase();
}

String? _validationFieldHint(Object? details) {
  if (details == null) return null;
  final parts = <String>[];

  void walk(Object? value, [String? parent]) {
    if (value == null) return;
    if (value is Map) {
      value.forEach((key, nested) {
        final keyText = key.toString().trim();
        if (keyText.isEmpty) {
          walk(nested, parent);
          return;
        }
        if (nested is String && nested.trim().isNotEmpty) {
          final label = parent == null || parent.isEmpty ? keyText : '$parent.$keyText';
          if (label.toLowerCase() == 'id' || label.toLowerCase() == 'err') {
            parts.add(nested.trim());
          } else {
            parts.add('$label: ${nested.trim()}');
          }
          return;
        }
        if (nested is List) {
          final msgs = nested.whereType<String>().map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
          if (msgs.isNotEmpty) {
            final label = parent == null || parent.isEmpty ? keyText : '$parent.$keyText';
            parts.add('$label: ${msgs.join(', ')}');
            return;
          }
        }
        walk(nested, parent == null || parent.isEmpty ? keyText : '$parent.$keyText');
      });
      return;
    }
    if (value is List) {
      for (final nested in value) {
        walk(nested, parent);
      }
    }
  }

  walk(details);
  if (parts.isEmpty) return null;
  final unique = <String>{};
  for (final p in parts) {
    if (p.toLowerCase() == 'invalid value' || p.toLowerCase() == 'please check your inputs') continue;
    unique.add(p);
  }
  if (unique.isEmpty) return null;
  return unique.take(3).join(' · ');
}

String? _mappedKnownApiMessage(ApiException e) {
  if (isContentTooLongApiError(e)) return chatMessageTooLongMessage;
  final msg = _exceptionHaystack(e);

  if (e.statusCode == 401 || msg.contains('not signed in') || msg.contains('unauthorized')) {
    return 'Sign in to continue.';
  }
  if (msg.contains('insufficient') && (msg.contains('balance') || msg.contains('wallet') || msg.contains('coin'))) {
    return 'Not enough coins. Add funds and try again.';
  }
  if ((msg.contains('not enough') || msg.contains('low balance')) && (msg.contains('coin') || msg.contains('wallet') || msg.contains('balance'))) {
    return 'Not enough coins. Add funds and try again.';
  }
  if (msg.contains('sold out')) {
    return 'This clip is sold out.';
  }
  if (msg.contains('already purchased') || msg.contains('already own') || msg.contains('already unlocked')) {
    return 'You already own this content.';
  }
  if (e.statusCode == 403 && (msg.contains('not authorized') || msg.contains('forbidden') || msg.contains('stream this'))) {
    return 'You don’t have access to this content.';
  }
  if (msg.contains('rate limit') || msg.contains('too many requests') || e.statusCode == 429) {
    return 'Too many requests. Wait a moment and try again.';
  }
  if (msg.contains('payload validation') || msg.contains('please check your inputs') || msg.contains('invalid value')) {
    final fieldHint = _validationFieldHint(e.details);
    if (fieldHint != null) return fieldHint;
    return 'Some details look invalid. Check your input and try again.';
  }
  if (msg.contains('file too large') || msg.contains('entity too large') || e.statusCode == 413) {
    return 'That file is too large. Try a smaller one.';
  }
  if (msg.contains('unsupported') && msg.contains('media')) {
    return 'That file type isn’t supported.';
  }
  if (msg.contains('post not found') ||
      msg.contains('video not found') ||
      msg.contains('clip not found') ||
      msg.contains('chat not found') ||
      msg.contains('group not found') ||
      msg.contains('stream not found') ||
      msg.contains('user not found') ||
      (e.statusCode == 404 && _looksLikeRawHttpError(e.message.trim()))) {
    if (msg.contains('user')) return 'That account could not be found.';
    if (msg.contains('chat') || msg.contains('group') || msg.contains('conversation')) {
      return 'This conversation is no longer available.';
    }
    return 'This content is no longer available.';
  }
  if (msg.contains('already following')) {
    return 'You already follow this account.';
  }
  if (msg.contains('not following')) {
    return 'You are not following this account.';
  }
  if (msg.contains('already subscribed')) {
    return 'You are already subscribed.';
  }
  if (msg.contains('not subscribed')) {
    return 'You are not subscribed to this creator.';
  }
  if (msg.contains('subscription') && (msg.contains('plan') && (msg.contains('not') || msg.contains('missing') || msg.contains('set up')))) {
    return 'This creator has not set up a subscription plan yet.';
  }
  if (msg.contains('self') && (msg.contains('follow') || msg.contains('block') || msg.contains('message'))) {
    return 'You can’t do that to your own account.';
  }
  if (msg.contains('blocked') || msg.contains('cannot chat') || msg.contains('cannot message')) {
    return 'This user is blocked. You cannot chat with them.';
  }
  if (msg.contains('member') && msg.contains('already')) {
    return 'This person is already in the group.';
  }
  if (msg.contains('permission') || msg.contains('not allowed') || msg.contains('forbidden')) {
    return 'You don’t have permission to do that.';
  }
  if (msg.contains('network') || msg.contains('timeout') || msg.contains('timed out')) {
    return connectionErrorMessage;
  }
  return null;
}

String friendlyApiMessage(
  Object e, {
  String? fallback,
  String blockedMessage = 'This user is blocked. You cannot chat with them.',
}) {
  if (e is ApiException) {
    return friendlyApiExceptionMessage(e, fallback: fallback, blockedMessage: blockedMessage);
  }
  if (isRetryableNetworkError(e)) {
    return connectionErrorMessage;
  }
  final raw = e.toString().trim();
  if (raw.isNotEmpty && !_looksLikeRawHttpError(raw) && !raw.startsWith('Exception:')) {
    return raw;
  }
  return fallback ?? 'Something went wrong. Please try again.';
}

String friendlyApiExceptionMessage(
  ApiException e, {
  String? fallback,
  String blockedMessage = 'This user is blocked. You cannot chat with them.',
}) {
  if (isRetryableNetworkError(e)) return connectionErrorMessage;
  if (isBlockedUserError(e)) return blockedMessage;
  final mapped = _mappedKnownApiMessage(e);
  if (mapped != null) return mapped;
  final trimmed = e.message.trim();
  if (trimmed.isNotEmpty && !_looksLikeRawHttpError(trimmed)) return trimmed;
  return fallback ?? 'Something went wrong. Please try again.';
}
