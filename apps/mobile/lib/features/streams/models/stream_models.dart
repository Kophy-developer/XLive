import '../../../core/network/api_json.dart';

class LiveStream {
  const LiveStream({
    required this.id,
    required this.title,
    this.caption,
    this.status,
    this.viewerCount = 0,
    this.thumbnailUrl,
    this.hostId,
    this.hostName,
    this.hostAvatarUrl,
    this.durationSeconds = 0,
    this.giftPoints = 0,
    this.visibility,
    this.joinPolicy,
    this.pricePerMinute = 0,
    this.captionsEnabled = false,
    this.captionsAvailable = false,
    this.saveEnabled = false,
    this.replaySaved = false,
    this.transcriptSaved = false,
    this.hasReplay = false,
    this.hasTranscript = false,
    this.replayUrl,
    this.recordingStatus,
    this.startedAt,
  });

  final String id;
  final String title;
  final String? caption;
  final String? status;
  final String? visibility;
  final String? joinPolicy;
  final int viewerCount;
  final String? thumbnailUrl;
  final String? hostId;
  final String? hostName;
  final String? hostAvatarUrl;
  final int durationSeconds;
  final int giftPoints;
  final int pricePerMinute;
  final bool captionsEnabled;
  final bool captionsAvailable;
  final bool saveEnabled;
  final bool replaySaved;
  final bool transcriptSaved;
  final bool hasReplay;
  final bool hasTranscript;
  final String? replayUrl;
  final String? recordingStatus;
  final DateTime? startedAt;

  bool get isLive => status?.toLowerCase() == 'live' || status?.toLowerCase() == 'started';

  bool get isPrivate => visibility?.toLowerCase() == 'private';

  bool get isSubscriberOnly => isPrivate && (joinPolicy?.toLowerCase() == 'subscribers');

  bool get isPaid => isPrivate && pricePerMinute > 0;

  bool get supportsCaptions => captionsEnabled || captionsAvailable;

  factory LiveStream.fromJson(Map<String, dynamic> json) {
    final host = ApiJson.map(json['host']) ??
        ApiJson.map(json['creator']) ??
        ApiJson.map(json['user']) ??
        ApiJson.map(json['owner']);
    final replaySaved = ApiJson.boolValue(json['replaySaved']) || ApiJson.boolValue(json['hasReplay']);
    final transcriptSaved = ApiJson.boolValue(json['transcriptSaved']) || ApiJson.boolValue(json['hasTranscript']);
    return LiveStream(
      id: ApiJson.pickString(json, ['id', '_id', 'streamId']) ?? '',
      title: ApiJson.pickString(json, ['title', 'name']) ?? 'Live stream',
      caption: ApiJson.pickString(json, ['caption', 'description']),
      status: ApiJson.pickString(json, ['status', 'state']),
      visibility: ApiJson.pickString(json, ['visibility', 'streamVisibility', 'type']),
      joinPolicy: ApiJson.pickString(json, ['joinPolicy']),
      viewerCount: ApiJson.pickInt(json, ['viewerCount', 'viewers', 'audienceCount', 'watchCount']),
      thumbnailUrl: ApiJson.pickString(json, ['thumbnailUrl', 'coverUrl', 'previewUrl', 'imageUrl']),
      hostId: host == null ? ApiJson.pickString(json, ['hostId', 'userId', 'creatorId']) : ApiJson.pickString(host, ['id', '_id']),
      hostName: host == null
          ? ApiJson.pickString(json, ['hostName', 'creatorName', 'username'])
          : ApiJson.pickString(host, ['displayName', 'username', 'name']),
      hostAvatarUrl: host == null
          ? ApiJson.pickString(json, ['hostAvatarUrl', 'avatarUrl'])
          : ApiJson.pickString(host, ['avatarUrl', 'avatar']),
      durationSeconds: ApiJson.pickInt(json, ['durationSeconds', 'duration', 'elapsedSeconds']),
      giftPoints: ApiJson.pickInt(json, ['giftPoints', 'points', 'earnedPoints', 'totalGifts']),
      pricePerMinute: ApiJson.pickInt(json, ['pricePerMinute', 'privateStreamPricePerMinute', 'price', 'coinsPerMinute']),
      captionsEnabled: ApiJson.boolValue(json['captionsEnabled']),
      captionsAvailable: ApiJson.boolValue(json['captionsAvailable']) || ApiJson.boolValue(json['captionsEnabled']),
      saveEnabled: ApiJson.boolValue(json['saveEnabled']),
      replaySaved: replaySaved,
      transcriptSaved: transcriptSaved,
      hasReplay: ApiJson.boolValue(json['hasReplay'], fallback: replaySaved),
      hasTranscript: ApiJson.boolValue(json['hasTranscript'], fallback: transcriptSaved),
      replayUrl: ApiJson.pickString(json, ['replayUrl', 'mediaUrl', 'videoUrl']),
      recordingStatus: ApiJson.pickString(json, ['recordingStatus']),
      startedAt: DateTime.tryParse(
            ApiJson.pickString(json, ['startedAt', 'startAt', 'liveStartedAt', 'createdAt']) ?? '',
          ) ??
          (ApiJson.pickInt(json, ['startedAtMs', 'startMs']) > 0
              ? DateTime.fromMillisecondsSinceEpoch(ApiJson.pickInt(json, ['startedAtMs', 'startMs']))
              : null),
    );
  }
}

class StreamReplayDetail {
  const StreamReplayDetail({
    required this.streamId,
    this.saveEnabled = false,
    this.replaySaved = false,
    this.replayUrl,
    this.thumbnailUrl,
    this.recordingStatus,
    this.transcriptSaved = false,
  });

  final String streamId;
  final bool saveEnabled;
  final bool replaySaved;
  final String? replayUrl;
  final String? thumbnailUrl;
  final String? recordingStatus;
  final bool transcriptSaved;

  bool get hasReplayMedia => replayUrl != null && replayUrl!.trim().isNotEmpty;

  ReplaySavePhase get phase {
    if (!saveEnabled) return ReplaySavePhase.off;
    final status = (recordingStatus ?? '').trim().toLowerCase();
    if (status == 'discarded' || status == 'deleted' || status == 'cancelled') {
      return ReplaySavePhase.discarded;
    }
    if (status == 'failed' || status == 'error') {
      return ReplaySavePhase.failed;
    }
    if (replaySaved ||
        hasReplayMedia ||
        status == 'ready' ||
        status == 'completed' ||
        status == 'saved' ||
        status == 'available') {
      return ReplaySavePhase.saved;
    }
    return ReplaySavePhase.processing;
  }

  bool get canDiscard =>
      saveEnabled && phase != ReplaySavePhase.discarded && phase != ReplaySavePhase.off;

  bool get canWatch => phase == ReplaySavePhase.saved && (replaySaved || hasReplayMedia);

  factory StreamReplayDetail.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final recording = ApiJson.map(data['recording']);
    return StreamReplayDetail(
      streamId: ApiJson.pickString(data, ['streamId', 'id', '_id']) ?? '',
      saveEnabled: ApiJson.boolValue(data['saveEnabled']),
      replaySaved: ApiJson.boolValue(data['replaySaved']) || ApiJson.boolValue(data['hasReplay']),
      replayUrl: ApiJson.pickString(data, ['replayUrl']) ??
          (recording == null ? null : ApiJson.pickString(recording, ['replayUrl', 'url', 'mediaUrl'])),
      thumbnailUrl: ApiJson.pickString(data, ['thumbnailUrl']) ??
          (recording == null ? null : ApiJson.pickString(recording, ['thumbnailUrl'])),
      recordingStatus: ApiJson.pickString(data, ['recordingStatus', 'status']) ??
          (recording == null ? null : ApiJson.pickString(recording, ['status', 'recordingStatus'])),
      transcriptSaved: ApiJson.boolValue(data['transcriptSaved']),
    );
  }
}

enum ReplaySavePhase { off, processing, saved, failed, discarded }

class StreamTranscriptDoc {
  const StreamTranscriptDoc({
    required this.streamId,
    this.saved = false,
    this.fullText = '',
    this.segments = const [],
  });

  final String streamId;
  final bool saved;
  final String fullText;
  final List<StreamTranscriptSegment> segments;

  factory StreamTranscriptDoc.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final raw = data['segments'] ?? data['items'] ?? data['docs'];
    final segments = <StreamTranscriptSegment>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          segments.add(StreamTranscriptSegment.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }
    return StreamTranscriptDoc(
      streamId: ApiJson.pickString(data, ['streamId', 'id', '_id']) ?? '',
      saved: ApiJson.boolValue(data['saved']) || ApiJson.boolValue(data['transcriptSaved']),
      fullText: ApiJson.pickString(data, ['fullText', 'text', 'transcript']) ?? '',
      segments: segments,
    );
  }
}

class StreamTranscriptSegment {
  const StreamTranscriptSegment({
    this.id,
    this.text = '',
    this.speaker,
    this.startMs = 0,
    this.endMs = 0,
  });

  final String? id;
  final String text;
  final String? speaker;
  final int startMs;
  final int endMs;

  factory StreamTranscriptSegment.fromJson(Map<String, dynamic> json) {
    return StreamTranscriptSegment(
      id: ApiJson.pickString(json, ['id', '_id', 'segmentId']),
      text: ApiJson.pickString(json, ['text', 'content', 'transcript']) ?? '',
      speaker: ApiJson.pickString(json, ['speaker', 'speakerName', 'displayName']),
      startMs: ApiJson.pickInt(json, ['startMs', 'start', 'from']),
      endMs: ApiJson.pickInt(json, ['endMs', 'end', 'to']),
    );
  }
}

class AgoraStreamToken {
  const AgoraStreamToken({
    required this.token,
    this.channelName,
    this.uid,
    this.userAccount,
    this.appId,
  });

  final String token;
  final String? channelName;
  final int? uid;
  final String? userAccount;
  final String? appId;

  factory AgoraStreamToken.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final rawUid = ApiJson.pickString(data, ['uid', 'agoraUid']);
    final parsedUid = rawUid == null ? null : int.tryParse(rawUid);
    return AgoraStreamToken(
      token: ApiJson.pickString(data, ['token', 'agoraToken', 'rtcToken']) ?? '',
      channelName: ApiJson.pickString(data, ['channelName', 'channel', 'channelId']),
      uid: parsedUid,
      userAccount: (parsedUid == null && rawUid != null && rawUid.isNotEmpty) ? rawUid : null,
      appId: ApiJson.pickString(data, ['appId', 'agoraAppId']),
    );
  }
}

class StreamInviteCandidate {
  const StreamInviteCandidate({
    required this.id,
    this.displayName,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? avatarUrl;

  String get name => displayName ?? username ?? 'User';

  factory StreamInviteCandidate.fromJson(Map<String, dynamic> json) {
    return StreamInviteCandidate(
      id: ApiJson.pickString(json, ['id', '_id', 'userId']) ?? '',
      displayName: ApiJson.pickString(json, ['displayName', 'name']),
      username: ApiJson.pickString(json, ['username', 'handle']),
      avatarUrl: ApiJson.pickString(json, ['avatarUrl', 'avatar']),
    );
  }
}

class StreamInvite {
  const StreamInvite({
    required this.id,
    this.streamId,
    this.streamTitle,
    this.hostName,
    this.inviteeId,
    this.inviteeName,
    this.inviteeUsername,
    this.inviteeAvatarUrl,
    this.status,
    this.role,
    this.earningsSplitPercent,
    this.durationMinutes,
    this.scheduledStartAt,
    this.endsAt,
  });

  final String id;
  final String? streamId;
  final String? streamTitle;
  final String? hostName;
  final String? inviteeId;
  final String? inviteeName;
  final String? inviteeUsername;
  final String? inviteeAvatarUrl;
  final String? status;
  final String? role;
  final int? earningsSplitPercent;
  final int? durationMinutes;
  final DateTime? scheduledStartAt;
  final DateTime? endsAt;

  bool get isPending => (status ?? '').toLowerCase() == 'pending';

  bool get isAccepted => (status ?? '').toLowerCase() == 'accepted' || (status ?? '').toLowerCase() == 'joined';

  bool get isCohostRole => (role ?? '').toLowerCase() == 'cohost' || (role ?? '').toLowerCase() == 'co-host';

  String get inviteeLabel => inviteeName ?? inviteeUsername ?? 'Invitee';

  String? get scheduleLabel {
    final parts = <String>[];
    if (durationMinutes != null && durationMinutes! > 0) {
      parts.add('$durationMinutes min');
    }
    if (endsAt != null) {
      final left = endsAt!.difference(DateTime.now());
      if (left.inSeconds > 0) {
        final m = left.inMinutes;
        final s = left.inSeconds % 60;
        parts.add('${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')} left');
      }
    } else if (scheduledStartAt != null) {
      final local = scheduledStartAt!.toLocal();
      final h = local.hour > 12 ? local.hour - 12 : (local.hour == 0 ? 12 : local.hour);
      final m = local.minute.toString().padLeft(2, '0');
      final ap = local.hour >= 12 ? 'PM' : 'AM';
      parts.add('Starts $h:$m $ap');
    }
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  factory StreamInvite.fromJson(Map<String, dynamic> json) {
    final stream = ApiJson.map(json['stream']);
    final host = ApiJson.map(json['host']) ?? ApiJson.map(json['creator']);
    final invitee = ApiJson.map(json['user']) ?? ApiJson.map(json['invitee']) ?? ApiJson.map(json['toUser']);
    final schedule = ApiJson.map(json['schedule']) ?? (stream == null ? null : ApiJson.map(stream['schedule']));
    final duration = ApiJson.pickInt(json, ['durationMinutes']) > 0
        ? ApiJson.pickInt(json, ['durationMinutes'])
        : (schedule == null
            ? (stream == null ? 0 : ApiJson.pickInt(stream, ['durationMinutes']))
            : ApiJson.pickInt(schedule, ['durationMinutes']));
    final scheduledRaw = ApiJson.pickString(json, ['scheduledStartAt', 'startsAt', 'startAt']) ??
        (schedule == null ? null : ApiJson.pickString(schedule, ['scheduledStartAt', 'startsAt', 'startAt'])) ??
        (stream == null ? null : ApiJson.pickString(stream, ['scheduledStartAt', 'startsAt', 'startAt']));
    final endsRaw = ApiJson.pickString(json, ['endsAt', 'endAt']) ??
        (schedule == null ? null : ApiJson.pickString(schedule, ['endsAt', 'endAt'])) ??
        (stream == null ? null : ApiJson.pickString(stream, ['endsAt', 'endAt']));
    final split = ApiJson.pickInt(json, ['earningsSplitPercent', 'splitPercent', 'earningsPercent']);
    final remaining = schedule == null ? 0 : ApiJson.pickInt(schedule, ['remainingSeconds']);
    DateTime? endsAt = DateTime.tryParse(endsRaw ?? '');
    if (endsAt == null && remaining > 0) {
      endsAt = DateTime.now().add(Duration(seconds: remaining));
    }
    return StreamInvite(
      id: ApiJson.pickString(json, ['id', '_id', 'inviteId']) ?? '',
      streamId: stream == null
          ? ApiJson.pickString(json, ['streamId'])
          : (ApiJson.pickString(stream, ['id', '_id']) ?? ApiJson.pickString(json, ['streamId'])),
      streamTitle: ApiJson.pickString(json, ['streamTitle', 'title']) ??
          (stream == null ? null : ApiJson.pickString(stream, ['title', 'name'])),
      hostName: ApiJson.pickString(json, ['hostName', 'fromName', 'senderName']) ??
          (host == null ? null : ApiJson.pickString(host, ['displayName', 'username', 'name'])),
      inviteeId: invitee == null
          ? ApiJson.pickString(json, ['inviteeId', 'userId', 'toUserId'])
          : ApiJson.pickString(invitee, ['id', '_id', 'userId']),
      inviteeName: invitee == null ? null : ApiJson.pickString(invitee, ['displayName', 'name']),
      inviteeUsername: invitee == null ? null : ApiJson.pickString(invitee, ['username']),
      inviteeAvatarUrl: invitee == null ? null : ApiJson.pickString(invitee, ['avatarUrl', 'avatar']),
      status: ApiJson.pickString(json, ['status', 'state']),
      role: ApiJson.pickString(json, ['role', 'inviteRole']),
      earningsSplitPercent: split > 0 ? split : null,
      durationMinutes: duration > 0 ? duration : null,
      scheduledStartAt: DateTime.tryParse(scheduledRaw ?? ''),
      endsAt: endsAt,
    );
  }
}

class StreamCohostMember {
  const StreamCohostMember({
    required this.id,
    this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.earningsSplitPercent,
    this.status,
  });

  final String id;
  final String? userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final int? earningsSplitPercent;
  final String? status;

  String get label => displayName ?? username ?? 'Co-host';

  factory StreamCohostMember.fromJson(Map<String, dynamic> json) {
    final user = ApiJson.map(json['user']) ?? ApiJson.map(json['invitee']) ?? ApiJson.map(json['cohost']);
    final split = ApiJson.pickInt(json, ['earningsSplitPercent', 'splitPercent', 'earningsPercent']);
    return StreamCohostMember(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      userId: user == null
          ? ApiJson.pickString(json, ['userId', 'inviteeId', 'cohostId'])
          : ApiJson.pickString(user, ['id', '_id', 'userId']),
      displayName: user == null
          ? ApiJson.pickString(json, ['displayName', 'name'])
          : ApiJson.pickString(user, ['displayName', 'name']),
      username: user == null ? ApiJson.pickString(json, ['username']) : ApiJson.pickString(user, ['username']),
      avatarUrl: user == null
          ? ApiJson.pickString(json, ['avatarUrl', 'avatar'])
          : ApiJson.pickString(user, ['avatarUrl', 'avatar']),
      earningsSplitPercent: split > 0 ? split : null,
      status: ApiJson.pickString(json, ['status', 'state']),
    );
  }
}

class StreamCohostsInfo {
  const StreamCohostsInfo({
    this.hostId,
    this.hostEarningsPercent = 100,
    this.maxCohosts = 3,
    this.docs = const [],
  });

  final String? hostId;
  final int hostEarningsPercent;
  final int maxCohosts;
  final List<StreamCohostMember> docs;

  factory StreamCohostsInfo.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final raw = data['docs'] ?? data['items'] ?? data['cohosts'];
    final docs = <StreamCohostMember>[];
    if (raw is List) {
      for (final item in raw) {
        if (item is Map) {
          final member = StreamCohostMember.fromJson(Map<String, dynamic>.from(item));
          if (member.id.isNotEmpty || (member.userId?.isNotEmpty ?? false)) {
            docs.add(member);
          }
        }
      }
    }
    final hostPct = ApiJson.pickInt(data, ['hostEarningsPercent', 'hostPercent'], fallback: 100);
    final max = ApiJson.pickInt(data, ['maxCohosts'], fallback: 3);
    return StreamCohostsInfo(
      hostId: ApiJson.pickString(data, ['hostId']),
      hostEarningsPercent: hostPct > 0 ? hostPct : 100,
      maxCohosts: max > 0 ? max : 3,
      docs: docs,
    );
  }
}

class StreamGiftRecord {
  const StreamGiftRecord({
    required this.id,
    this.giftName,
    this.iconUrl,
    this.quantity = 1,
    this.senderName,
    this.points = 0,
  });

  final String id;
  final String? giftName;
  final String? iconUrl;
  final int quantity;
  final String? senderName;
  final int points;

  factory StreamGiftRecord.fromJson(Map<String, dynamic> json) {
    final gift = ApiJson.map(json['gift']);
    final sender = ApiJson.map(json['sender']) ?? ApiJson.map(json['user']);
    return StreamGiftRecord(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      giftName: gift == null
          ? ApiJson.pickString(json, ['giftName', 'name'])
          : ApiJson.pickString(gift, ['name', 'title']),
      iconUrl: gift == null ? ApiJson.pickString(json, ['iconUrl']) : ApiJson.pickString(gift, ['iconUrl', 'icon']),
      quantity: ApiJson.pickInt(json, ['quantity', 'count'], fallback: 1),
      senderName: sender == null
          ? ApiJson.pickString(json, ['senderName', 'username'])
          : ApiJson.pickString(sender, ['displayName', 'username', 'name']),
      points: ApiJson.pickInt(json, ['points', 'cashValue', 'amount']),
    );
  }
}
