class PresenceInfo {
  const PresenceInfo({required this.online, required this.label});

  final bool online;
  final String label;
}

const _stale = Duration(minutes: 5);
const _onlineWords = {'online', 'active_now', 'activenow', 'available'};
const _offlineWords = {'offline', 'away', 'invisible', 'idle', 'unavailable'};

Map<String, dynamic> _unwrap(dynamic raw) {
  if (raw is! Map) return <String, dynamic>{};
  final map = Map<String, dynamic>.from(raw);
  final data = map['data'];
  if (data is Map) return _unwrap(data);
  final presence = map['presence'];
  if (presence is Map) return Map<String, dynamic>.from(presence);
  return map;
}

bool? _flag(dynamic value) {
  if (value == true || value == 1 || value == 'true' || value == '1') return true;
  if (value == false || value == 0 || value == 'false' || value == '0') return false;
  return null;
}

DateTime? _when(dynamic value) {
  if (value == null || value == '') return null;
  if (value is num) {
    final n = value.toDouble();
    final ms = n < 1e12 ? n * 1000 : n;
    return DateTime.fromMillisecondsSinceEpoch(ms.round(), isUtc: true);
  }
  return DateTime.tryParse(value.toString());
}

String _formatLastSeen(DateTime at) {
  final local = at.toLocal();
  final now = DateTime.now();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (now.day == local.day && now.month == local.month && now.year == local.year) {
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return 'today $h:$m';
  }
  if (diff.inDays < 7) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[local.weekday - 1];
  }
  return '${local.day}/${local.month}/${local.year}';
}

PresenceInfo parsePresence(dynamic raw) {
  final d = _unwrap(raw);
  final lastSeen = _when(
    d['lastSeen'] ?? d['lastSeenAt'] ?? d['last_seen'] ?? d['lastActive'] ?? d['lastActiveAt'] ?? d['lastOnlineAt'],
  );
  final onlineFlag = _flag(d['online']) ?? _flag(d['isOnline']) ?? _flag(d['is_online']);
  final word = (d['presence'] ?? d['activityStatus'] ?? d['onlineStatus'] ?? d['state'] ?? '').toString().toLowerCase().trim();
  final statusWord = (d['status'] ?? '').toString().toLowerCase().trim();
  final wordOnline = _onlineWords.contains(word) || statusWord == 'online';
  final wordOffline = _offlineWords.contains(word) || statusWord == 'offline' || statusWord == 'away';

  var online = false;
  if (onlineFlag == false || wordOffline) {
    online = false;
  } else if (onlineFlag == true || wordOnline) {
    online = true;
  }

  if (lastSeen != null) {
    final age = DateTime.now().difference(lastSeen.toLocal());
    if (age > _stale) online = false;
  }

  if (online) return const PresenceInfo(online: true, label: 'Online');
  if (lastSeen != null) return PresenceInfo(online: false, label: 'Last seen ${_formatLastSeen(lastSeen)}');
  return const PresenceInfo(online: false, label: 'Offline');
}
