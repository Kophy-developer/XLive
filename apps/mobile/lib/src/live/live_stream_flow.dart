import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/api_config.dart';
import '../../core/i18n/translation_service.dart';
import '../../core/live/agora_stream_controller.dart';
import '../../core/live/agora_stream_view.dart';
import '../../core/live/host_speech_captions.dart';
import '../../core/live/live_hear_translation.dart';
import '../../core/live/live_languages.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../core/network/api_json.dart';
import '../../core/session/auth_session.dart';
import '../../core/socket/xlive_socket_client.dart';
import '../../core/widgets/connection_status_pill.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/creator/creator_repository.dart';
import '../../features/feed/feed_repository.dart';
import '../../features/gifts/gifts_repository.dart';
import '../../features/gifts/models/gift_models.dart';
import '../../features/social/social_repository.dart';
import '../../features/streams/models/stream_models.dart';
import '../../features/streams/models/stream_transcript_models.dart';
import '../../features/streams/streams_repository.dart';
import '../../features/users/users_repository.dart';
import '../../core/subscriptions/subscription_store.dart';
import '../chats/chat_attach_utils.dart';
import 'live_theme.dart';
import 'widgets/live_captions_overlay.dart';
import 'widgets/live_chat_overlay.dart';
import 'widgets/live_gift_burst.dart';
import 'widgets/live_host_sheets.dart';
import 'widgets/live_viewer_overlays.dart';
import 'widgets/stream_invite_dialog.dart';

class LiveDuringArgs {
  const LiveDuringArgs({
    required this.streamId,
    this.isHost = false,
    this.isCohost = false,
  });

  final String streamId;
  final bool isHost;
  final bool isCohost;
}

class LiveSummaryArgs {
  const LiveSummaryArgs({
    required this.streamId,
    this.viewerCount = 0,
    this.giftPoints = 0,
    this.initialReplay,
    this.replayUploadFailed = false,
  });

  final String streamId;
  final int viewerCount;
  final int giftPoints;
  final StreamReplayDetail? initialReplay;
  final bool replayUploadFailed;
}

class LiveHubScreen extends StatefulWidget {
  const LiveHubScreen({super.key});

  @override
  State<LiveHubScreen> createState() => _LiveHubScreenState();
}

class _LiveHubScreenState extends State<LiveHubScreen> {
  final _streamsRepo = StreamsRepository();
  List<LiveStream> _live = const [];
  List<StreamInvite> _pendingInvites = const [];
  List<LiveStream> _replays = const [];
  bool _loading = true;
  String? _error;
  StreamSubscription<Map<String, dynamic>>? _inviteIncomingSub;
  StreamSubscription<Map<String, dynamic>>? _inviteAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _inviteDeclinedSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
    final socket = XLiveSocketClient.instance;
    _inviteIncomingSub = socket.onStreamInviteIncoming.listen((_) => _load());
    _inviteAcceptedSub = socket.onStreamInviteAccepted.listen((_) => _load());
    _inviteDeclinedSub = socket.onStreamInviteDeclined.listen((_) => _load());
    _pollTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (mounted && AuthSession.instance.isSignedIn) _load(silent: true);
    });
  }

  @override
  void dispose() {
    _inviteIncomingSub?.cancel();
    _inviteAcceptedSub?.cancel();
    _inviteDeclinedSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final liveFuture = _streamsRepo.listLive();
      final invitesFuture = AuthSession.instance.isSignedIn
          ? _streamsRepo.myInvites(limit: 30)
          : Future<List<StreamInvite>>.value(const []);
      final replaysFuture = _streamsRepo.listReplays(limit: 8);
      final results = await Future.wait([liveFuture, invitesFuture, replaysFuture]);
      if (!mounted) return;
      final live = results[0] as List<LiveStream>;
      var invites = (results[1] as List<StreamInvite>).where((i) => i.isPending).toList();
      invites = await Future.wait(invites.map((invite) async {
        if (invite.isStreamEnded || invite.isStreamLiveOrScheduled) return invite;
        final streamId = invite.streamId?.trim();
        if (streamId == null || streamId.isEmpty) {
          return invite.copyWith(streamStatus: 'ended');
        }
        if (live.any((s) => s.id == streamId)) {
          return invite.copyWith(streamStatus: 'live');
        }
        try {
          final stream = await _streamsRepo.getStream(streamId);
          final status = (stream.status ?? '').trim();
          return invite.copyWith(
            streamStatus: status.isNotEmpty ? status : (stream.isLive ? 'live' : 'ended'),
          );
        } catch (_) {
          return invite.copyWith(streamStatus: 'ended');
        }
      }));
      invites = invites.where((i) => !i.isStreamEnded).toList();
      if (!mounted) return;
      setState(() {
        _live = live;
        _pendingInvites = invites;
        _replays = results[2] as List<LiveStream>;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      if (silent) return;
      setState(() {
        _live = const [];
        _pendingInvites = const [];
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  StreamInvite? _inviteFor(LiveStream stream) {
    for (final invite in _pendingInvites) {
      if (invite.streamId == stream.id) return invite;
    }
    return null;
  }

  void _watchStream(LiveStream stream) {
    final invite = _inviteFor(stream);
    if (invite != null) {
      _openInvite(invite);
      return;
    }
    final isOwner = stream.hostId != null &&
        stream.hostId == AuthSession.instance.user?.id;
    Navigator.pushNamed(
      context,
      '/live/during',
      arguments: LiveDuringArgs(
        streamId: stream.id,
        isHost: isOwner,
      ),
    );
  }

  Future<void> _endBroadcastFromHub(LiveStream stream) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Live Stream?'),
        content: Text('Are you sure you want to end "${stream.title}"? This will terminate the broadcast on the server.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _streamsRepo.endStream(stream.id);
      try {
        await XLiveSocketClient.instance.endStream(stream.id);
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stream ended successfully')),
        );
        await _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyApiMessage(e))),
        );
        await _load();
      }
    }
  }

  Future<void> _openInvite(StreamInvite invite) async {
    final accepted = await showStreamInviteAcceptDialog(context, invite: invite);
    if (accepted && mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    final orphanInvites = _pendingInvites.where((i) {
      final sid = i.streamId;
      if (sid == null || sid.isEmpty) return true;
      return !_live.any((s) => s.id == sid);
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Live Streaming'),
        actions: [
          IconButton(
            icon: const Icon(Icons.video_library_outlined),
            tooltip: 'Replays',
            onPressed: () => Navigator.pushNamed(context, '/live/replays'),
          ),
          IconButton(
            icon: const Icon(Icons.mail_outline_rounded),
            onPressed: () => Navigator.pushNamed(context, '/social/stream-invites'),
          ),
          if (AuthSession.instance.isSignedIn)
            TextButton(onPressed: () => Navigator.pushNamed(context, '/live/setup'), child: const Text('Go live')),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Live Now', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Watch creators streaming in real time.', style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 18),
            Row(
              children: [
                Text('BROADCASTS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, color: Colors.grey.shade700)),
                const Spacer(),
                TextButton(onPressed: _load, child: const Text('Refresh')),
              ],
            ),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_live.isEmpty && orphanInvites.isEmpty)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('No live streams right now.')))
            else ...[
              for (final invite in orphanInvites)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _LiveBroadcastCard(
                    title: invite.streamTitle ?? 'Live stream',
                    subtitle: 'You were invited — tap to answer',
                    viewerCount: 0,
                    ringing: true,
                    isCohostInvite: invite.isCohostRole,
                    meta: invite.scheduleLabel,
                    onTap: () => _openInvite(invite),
                  ),
                ),
              for (final stream in _live)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Builder(
                    builder: (_) {
                      final invite = _inviteFor(stream);
                      final isOwner = stream.hostId != null &&
                          stream.hostId == AuthSession.instance.user?.id;
                      return _LiveBroadcastCard(
                        title: stream.title,
                        subtitle: invite == null
                            ? (stream.hostName ?? 'Creator')
                            : 'You were invited — tap to answer',
                        viewerCount: stream.viewerCount,
                        thumbnailUrl: stream.thumbnailUrl,
                        ringing: invite != null,
                        isCohostInvite: invite?.isCohostRole == true,
                        isOwner: isOwner,
                        onEndStream: isOwner ? () => _endBroadcastFromHub(stream) : null,
                        meta: invite?.scheduleLabel,
                        onTap: () => _watchStream(stream),
                      );
                    },
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Text('SAVED REPLAYS', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 0.5, color: Colors.grey.shade700)),
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/live/replays'),
                  child: const Text('See all'),
                ),
              ],
            ),
            if (_replays.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No saved replays yet', style: TextStyle(color: Colors.grey.shade600)),
              )
            else
              SizedBox(
                height: 110,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _replays.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final replay = _replays[i];
                    return InkWell(
                      onTap: () => Navigator.pushNamed(context, '/live/replays'),
                      borderRadius: BorderRadius.circular(14),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: SizedBox(
                          width: 150,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (replay.thumbnailUrl != null && replay.thumbnailUrl!.isNotEmpty)
                                Image.network(replay.thumbnailUrl!, fit: BoxFit.cover)
                              else
                                Container(color: Colors.grey.shade200),
                              Positioned(
                                left: 8,
                                top: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(color: const Color(0xFF2F6BFF), borderRadius: BorderRadius.circular(8)),
                                  child: const Text('REPLAY', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            const Text('Creator tools', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0x1A0A0A0A))),
              title: const Text('Live Setup'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/live/setup'),
            ),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0x1A0A0A0A))),
              title: const Text('Stream replays'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/live/replays'),
            ),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0x1A0A0A0A))),
              title: const Text('My replays'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.pushNamed(context, '/live/replays', arguments: true),
            ),
          ],
        ),
      ),
      floatingActionButton: AuthSession.instance.isSignedIn
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.pushNamed(context, '/live/setup'),
              backgroundColor: const Color(0xFFE8487E),
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: const Text('Go Live', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            )
          : null,
    );
  }
}

class _LiveBroadcastCard extends StatelessWidget {
  const _LiveBroadcastCard({
    required this.title,
    required this.subtitle,
    required this.viewerCount,
    required this.onTap,
    this.thumbnailUrl,
    this.ringing = false,
    this.isCohostInvite = false,
    this.isOwner = false,
    this.onEndStream,
    this.meta,
  });

  final String title;
  final String subtitle;
  final int viewerCount;
  final VoidCallback onTap;
  final String? thumbnailUrl;
  final bool ringing;
  final bool isCohostInvite;
  final bool isOwner;
  final VoidCallback? onEndStream;
  final String? meta;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ringing ? const Color(0xFFFFC107) : const Color(0x1A0A0A0A), width: ringing ? 1.5 : 1),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                      Image.network(thumbnailUrl!, fit: BoxFit.cover)
                    else
                      Container(color: const Color(0xFF1C1C1E)),
                    const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 48)),
                    Positioned(
                      left: 10,
                      top: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(8)),
                        child: const Text('LIVE', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ),
                    if (ringing)
                      Positioned(
                        left: 10,
                        top: 42,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: const Color(0xFFFFC107), borderRadius: BorderRadius.circular(999)),
                          child: Text(
                            isCohostInvite ? 'Co-host · Invited · Ringing' : 'Invited · Ringing',
                            style: const TextStyle(color: Color(0xFF1A1200), fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(999)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text('$viewerCount', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13.5)),
                          if (meta != null && meta!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(meta!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12.5, fontWeight: FontWeight.w600)),
                          ],
                        ],
                      ),
                    ),
                    if (isOwner && onEndStream != null) ...[
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: onEndStream,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFFEF4444),
                          backgroundColor: const Color(0x1AEF4444),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.power_settings_new_rounded, size: 14),
                        label: const Text('End', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveSetupScreen extends StatefulWidget {
  const LiveSetupScreen({super.key});

  @override
  State<LiveSetupScreen> createState() => _LiveSetupScreenState();
}

class _LiveSetupScreenState extends State<LiveSetupScreen> with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF8A2DDC);
  static const _sky = Color(0xFF35D3FB);
  static const _maxCohosts = 3;
  static const _maxCohostSplitTotal = 90;

  final _streamsRepo = StreamsRepository();
  final _creatorRepo = CreatorRepository();
  final _socialRepo = SocialRepository();
  final _usersRepo = UsersRepository();
  final _titleController = TextEditingController(text: 'My live stream');
  final _captionController = TextEditingController();
  final _inviteSearchCtrl = TextEditingController();
  late final TabController _inviteTabs;
  bool _private = false;
  bool _captionsEnabled = true;
  bool _saveEnabled = true;
  bool _busy = false;
  bool _inviteAsCohost = false;
  int _cohostSplitPercent = 20;
  String _chatPolicy = 'everyone';
  String _joinPolicy = 'everyone';
  List<_SetupInvitePerson> _people = const [];
  final Map<String, _SetupInvitePerson> _selected = {};
  bool _loadingPeople = false;
  String? _peopleError;
  Timer? _inviteSearchDebounce;

  @override
  void initState() {
    super.initState();
    _inviteTabs = TabController(length: 3, vsync: this);
    _inviteTabs.addListener(() {
      if (_inviteTabs.indexIsChanging) return;
      _loadPeople();
    });
    _loadPeople();
  }

  @override
  void dispose() {
    _inviteSearchDebounce?.cancel();
    _titleController.dispose();
    _captionController.dispose();
    _inviteSearchCtrl.dispose();
    _inviteTabs.dispose();
    super.dispose();
  }

  int get _selectedCohostCount => _inviteAsCohost ? _selected.length : 0;

  int get _hostKeepPercent {
    if (!_inviteAsCohost || _selected.isEmpty) return 100;
    final used = (_selected.length * _cohostSplitPercent).clamp(0, _maxCohostSplitTotal);
    return (100 - used).clamp(10, 100);
  }

  Future<void> _loadPeople() async {
    final me = AuthSession.instance.user?.id;
    if (me == null || me.isEmpty) return;
    setState(() {
      _loadingPeople = true;
      _peopleError = null;
    });
    try {
      List<_SetupInvitePerson> items;
      if (_inviteTabs.index == 2) {
        final q = _inviteSearchCtrl.text.trim();
        if (q.isEmpty) {
          items = const [];
        } else {
          final users = await _usersRepo.searchUsers(q, limit: 30);
          items = users
              .where((u) => u.id != me)
              .map((u) => _SetupInvitePerson(id: u.id, name: u.effectiveDisplayName, username: u.username, avatarUrl: u.avatarUrl))
              .toList();
        }
      } else if (_inviteTabs.index == 1) {
        final users = await _socialRepo.getFollowing(me, limit: 40);
        items = users
            .map((u) => _SetupInvitePerson(id: u.id, name: u.effectiveDisplayName, username: u.username, avatarUrl: u.avatarUrl))
            .toList();
      } else {
        final users = await _socialRepo.getFollowers(me, limit: 40);
        items = users
            .map((u) => _SetupInvitePerson(id: u.id, name: u.effectiveDisplayName, username: u.username, avatarUrl: u.avatarUrl))
            .toList();
      }
      if (!mounted) return;
      setState(() {
        _people = items;
        _loadingPeople = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPeople = false;
        _peopleError = friendlyApiMessage(e);
      });
    }
  }

  void _onInviteSearchChanged(String _) {
    if (_inviteTabs.index != 2) {
      setState(() {});
      return;
    }
    _inviteSearchDebounce?.cancel();
    _inviteSearchDebounce = Timer(const Duration(milliseconds: 320), _loadPeople);
  }

  void _toggleSelected(_SetupInvitePerson person) {
    setState(() {
      if (_selected.containsKey(person.id)) {
        _selected.remove(person.id);
        return;
      }
      if (_inviteAsCohost && _selected.length >= _maxCohosts) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 3 co-hosts')));
        return;
      }
      if (_inviteAsCohost && ((_selected.length + 1) * _cohostSplitPercent) > _maxCohostSplitTotal) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Co-host splits can total at most 90%')));
        return;
      }
      _selected[person.id] = person;
    });
  }

  Future<void> _goLive() async {
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to go live.')));
      return;
    }
    final title = _titleController.text.trim().isEmpty ? 'My live stream' : _titleController.text.trim();
    if (_inviteAsCohost && _selected.isNotEmpty) {
      if (_selected.length > _maxCohosts) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Max 3 co-hosts')));
        return;
      }
      if (_selected.length * _cohostSplitPercent > _maxCohostSplitTotal) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Co-host splits can total at most 90%')));
        return;
      }
    }
    setState(() => _busy = true);
    try {
      final caption = _captionController.text.trim();
      final LiveStream created;
      if (_private) {
        final settings = await _creatorRepo.getCreatorSettings();
        var pricePerMinute = settings.privateStreamPricePerMinute;
        if (pricePerMinute <= 0) pricePerMinute = 500;
        created = await _streamsRepo.createPrivateSubscriberStream(
          title: title,
          caption: caption,
          chatPolicy: 'everyone',
          pricePerMinute: pricePerMinute,
          captionsEnabled: _captionsEnabled,
          saveEnabled: _saveEnabled,
        );
      } else {
        created = await _streamsRepo.createStream(
          title: title,
          caption: caption,
          visibility: 'public',
          chatPolicy: _chatPolicy,
          joinPolicy: _joinPolicy,
          captionsEnabled: _captionsEnabled,
          saveEnabled: _saveEnabled,
        );
      }
      for (final person in _selected.values) {
        final asCohost = _private && _inviteAsCohost;
        await _streamsRepo.sendInvite(
          created.id,
          person.id,
          role: asCohost ? 'cohost' : null,
          earningsSplitPercent: asCohost ? _cohostSplitPercent : null,
        );
      }
      await _streamsRepo.startStream(created.id);
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/live/during',
        arguments: LiveDuringArgs(streamId: created.id, isHost: true),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  List<_SetupInvitePerson> get _visiblePeople {
    if (_inviteTabs.index == 2) return _people;
    final q = _inviteSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _people;
    return _people.where((p) => p.name.toLowerCase().contains(q) || (p.username ?? '').toLowerCase().contains(q)).toList();
  }

  Widget _policyDropdown({
    required String label,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: LiveTheme.pillBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: const Color(0xFF1E1E1E),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              items: [
                const DropdownMenuItem(value: 'everyone', child: Text('Everyone')),
                const DropdownMenuItem(value: 'followers', child: Text('Followers')),
                if (label != 'Who can chat')
                  const DropdownMenuItem(value: 'subscribers', child: Text('Subscribers')),
              ],
              onChanged: _busy ? null : (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A1A2E), Color(0xFF0A0A0A)],
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: LiveTheme.pillFill, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SafeArea(
                  top: false,
                  child: Container(
                    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
                    decoration: const BoxDecoration(
                      color: Color(0xFF141414),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(100)),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Go live',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Title, invites, and co-host split',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                            children: [
                              TextField(
                                controller: _titleController,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  hintText: 'Stream title',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: LiveTheme.pillBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: LiveTheme.pillBorder)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _captionController,
                                style: const TextStyle(color: Colors.white, fontSize: 15),
                                maxLines: 2,
                                minLines: 1,
                                decoration: InputDecoration(
                                  hintText: 'Add a caption…',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: LiveTheme.pillBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: LiveTheme.pillBorder)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _LiveVisibilityOption(
                                        label: 'Public',
                                        icon: Icons.public_rounded,
                                        selected: !_private,
                                        onTap: _busy
                                            ? null
                                            : () => setState(() {
                                                  _private = false;
                                                }),
                                      ),
                                    ),
                                    Expanded(
                                      child: _LiveVisibilityOption(
                                        label: 'Private',
                                        icon: Icons.lock_rounded,
                                        selected: _private,
                                        onTap: _busy
                                            ? null
                                            : () => setState(() {
                                                  _private = true;
                                                }),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!_private) ...[
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _policyDropdown(
                                        label: 'Who can chat',
                                        value: _chatPolicy,
                                        onChanged: (v) => setState(() => _chatPolicy = v),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _policyDropdown(
                                        label: 'Who can join',
                                        value: _joinPolicy,
                                        onChanged: (v) => setState(() => _joinPolicy = v),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                const SizedBox(height: 14),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E1E1E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: LiveTheme.pillBorder),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.workspace_premium_rounded, color: LiveTheme.purple, size: 24),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Subscribers only',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Private live streams are exclusively accessible to your active channel subscribers.',
                                              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12.5, height: 1.3),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: LiveTheme.pillBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.translate_rounded, color: Colors.white70, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'AI Translator',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Live captions viewers can toggle and translate',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _captionsEnabled,
                                      activeTrackColor: _purple,
                                      onChanged: _busy ? null : (v) => setState(() => _captionsEnabled = v),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: LiveTheme.pillBorder),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.video_library_outlined, color: Colors.white70, size: 22),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Save replay',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Automatically keep this live as a replay after it ends',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12.5, height: 1.3),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Switch.adaptive(
                                      value: _saveEnabled,
                                      activeTrackColor: _purple,
                                      onChanged: _busy ? null : (v) => setState(() => _saveEnabled = v),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'Invite people',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1E1E1E),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: LiveTheme.pillBorder),
                                ),
                                child: Column(
                                  children: [
                                    if (_private) ...[
                                    Row(
                                      children: [
                                        const Expanded(
                                          child: Text(
                                            'Invite selected as co-hosts',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                          ),
                                        ),
                                        Switch.adaptive(
                                          value: _inviteAsCohost,
                                          activeTrackColor: _purple,
                                          onChanged: _busy
                                              ? null
                                              : (v) => setState(() {
                                                    _inviteAsCohost = v;
                                                    if (v && _selected.length > _maxCohosts) {
                                                      final keep = _selected.entries.take(_maxCohosts).toList();
                                                      _selected
                                                        ..clear()
                                                        ..addEntries(keep);
                                                    }
                                                  }),
                                        ),
                                      ],
                                    ),
                                    if (_inviteAsCohost) ...[
                                      Row(
                                        children: [
                                          Text(
                                            'Each co-host $_cohostSplitPercent%',
                                            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                          ),
                                          const Spacer(),
                                          Text(
                                            'Host ~$_hostKeepPercent%',
                                            style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                                          ),
                                        ],
                                      ),
                                      Slider(
                                        value: _cohostSplitPercent.toDouble(),
                                        min: 5,
                                        max: 90,
                                        divisions: 17,
                                        activeColor: LiveTheme.purple,
                                        onChanged: _busy
                                            ? null
                                            : (v) => setState(() => _cohostSplitPercent = v.round()),
                                      ),
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Max $_maxCohosts co-hosts · max $_maxCohostSplitTotal% total · selected $_selectedCohostCount',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
                                        ),
                                      ),
                                    ] else if (_selected.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${_selected.length} selected as viewers',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                                        ),
                                      ),
                                    ],
                                    if (!_private && _selected.isNotEmpty)
                                      Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          '${_selected.length} selected as viewers',
                                          style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              TabBar(
                                controller: _inviteTabs,
                                isScrollable: true,
                                labelColor: Colors.white,
                                unselectedLabelColor: Colors.white54,
                                indicatorColor: LiveTheme.purple,
                                tabs: const [
                                  Tab(text: 'Followers'),
                                  Tab(text: 'Following'),
                                  Tab(text: 'Search'),
                                ],
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _inviteSearchCtrl,
                                onChanged: _onInviteSearchChanged,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  hintText: _inviteTabs.index == 2 ? 'Search people' : 'Filter list',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
                                  prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
                                  filled: true,
                                  fillColor: const Color(0xFF1E1E1E),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 220,
                                child: _loadingPeople
                                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : _peopleError != null
                                        ? Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(_peopleError!, style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
                                                TextButton(onPressed: _loadPeople, child: const Text('Retry')),
                                              ],
                                            ),
                                          )
                                        : _visiblePeople.isEmpty
                                            ? Center(
                                                child: Text(
                                                  _inviteTabs.index == 2 ? 'Search for people to invite' : 'No people to invite',
                                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                                                ),
                                              )
                                            : ListView.separated(
                                                itemCount: _visiblePeople.length,
                                                separatorBuilder: (_, _) => Divider(height: 1, color: Colors.white12),
                                                itemBuilder: (_, i) {
                                                  final person = _visiblePeople[i];
                                                  final selected = _selected.containsKey(person.id);
                                                  return ListTile(
                                                    contentPadding: EdgeInsets.zero,
                                                    leading: UserAvatar(radius: 20, imageUrl: person.avatarUrl),
                                                    title: Text(person.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                                    subtitle: person.username == null
                                                        ? null
                                                        : Text('@${person.username}', style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                                                    trailing: Checkbox(
                                                      value: selected,
                                                      activeColor: LiveTheme.purple,
                                                      onChanged: _busy ? null : (_) => _toggleSelected(person),
                                                    ),
                                                    onTap: _busy ? null : () => _toggleSelected(person),
                                                  );
                                                },
                                              ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          child: SizedBox(
                            height: 52,
                            child: DecoratedBox(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(colors: [_purple, _sky]),
                                borderRadius: BorderRadius.all(Radius.circular(14)),
                              ),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                onPressed: _busy ? null : _goLive,
                                child: _busy
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : Text(
                                        _selected.isEmpty
                                            ? 'Go Live'
                                            : (_private && _inviteAsCohost)
                                                ? 'Go Live · Invite co-host'
                                                : _private
                                                    ? 'Go Live · Invite guest'
                                                    : 'Go Live · Invite',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupInvitePerson {
  const _SetupInvitePerson({
    required this.id,
    required this.name,
    this.username,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? username;
  final String? avatarUrl;
}

class _LiveVisibilityOption extends StatelessWidget {
  const _LiveVisibilityOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  static const _purple = Color(0xFF8A2DDC);
  static const _sky = Color(0xFF35D3FB);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: selected ? const LinearGradient(colors: [_purple, _sky]) : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: selected ? Colors.white : Colors.white70),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white70,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiveDuringScreen extends StatefulWidget {
  const LiveDuringScreen({super.key, this.args});

  final LiveDuringArgs? args;

  @override
  State<LiveDuringScreen> createState() => _LiveDuringScreenState();
}

class _LiveDuringScreenState extends State<LiveDuringScreen> with WidgetsBindingObserver {
  final _streamsRepo = StreamsRepository();
  final _giftsRepo = GiftsRepository();
  final _usersRepo = UsersRepository();
  final _chatInput = TextEditingController();
  GlobalKey<AgoraStreamViewState> _agoraKey = GlobalKey<AgoraStreamViewState>();
  final _agoraController = AgoraStreamController();
  bool _rejoiningCohost = false;
  LiveStream? _stream;
  AgoraStreamToken? _agoraToken;
  int _viewerCount = 0;
  bool _loading = true;
  bool _ending = false;
  bool _streamEnded = false;
  bool _talkBackActive = false;
  DateTime? _liveStartedAt;
  Timer? _liveTimer;
  String _elapsedLabel = '00:00';
  String? _joinError;
  String? _replyToSender;
  final List<LiveFloatingComment> _floatingComments = [];
  final List<LiveFloatingComment> _chatLog = [];
  bool _chatPanelOpen = false;
  final List<LiveGiftBurst> _giftBursts = [];
  final List<LiveStreamViewerRow> _viewers = [];
  final Set<String> _mutedViewerIds = {};
  final Set<String> _talkBackViewerIds = {};
  List<StreamCohostMember> _cohosts = const [];
  List<GiftCatalogItem> _giftCatalog = const [];
  int _commentSeq = 0;
  int _giftSeq = 0;
  int _earnedGiftCoins = 0;
  StreamSubscription<Map<String, dynamic>>? _giftSub;
  StreamSubscription<Map<String, dynamic>>? _viewerSub;
  StreamSubscription<Map<String, dynamic>>? _viewersListSub;
  StreamSubscription<Map<String, dynamic>>? _endedSub;
  StreamSubscription<Map<String, dynamic>>? _removedSub;
  StreamSubscription<Map<String, dynamic>>? _chatSub;
  StreamSubscription<Map<String, dynamic>>? _billingSub;
  StreamSubscription<Map<String, dynamic>>? _mutedSub;
  StreamSubscription<Map<String, dynamic>>? _unmutedSub;
  StreamSubscription<Map<String, dynamic>>? _talkBackGrantedSub;
  StreamSubscription<Map<String, dynamic>>? _talkBackRevokedSub;
  StreamSubscription<Map<String, dynamic>>? _transcriptSub;
  StreamSubscription<Map<String, dynamic>>? _transcriptHistorySub;
  StreamSubscription<Map<String, dynamic>>? _inviteAcceptedSub;
  StreamSubscription<Map<String, dynamic>>? _inLiveInviteSub;
  bool _ccPreferred = true;
  bool _ccVisible = false;
  bool _captionsSupported = false;
  bool _hearTranslate = true;
  String? _activeCaptionSegmentId;
  String _activeCaptionText = '';
  final List<String> _finalCaptionLines = [];
  Timer? _perSecondBillingTimer;
  Timer? _viewerPollTimer;
  HostSpeechCaptions? _hostSpeech;
  String? _lastSpokenCaptionKey;
  int _sessionSeconds = 0;
  double _sessionCoinsCharged = 0.0;
  int _initialWalletBalance = 0;
  bool _isSubscriberViewer = false;

  String? get _streamId => widget.args?.streamId;
  bool get _isHost =>
      widget.args?.isHost == true ||
      (_stream != null &&
          _stream?.hostId != null &&
          _stream?.hostId == AuthSession.instance.user?.id);
  bool get _isCohost => widget.args?.isCohost == true;
  bool get _isBroadcaster => _isHost || _isCohost;
  bool get _isPrivateStream => _stream?.isPrivate == true;
  List<String> get _captionDisplayLines {
    final lines = <String>[..._finalCaptionLines];
    if (_activeCaptionText.trim().isNotEmpty) lines.add(_activeCaptionText.trim());
    if (lines.length <= 2) return lines;
    return lines.sublist(lines.length - 2);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _agoraController.addListener(_onAgoraController);
    _bootstrap();
  }

  void _onAgoraController() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isCohost && !_streamEnded && !_loading) {
      unawaited(_rejoinCohostBroadcast());
    }
  }

  Future<void> _rejoinCohostBroadcast() async {
    final id = _streamId;
    if (id == null || id.isEmpty || _rejoiningCohost || !_isCohost) return;
    _rejoiningCohost = true;
    try {
      await _agoraKey.currentState?.tearDown();
      final token = await _streamsRepo.getToken(id, role: 'cohost');
      if (!mounted) return;
      setState(() {
        _agoraToken = token;
        _agoraKey = GlobalKey<AgoraStreamViewState>();
      });
    } catch (_) {
      try {
        final token = await _streamsRepo.getToken(id, role: 'host');
        if (!mounted) return;
        setState(() {
          _agoraToken = token;
          _agoraKey = GlobalKey<AgoraStreamViewState>();
        });
      } catch (_) {}
    } finally {
      _rejoiningCohost = false;
    }
  }

  void _applyViewerCount(int? count) {
    if (count == null || count < 0) return;
    if (count <= _viewerCount) return;
    if (!mounted) {
      _viewerCount = count;
      return;
    }
    setState(() => _viewerCount = count);
  }

  int get _summaryGiftCoins {
    final fromStream = _stream?.giftPoints ?? 0;
    return _earnedGiftCoins > fromStream ? _earnedGiftCoins : fromStream;
  }

  int? _parseViewerCount(dynamic raw) {
    if (raw is Map) {
      return int.tryParse('${raw['viewerCount'] ?? raw['count'] ?? raw['viewers'] ?? raw['total']}');
    }
    return int.tryParse('$raw');
  }

  void _startViewerPoll(String streamId) {
    _viewerPollTimer?.cancel();
    _viewerPollTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      try {
        final stream = await _streamsRepo.getStream(streamId);
        _applyViewerCount(stream.viewerCount);
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _perSecondBillingTimer?.cancel();
    _viewerPollTimer?.cancel();
    final id = _streamId;
    if (id != null && id.isNotEmpty && !_streamEnded) {
      if (_isHost) {
        unawaited(() async {
          try {
            await _streamsRepo.endStream(id);
          } catch (_) {}
          try {
            await XLiveSocketClient.instance.endStream(id);
          } catch (_) {}
        }());
      }
      XLiveSocketClient.instance.leaveStream(
        id,
        durationSeconds: _sessionSeconds,
        chargedCoins: _sessionCoinsCharged.ceil(),
      );
    }
    unawaited(LiveHearTranslation.instance.stop());
    _agoraController.setRemoteAudioDucked(false);
    _agoraController.removeListener(_onAgoraController);
    _agoraController.dispose();
    _giftSub?.cancel();
    _viewerSub?.cancel();
    _viewersListSub?.cancel();
    _endedSub?.cancel();
    _removedSub?.cancel();
    _chatSub?.cancel();
    _billingSub?.cancel();
    _mutedSub?.cancel();
    _unmutedSub?.cancel();
    _talkBackGrantedSub?.cancel();
    _talkBackRevokedSub?.cancel();
    _transcriptSub?.cancel();
    _transcriptHistorySub?.cancel();
    _inviteAcceptedSub?.cancel();
    _inLiveInviteSub?.cancel();
    unawaited(_hostSpeech?.stop());
    _hostSpeech = null;
    _liveTimer?.cancel();
    _chatInput.dispose();
    super.dispose();
  }

  void _startLiveTimer(LiveStream stream) {
    _liveTimer?.cancel();
    final base = stream.startedAt ??
        DateTime.now().subtract(Duration(seconds: stream.durationSeconds.clamp(0, 24 * 3600)));
    _liveStartedAt = base;
    void tick() {
      final started = _liveStartedAt;
      if (started == null || !mounted) return;
      final elapsed = DateTime.now().difference(started);
      final total = elapsed.inSeconds < 0 ? 0 : elapsed.inSeconds;
      final h = total ~/ 3600;
      final m = (total % 3600) ~/ 60;
      final s = total % 60;
      final label = h > 0
          ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
          : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
      if (label != _elapsedLabel) setState(() => _elapsedLabel = label);
    }
    tick();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  void _startPerSecondBilling(int pricePerMinute) {
    _perSecondBillingTimer?.cancel();
    if (pricePerMinute <= 0) return;
    _sessionSeconds = 0;
    _sessionCoinsCharged = 0.0;
    final ratePerSecond = pricePerMinute / 60.0;
    _perSecondBillingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _streamEnded) return;
      _sessionSeconds++;
      _sessionCoinsCharged = _sessionSeconds * ratePerSecond;
      final remaining = _initialWalletBalance - _sessionCoinsCharged;
      if (remaining <= 0) {
        _perSecondBillingTimer?.cancel();
        _streamEnded = true;
        _agoraController.tearDown();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Private stream ended — your balance ran out.')),
          );
          Navigator.pop(context);
        }
        return;
      }
      setState(() {});
    });
  }

  String _formatSessionDuration(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _bootstrap() async {
    final id = _streamId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final stream = await _streamsRepo.getStream(id);
      if (!stream.isLive) {
        if (!mounted) return;
        setState(() {
          _joinError = 'This stream has ended';
          _loading = false;
        });
        return;
      }
      final isHostViewer = widget.args?.isHost == true ||
          widget.args?.isCohost == true ||
          stream.hostId == AuthSession.instance.user?.id;
      final isSubscriber = SubscriptionStore.instance.isSubscribedTo(stream.hostId);
      _isSubscriberViewer = isSubscriber;
      if (AuthSession.instance.isSignedIn && stream.isPaid && !isHostViewer && !isSubscriber) {
        await AuthSession.instance.refreshWallet();
        final balance = AuthSession.instance.walletBalance ?? 0;
        _initialWalletBalance = balance;
        if (balance <= 0) {
          if (!mounted) return;
          setState(() {
            _joinError = 'Insufficient balance to join this private stream';
            _loading = false;
          });
          await _showInsufficientBalanceDialog(stream.pricePerMinute, balance);
          return;
        }
      }
      if (AuthSession.instance.isSignedIn) {
        final ack = await XLiveSocketClient.instance.emitWithAck('join_stream', {'streamId': id});
        if (ack['ok'] != true) {
          final msg = ack['error']?.toString() ?? ack['message']?.toString() ?? 'Unable to join stream';
          if (!mounted) return;
          final lower = msg.toLowerCase();
          if (lower.contains('balance') || lower.contains('insufficient') || lower.contains('funds')) {
            setState(() {
              _joinError = 'Insufficient balance to join this private stream';
              _loading = false;
            });
            await _showInsufficientBalanceDialog(stream.pricePerMinute, AuthSession.instance.walletBalance ?? 0);
            return;
          }
          setState(() {
            _joinError = msg;
            _loading = false;
          });
          return;
        }
        _applyViewerCount(_parseViewerCount(ack));
      }
      AgoraStreamToken? token;
      if (AuthSession.instance.isSignedIn) {
        final isHostRole = widget.args?.isHost == true ||
            stream.hostId == AuthSession.instance.user?.id;
        final preferredRole = isHostRole
            ? 'host'
            : (widget.args?.isCohost == true ? 'cohost' : 'audience');
        try {
          token = await _streamsRepo.getToken(id, role: preferredRole);
        } catch (_) {
          if (preferredRole == 'cohost') {
            token = await _streamsRepo.getToken(id, role: 'host');
          } else {
            rethrow;
          }
        }
      }
      _applyViewerCount(stream.viewerCount);
      final captionsSupported = stream.supportsCaptions;
      final ccPreferred = await AuthSession.instance.sessionStore.readLiveCaptionsEnabled();
      List<StreamCohostMember> cohosts = const [];
      try {
        final cohostsInfo = await _streamsRepo.getCohosts(id);
        cohosts = cohostsInfo.docs;
      } catch (_) {}
      List<GiftCatalogItem> giftCatalog = const [];
      try {
        giftCatalog = await _giftsRepo.getCatalog();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _stream = stream;
        _agoraToken = token;
        _cohosts = cohosts;
        _giftCatalog = giftCatalog;
        _captionsSupported = captionsSupported;
        _ccPreferred = ccPreferred;
        _ccVisible = captionsSupported && ccPreferred;
        _loading = false;
      });
      _startLiveTimer(stream);
      if (stream.isPaid && !_isBroadcaster && !_isSubscriberViewer && stream.pricePerMinute > 0) {
        _startPerSecondBilling(stream.pricePerMinute);
      }
      _bindSocket(id);
      _startViewerPoll(id);
      unawaited(_loadStreamChatHistory(id));
      if (_isHost) {
        XLiveSocketClient.instance.requestStreamViewers(id);
      }
      if (_isHost && (stream.captionsEnabled || stream.saveEnabled)) {
        _hostSpeech = HostSpeechCaptions(onChunk: _handleHostCaptionLine);
        unawaited(_hostSpeech!.start(lang: AuthSession.instance.user?.language));
      } else if (!_isHost && _hearTranslate && (stream.captionsEnabled || stream.saveEnabled)) {
        _agoraController.setRemoteAudioDucked(true);
        LiveHearTranslation.instance.enabled = true;
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _showInsufficientBalanceDialog(int pricePerMinute, int balance) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Insufficient balance', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This private stream costs $pricePerMinute coins per minute. '
              'Your balance is $balance coins. Load funds to join.',
              style: const TextStyle(fontSize: 14.5, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF8A2DDC),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/wallet/xlive');
            },
            child: const Text('Load funds'),
          ),
        ],
      ),
    );
  }

  void _bindSocket(String id) {
    final socket = XLiveSocketClient.instance;
    _giftSub = socket.onGiftSent.listen((event) {
      if (event['streamId']?.toString() != id) return;
      unawaited(_handleGiftSentEvent(event));
    });
    _viewerSub = socket.onStreamViewerCount.listen((event) {
      if (event['streamId']?.toString() != id) return;
      _applyViewerCount(_parseViewerCount(event));
    });
    _viewersListSub = socket.onStreamViewers.listen((event) {
      if (event['streamId']?.toString() != id) return;
      final raw = event['viewers'] ?? event['users'] ?? event['items'];
      if (raw is! List || !mounted) return;
      final count = _parseViewerCount(event) ?? raw.length;
      setState(() {
        if (count > _viewerCount) _viewerCount = count;
        _viewers
          ..clear()
          ..addAll(
            raw.map((item) {
              final map = item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{};
              final userId = map['userId']?.toString() ?? map['id']?.toString() ?? '';
              final muted = map['muted'] == true || map['isMuted'] == true;
              final talkBack = map['talkBack'] == true || map['hasTalkBack'] == true || map['talkBackGranted'] == true;
              if (muted) _mutedViewerIds.add(userId);
              if (talkBack) _talkBackViewerIds.add(userId);
              return LiveStreamViewerRow(
                id: userId,
                name: map['displayName']?.toString() ?? map['username']?.toString() ?? 'Viewer',
                avatarUrl: map['avatarUrl']?.toString(),
                muted: muted,
                talkBack: talkBack,
              );
            }).where((v) => v.id.isNotEmpty),
          );
      });
    });
    _endedSub = socket.onStreamEnded.listen((event) async {
      if (event['streamId']?.toString() != id) return;
      if (!mounted || _streamEnded) return;
      _streamEnded = true;
      await _agoraKey.currentState?.tearDown();
      _agoraController.tearDown();
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/live/summary',
        arguments: LiveSummaryArgs(streamId: id, viewerCount: _viewerCount, giftPoints: _summaryGiftCoins),
      );
    });
    _removedSub = socket.onViewerRemoved.listen((event) async {
      if (event['streamId']?.toString() != id) return;
      final removedId = event['userId']?.toString();
      final me = AuthSession.instance.user?.id ?? socket.userId;
      if (removedId != null && me != null && removedId == me && mounted) {
        _streamEnded = true;
        await _agoraKey.currentState?.tearDown();
        _agoraController.tearDown();
        if (!mounted) return;
        final reason = event['reason']?.toString();
        final message = reason == 'billing_failed'
            ? 'Removed from stream — insufficient wallet balance'
            : (_isCohost ? 'You were removed as co-host' : 'You were removed from the stream');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        Navigator.pop(context);
      }
    });
    _chatSub = socket.onStreamChatMessage.listen((event) {
      if (event['streamId']?.toString() != id) return;
      if (!mounted) return;
      final parsed = _parseStreamChatEvent(event);
      if (parsed.content.isEmpty) return;
      _pushComment(sender: parsed.sender, content: parsed.content);
    });
    _billingSub = socket.onStreamBillingTick.listen((event) {
      if (!_isPrivateStream) return;
      if (event['streamId']?.toString() != id) return;
      if (!mounted) return;
      final amount = event['charged'] ?? event['amount'] ?? event['coins'];
      final ppm = event['pricePerMinute'];
      if (amount != null) {
        final suffix = ppm != null ? ' ($ppm coins/min)' : '';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Billed: $amount coins$suffix')));
        AuthSession.instance.refreshWallet();
      }
    });
    _mutedSub = socket.onStreamViewerMuted.listen((event) {
      if (!_isPrivateStream) return;
      if (event['streamId']?.toString() != id) return;
      final mutedId = event['userId']?.toString();
      final me = AuthSession.instance.user?.id ?? socket.userId;
      if (mutedId != null && me != null && mutedId == me && mounted && _talkBackActive) {
        _agoraController.setMicPublishEnabled(false);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Host muted your mic')));
      }
    });
    _unmutedSub = socket.onStreamViewerUnmuted.listen((event) {
      if (!_isPrivateStream) return;
      if (event['streamId']?.toString() != id) return;
      final unmutedId = event['userId']?.toString();
      final me = AuthSession.instance.user?.id ?? socket.userId;
      if (unmutedId != null && me != null && unmutedId == me && mounted && _talkBackActive) {
        _agoraController.setMicPublishEnabled(true);
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can speak again')));
      }
    });
    _talkBackGrantedSub = socket.onStreamTalkBackGranted.listen((event) {
      if (!_isPrivateStream) return;
      if (event['streamId']?.toString() != id) return;
      final userId = event['userId']?.toString();
      final me = AuthSession.instance.user?.id ?? socket.userId;
      if (userId != null && me != null && userId == me && mounted) {
        setState(() => _talkBackActive = true);
        _agoraController.setTalkBackActive(true);
        _agoraController.setMicPublishEnabled(true);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Talk-back enabled')));
      }
    });
    _talkBackRevokedSub = socket.onStreamTalkBackRevoked.listen((event) {
      if (!_isPrivateStream) return;
      if (event['streamId']?.toString() != id) return;
      final userId = event['userId']?.toString();
      final me = AuthSession.instance.user?.id ?? socket.userId;
      if (userId != null && me != null && userId == me && mounted) {
        setState(() => _talkBackActive = false);
        _agoraController.setTalkBackActive(false);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Talk-back ended')));
      }
    });
    _transcriptSub = socket.onStreamTranscript.listen((event) {
      if (!mounted) return;
      final eventStreamId = event['streamId']?.toString();
      if (eventStreamId != null && eventStreamId.isNotEmpty && eventStreamId != id) return;
      final line = StreamTranscriptLine.fromJson(event);
      if (line.text.isEmpty) return;
      if (_isHost && line.mode == 'translated') return;
      _ingestTranscriptLine(line);
      if (!_captionsSupported) {
        setState(() {
          _captionsSupported = true;
          if (_ccPreferred) _ccVisible = true;
        });
      }
    });
    _transcriptHistorySub = socket.onStreamTranscriptHistory.listen((event) {
      if (event['streamId']?.toString() != id) return;
      if (!mounted) return;
      final raw = event['items'] ?? event['docs'] ?? event['transcripts'];
      if (raw is! List) return;
      for (final item in raw) {
        if (item is! Map) continue;
        final line = StreamTranscriptLine.fromJson(Map<String, dynamic>.from(item));
        if (line.text.isEmpty) continue;
        _ingestTranscriptLine(line, rebuild: false);
      }
      setState(() {
        _captionsSupported = true;
        if (_ccPreferred) _ccVisible = true;
      });
    });
    _inviteAcceptedSub = socket.onStreamInviteAccepted.listen((event) async {
      if (event['streamId']?.toString() != id) return;
      try {
        final cohostsInfo = await _streamsRepo.getCohosts(id);
        if (mounted) setState(() => _cohosts = cohostsInfo.docs);
      } catch (_) {}
    });
    _inLiveInviteSub = socket.onStreamInviteIncoming.listen((event) async {
      if (event['streamId']?.toString() != id) return;
      final inviteId = ApiJson.pickString(event, ['inviteId', 'id', '_id']) ?? '';
      final role = ApiJson.pickString(event, ['role']);
      final isCohostInvite = role?.toLowerCase() == 'cohost' || role?.toLowerCase() == 'co-host';
      if (!isCohostInvite || !mounted || _isBroadcaster) return;

      HapticFeedback.vibrate();
      final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.video_call_rounded, color: Color(0xFF35D3FB)),
              SizedBox(width: 8),
              Text('Co-Host Invitation', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          content: Text(
            '${_stream?.hostName ?? "The host"} invited you to join this live broadcast as a co-host! Your camera and microphone will turn on.',
            style: const TextStyle(fontSize: 14.5, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Decline'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF8A2DDC)),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Accept & Join'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) {
        try {
          if (inviteId.isNotEmpty) {
            await _streamsRepo.acceptInvite(inviteId);
          }
        } catch (_) {}
        if (mounted) {
          Navigator.pushReplacementNamed(
            context,
            '/live/during',
            arguments: LiveDuringArgs(streamId: id, isCohost: true),
          );
        }
      }
    });
  }

  void _ingestTranscriptLine(StreamTranscriptLine line, {bool rebuild = true}) {
    void apply() {
      if (line.isFinal) {
        if (_activeCaptionSegmentId == line.segmentId || _activeCaptionText == line.text) {
          _activeCaptionText = '';
          _activeCaptionSegmentId = null;
        }
        if (_finalCaptionLines.isEmpty || _finalCaptionLines.last != line.text) {
          _finalCaptionLines.add(line.text);
          if (_finalCaptionLines.length > 8) {
            _finalCaptionLines.removeRange(0, _finalCaptionLines.length - 8);
          }
        }
      } else {
        _activeCaptionSegmentId = line.segmentId.isEmpty ? _activeCaptionSegmentId : line.segmentId;
        _activeCaptionText = line.text;
      }
    }

    if (rebuild) {
      setState(apply);
    } else {
      apply();
    }

    if (!_isHost && line.isFinal && line.text.trim().isNotEmpty) {
      unawaited(_maybeSpeakTranslated(line));
    }
  }

  Future<void> _maybeSpeakTranslated(StreamTranscriptLine line) async {
    final target = normalizeLiveLang(AuthSession.instance.user?.language);
    final profileTarget = target.isEmpty ? 'en' : target;

    final result = await TranslationService.instance.translate(
      line.text,
      sourceLang: null,
      targetLang: profileTarget,
    );
    final spoken = result.text.trim().isEmpty ? line.text.trim() : result.text.trim();
    if (!mounted || spoken.isEmpty) return;

    if (_ccVisible && spoken != line.text) {
      setState(() {
        if (_finalCaptionLines.isNotEmpty && _finalCaptionLines.last == line.text) {
          _finalCaptionLines[_finalCaptionLines.length - 1] = spoken;
        } else if (_finalCaptionLines.isEmpty || _finalCaptionLines.last != spoken) {
          _finalCaptionLines.add(spoken);
          if (_finalCaptionLines.length > 8) {
            _finalCaptionLines.removeRange(0, _finalCaptionLines.length - 8);
          }
        }
      });
    }

    if (!_hearTranslate) return;
    final key = '${line.segmentId}|$spoken';
    if (_lastSpokenCaptionKey == key) return;
    _lastSpokenCaptionKey = key;
    _agoraController.setRemoteAudioDucked(true);
    await LiveHearTranslation.instance.speak(spoken, targetLang: profileTarget);
  }

  void _setHearTranslate(bool enabled) {
    setState(() => _hearTranslate = enabled);
    LiveHearTranslation.instance.enabled = enabled;
    if (!enabled) {
      unawaited(LiveHearTranslation.instance.stop());
      _agoraController.setRemoteAudioDucked(false);
    } else if (!_isHost) {
      _agoraController.setRemoteAudioDucked(true);
    }
  }

  Future<void> _toggleCc() async {
    final next = !_ccVisible;
    setState(() {
      _ccPreferred = next;
      _ccVisible = next && _captionsSupported;
    });
    await AuthSession.instance.sessionStore.writeLiveCaptionsEnabled(next);
    if (!mounted) return;
    if (next) {
      final shown = await AuthSession.instance.sessionStore.readAiTranslatorToastShown();
      if (!mounted) return;
      if (!shown) {
        await AuthSession.instance.sessionStore.writeAiTranslatorToastShown();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('AI Translator on'),
            duration: Duration(milliseconds: 1600),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleHostCaptionLine(StreamTranscriptLine line) {
    if (!_isHost) return;
    if (!(_stream?.captionsEnabled == true || _stream?.saveEnabled == true)) return;
    final id = _streamId;
    if (id == null || id.isEmpty) return;
    if (line.text.trim().isEmpty) return;
    _ingestTranscriptLine(line);
    XLiveSocketClient.instance.emitStreamTranscriptChunk(
      streamId: id,
      segmentId: line.segmentId,
      text: line.text,
      sourceLang: line.lang,
      isFinal: line.isFinal,
      timestamp: line.timestamp ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  void _onHostSttChunk(AgoraSttChunk chunk) {
    _handleHostCaptionLine(
      StreamTranscriptLine(
        segmentId: chunk.segmentId,
        text: chunk.text,
        mode: 'original',
        lang: chunk.sourceLang ?? '',
        isFinal: chunk.isFinal,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  Future<void> _loadStreamChatHistory(String streamId) async {
    try {
      final rows = await _streamsRepo.listStreamChat(streamId, page: 1, limit: 50);
      if (!mounted || rows.isEmpty) return;
      final existing = <String>{
        for (final c in _chatLog) '${c.sender}|${c.content}',
      };
      for (final row in rows.reversed) {
        final parsed = _parseStreamChatEvent(row);
        if (parsed.content.isEmpty) continue;
        final key = '${parsed.sender}|${parsed.content}';
        if (existing.contains(key)) continue;
        existing.add(key);
        _pushComment(sender: parsed.sender, content: parsed.content);
      }
    } catch (_) {}
  }

  Future<void> _handleGiftSentEvent(Map<String, dynamic> event) async {
    final data = event['data'] is Map ? Map<String, dynamic>.from(event['data'] as Map) : event;
    final senderObj = data['sender'] ?? data['user'] ?? data['from'];
    String? senderName = data['senderName']?.toString();
    if ((senderName == null || senderName.isEmpty) && senderObj is Map) {
      senderName = senderObj['displayName']?.toString() ??
          senderObj['username']?.toString() ??
          senderObj['name']?.toString();
    }
    final senderId = data['senderId']?.toString() ??
        (senderObj is Map ? (senderObj['id'] ?? senderObj['_id'])?.toString() : null);
    if ((senderName == null || senderName.isEmpty || senderName == 'Viewer') &&
        senderId != null &&
        senderId.isNotEmpty) {
      try {
        final user = await _usersRepo.getUser(senderId);
        final resolved = user.effectiveDisplayName.trim();
        if (resolved.isNotEmpty && resolved != 'User') senderName = resolved;
      } catch (_) {}
    }
    final resolvedSender = (senderName == null || senderName.isEmpty) ? 'Viewer' : senderName;

    final giftObj = data['gift'];
    String giftLabel = data['giftName']?.toString() ?? 'Gift';
    final giftId = data['giftId']?.toString() ??
        (giftObj is Map ? (giftObj['id'] ?? giftObj['_id'])?.toString() : null);
    if (giftObj is Map) {
      giftLabel = giftObj['name']?.toString() ?? giftObj['title']?.toString() ?? giftLabel;
    }
    if ((giftLabel.isEmpty || giftLabel == 'Gift') && giftId != null && giftId.isNotEmpty) {
      for (final item in _giftCatalog) {
        if (item.id == giftId) {
          giftLabel = item.name;
          break;
        }
      }
    }
    final qty = int.tryParse('${data['quantity'] ?? event['quantity'] ?? 1}') ?? 1;
    var unitCoins = 0;
    if (giftObj is Map) {
      unitCoins = int.tryParse('${giftObj['price'] ?? giftObj['cost'] ?? giftObj['coinPrice'] ?? giftObj['points'] ?? 0}') ?? 0;
    }
    if (unitCoins <= 0 && giftId != null && giftId.isNotEmpty) {
      for (final item in _giftCatalog) {
        if (item.id == giftId) {
          unitCoins = item.price;
          break;
        }
      }
    }
    final eventCoins = int.tryParse('${data['points'] ?? data['coins'] ?? data['amount'] ?? event['points'] ?? 0}') ?? 0;
    final addCoins = eventCoins > 0 ? eventCoins : unitCoins * (qty <= 0 ? 1 : qty);
    if (!mounted) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _giftSeq += 1;
      if (addCoins > 0) _earnedGiftCoins += addCoins;
      _giftBursts.add(
        LiveGiftBurst(
          id: 'g$_giftSeq',
          senderName: resolvedSender,
          giftLabel: giftLabel,
          quantity: qty,
          toHost: _isHost,
        ),
      );
      if (_giftBursts.length > 8) _giftBursts.removeAt(0);
    });
    if (_isHost) AuthSession.instance.refreshWallet();
  }

  ({String sender, String content}) _parseStreamChatEvent(Map<String, dynamic> event) {
    final comment = event['comment'];
    Map<String, dynamic> map = event;
    if (comment is Map) map = Map<String, dynamic>.from(comment);
    final message = map['message'];
    if (message is Map) map = Map<String, dynamic>.from(message);
    final senderObj = map['sender'] ?? map['user'] ?? map['user'];
    String? senderFromObj;
    if (senderObj is Map) {
      senderFromObj = senderObj['displayName']?.toString() ??
          senderObj['username']?.toString() ??
          senderObj['name']?.toString();
    }
    final sender =
        map['senderName']?.toString() ?? map['userName']?.toString() ?? senderFromObj ?? map['userId']?.toString() ?? 'Viewer';
    var content = map['content']?.toString() ?? map['text']?.toString() ?? map['body']?.toString() ?? '';
    final mediaType = (map['mediaType']?.toString() ?? '').toLowerCase();
    final mediaUrl = map['mediaUrl']?.toString() ?? '';
    if (content.trim().isEmpty && mediaUrl.isNotEmpty) {
      if (mediaType.contains('image') || mediaType.contains('photo')) {
        content = 'Photo';
      } else if (mediaType.contains('video')) {
        content = 'Video';
      } else {
        content = 'Document';
      }
    } else if (mediaUrl.isNotEmpty && (mediaType.contains('document') || mediaType.contains('file'))) {
      content = content.contains('📎') ? content : '📎 $content';
    }
    return (sender: sender, content: content);
  }

  void _pushComment({required String sender, required String content, String? replyTo}) {
    if (content.isEmpty) return;
    setState(() {
      _commentSeq += 1;
      final item = LiveFloatingComment(id: 'c$_commentSeq', sender: sender, content: content, replyTo: replyTo);
      _floatingComments.add(item);
      _chatLog.add(item);
      if (_floatingComments.length > 20) _floatingComments.removeAt(0);
    });
  }

  void _sendChatMessage() {
    final id = _streamId;
    final text = _chatInput.text.trim();
    if (id == null || text.isEmpty) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to comment')));
      return;
    }
    XLiveSocketClient.instance.sendStreamChatMessage(streamId: id, content: text);
    _chatInput.clear();
    _pushComment(sender: 'You', content: text, replyTo: _replyToSender);
    setState(() => _replyToSender = null);
  }

  Future<void> _attachToLiveChat() async {
    final id = _streamId;
    if (id == null || id.isEmpty) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to share a file')));
      return;
    }
    final choice = await showChatAttachSheet(context);
    if (choice == null || !mounted) return;
    try {
      final pickedList = await pickChatAttachments(context, choice);
      if (pickedList.isEmpty || !mounted) return;
      for (final picked in pickedList) {
        if (!mounted) return;
        final filename = picked.file.name.trim().isEmpty
            ? (picked.isVideo ? 'video.mp4' : picked.isDocument ? 'document.bin' : 'image.jpg')
            : picked.file.name;
        final mediaType = picked.isDocument
            ? 'document'
            : picked.isVideo
                ? 'video'
                : 'image';
        final caption = _chatInput.text.trim();
        final uploaded = await _streamsRepo.uploadStreamChatFile(
          streamId: id,
          filePath: picked.file.path,
          filename: filename,
          content: caption.isEmpty ? filename : caption,
          mediaType: mediaType,
        );
        final label = mediaType == 'document'
            ? '📎 ${uploaded.content?.trim().isNotEmpty == true ? uploaded.content!.trim() : filename}'
            : (uploaded.content?.trim().isNotEmpty == true ? uploaded.content!.trim() : filename);
        XLiveSocketClient.instance.sendStreamChatMessage(
          streamId: id,
          content: label,
          mediaUrl: uploaded.mediaUrl,
          mediaType: mediaType,
        );
        _pushComment(sender: 'You', content: label);
      }
      if (!mounted) return;
      _chatInput.clear();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  void _toggleHostMic() {
    final next = !_agoraController.hostMicEnabled;
    _agoraController.setHostMicEnabled(next);
    setState(() {});
  }

  void _toggleHostCamera() {
    if (_agoraController.screenShareActive) return;
    final next = !_agoraController.hostCameraEnabled;
    _agoraController.setHostCameraEnabled(next);
    setState(() {});
  }

  void _toggleScreenShare() {
    if (!_isPrivateStream) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Screen sharing is only available in private live streams')),
      );
      return;
    }
    if (!_isBroadcaster) return;
    final next = !_agoraController.screenShareActive;
    if (next && _agoraController.hasRemoteScreenShare) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Wait until the current screen share ends')),
      );
      return;
    }
    _agoraController.setScreenShareActive(next);
    setState(() {});
  }

  void _openPeoplePanel() async {
    final id = _streamId;
    if (id == null || id.isEmpty) return;
    await showLivePeoplePanel(
      context,
      streamId: id,
      viewerCount: _viewerCount,
      allowCohost: _isPrivateStream,
    );
    if (mounted) {
      try {
        final cohostsInfo = await _streamsRepo.getCohosts(id);
        setState(() => _cohosts = cohostsInfo.docs);
      } catch (_) {}
    }
  }

  Future<void> _shareLive() async {
    final id = _streamId?.trim();
    if (id == null || id.isEmpty) return;
    final host = (_stream?.hostName ?? 'this creator').trim();
    final title = (_stream?.title ?? '').trim();
    final link = '${const ApiConfig().apiBaseUrl}/live/$id';
    final text = title.isNotEmpty && title != 'Live stream'
        ? 'Watch "$title" live on Xlive with $host\n$link'
        : 'Watch $host live on Xlive\n$link';
    try {
      if (AuthSession.instance.isSignedIn) {
        await FeedRepository().recordInteraction(action: 'share', targetType: 'stream', targetId: id);
      }
      await Share.share(text);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _tearDownAndExit({
    required bool toSummary,
    StreamReplayDetail? initialReplay,
    bool replayUploadFailed = false,
  }) async {
    final id = _streamId;
    if (id == null) return;
    _streamEnded = true;
    await _agoraKey.currentState?.tearDown();
    _agoraController.tearDown();
    try {
      await XLiveSocketClient.instance.leaveStream(id);
    } catch (_) {}
    if (!mounted) return;
    if (toSummary) {
      Navigator.pushReplacementNamed(
        context,
        '/live/summary',
        arguments: LiveSummaryArgs(
          streamId: id,
          viewerCount: _viewerCount,
          giftPoints: _summaryGiftCoins,
          initialReplay: initialReplay,
          replayUploadFailed: replayUploadFailed,
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<StreamReplayDetail?> _uploadHostReplay(String streamId, String filePath) async {
    final filename = filePath.split(Platform.pathSeparator).last;
    final detail = await _streamsRepo.uploadReplay(
      streamId: streamId,
      filePath: filePath,
      filename: filename.isEmpty ? 'replay.mp4' : filename,
    );
    try {
      await File(filePath).delete();
    } catch (_) {}
    return detail;
  }

  Future<void> _confirmAndEndStream() async {
    if (_ending || _streamEnded) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End Live Stream?'),
        content: const Text(
          'Are you sure you want to end this live broadcast? This will terminate the stream for all viewers and co-hosts.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('End Stream'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _endStream();
    }
  }

  Future<void> _endStream() async {
    if (_ending || _streamEnded) return;
    final id = _streamId;
    if (id == null || id.isEmpty) return;
    setState(() => _ending = true);
    StreamReplayDetail? uploadedReplay;
    var replayUploadFailed = false;
    try {
      if (_isHost) {
        final shouldSave = _stream?.saveEnabled == true;
        try {
          await _streamsRepo.endStream(id);
        } catch (_) {}
        _streamEnded = true;
        try {
          await XLiveSocketClient.instance.endStream(id);
        } catch (_) {}
        String? recordingPath;
        if (shouldSave) {
          recordingPath = await _agoraKey.currentState?.stopLocalRecording();
        }
        await _agoraKey.currentState?.tearDown();
        _agoraController.tearDown();
        try {
          await XLiveSocketClient.instance.leaveStream(id);
        } catch (_) {}
        if (shouldSave) {
          if (recordingPath != null && recordingPath.isNotEmpty) {
            try {
              uploadedReplay = await _uploadHostReplay(id, recordingPath);
            } catch (_) {
              replayUploadFailed = true;
              try {
                await File(recordingPath).delete();
              } catch (_) {}
            }
          } else {
            replayUploadFailed = true;
          }
        }
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/live/summary',
          arguments: LiveSummaryArgs(
            streamId: id,
            viewerCount: _viewerCount,
            giftPoints: _summaryGiftCoins,
            initialReplay: uploadedReplay,
            replayUploadFailed: replayUploadFailed,
          ),
        );
        return;
      }
      _streamEnded = true;
      await _tearDownAndExit(toSummary: true);
    } catch (e) {
      _streamEnded = true;
      await _tearDownAndExit(toSummary: false);
    }
  }

  Future<void> _leaveStream() async {
    if (_ending || _streamEnded) return;
    _streamEnded = true;
    setState(() => _ending = true);
    await _tearDownAndExit(toSummary: false);
  }

  Future<void> _showGiftPicker() async {
    final id = _streamId;
    if (id == null || id.isEmpty || !AuthSession.instance.isSignedIn || _isHost) return;
    try {
      final catalog = await _giftsRepo.getCatalog();
      if (!mounted || catalog.isEmpty) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: const Color(0xFF141414),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Send a gift', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 280,
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 0.82,
                      ),
                      itemCount: catalog.length,
                      itemBuilder: (_, i) {
                        final gift = catalog[i];
                        return Material(
                          color: const Color(0x1AFFFFFF),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () async {
                              Navigator.pop(ctx);
                              HapticFeedback.lightImpact();
                              try {
                                await _giftsRepo.sendGift(streamId: id, giftId: gift.id);
                                await AuthSession.instance.refreshWallet();
                              } catch (e) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(friendlyApiMessage(e))),
                                );
                              }
                            },
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (gift.iconUrl != null)
                                  CircleAvatar(radius: 22, backgroundImage: NetworkImage(gift.iconUrl!))
                                else
                                  const Icon(Icons.card_giftcard_rounded, color: Colors.amber, size: 32),
                                const SizedBox(height: 6),
                                Text(gift.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11)),
                                Text('${gift.price} coins', style: const TextStyle(color: LiveTheme.sky, fontSize: 10, fontWeight: FontWeight.w700)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyApiMessage(e))));
    }
  }

  Future<void> _openManageViewers() async {
    final id = _streamId;
    if (id == null || !_isHost) return;
    XLiveSocketClient.instance.requestStreamViewers(id);
    await showLiveManageViewersSheet(
      context,
      viewers: _viewers,
      talkBackControls: _isPrivateStream,
      onToggleMute: (v) async {
        if (!v.talkBack) return;
        final muted = _mutedViewerIds.contains(v.id);
        final ok = muted
            ? await XLiveSocketClient.instance.unmuteViewer(streamId: id, userId: v.id)
            : await XLiveSocketClient.instance.muteViewer(streamId: id, userId: v.id);
        if (ok && mounted) {
          setState(() {
            if (muted) {
              _mutedViewerIds.remove(v.id);
            } else {
              _mutedViewerIds.add(v.id);
            }
          });
        }
      },
      onToggleTalkBack: (v) async {
        final granted = _talkBackViewerIds.contains(v.id);
        final ok = granted
            ? await XLiveSocketClient.instance.revokeTalkBack(streamId: id, userId: v.id)
            : await XLiveSocketClient.instance.grantTalkBack(streamId: id, userId: v.id);
        if (ok && mounted) {
          setState(() {
            if (granted) {
              _talkBackViewerIds.remove(v.id);
            } else {
              _talkBackViewerIds.add(v.id);
            }
          });
        }
      },
      onRemove: (userId) async {
        final ok = await XLiveSocketClient.instance.removeViewer(streamId: id, userId: userId);
        if (ok && mounted) setState(() => _viewers.removeWhere((x) => x.id == userId));
      },
    );
  }

  void _toggleViewerMic() {
    if (!_talkBackActive) return;
    final next = !_agoraController.micPublishEnabled;
    _agoraController.setMicPublishEnabled(next);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.white)));
    }
    if (_joinError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_joinError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Go back')),
              ],
            ),
          ),
        ),
      );
    }
    if (_streamId == null || _streamId!.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Live')),
        body: const Center(child: Text('No stream selected')),
      );
    }

    return PopScope(
      canPop: !_isHost || _streamEnded,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_isHost && !_streamEnded) {
          await _confirmAndEndStream();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: _agoraToken != null
                ? AgoraStreamView(
                    key: _agoraKey,
                    credentials: _agoraToken!,
                    isHost: _isHost,
                    isCohost: _isCohost,
                    channelFallback: _streamId!,
                    controller: _agoraController,
                    fallback: _streamBackdrop(),
                    onSttChunk: _isHost && ((_stream?.captionsEnabled ?? false) || (_stream?.saveEnabled ?? false))
                        ? _onHostSttChunk
                        : null,
                    recordLocally: _isHost && (_stream?.saveEnabled == true),
                    hostName: _stream?.hostName ?? 'Creator',
                    hostAvatarUrl: _stream?.hostAvatarUrl,
                    hostUserId: _stream?.hostId,
                    cohosts: _cohosts,
                    localDisplayName: AuthSession.instance.user?.displayName ?? AuthSession.instance.user?.username ?? 'You',
                    localAvatarUrl: AuthSession.instance.user?.avatarUrl,
                  )
                : _streamBackdrop(),
          ),
          if (_agoraToken == null) Positioned.fill(child: Container(color: Colors.black45)),
          LiveGiftBurstOverlay(bursts: _giftBursts),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isHost)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            LiveViewerPopover(
                              viewers: _viewers.map((v) => LiveViewerChip(id: v.id, name: v.name, avatarUrl: v.avatarUrl)).toList(),
                              totalCount: _viewerCount,
                              onSeeAll: _openManageViewers,
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.45),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                              ),
                              child: Text(
                                _elapsedLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_captionsSupported) ...[
                                  LiveAiTranslatorToggleButton(
                                    enabled: true,
                                    active: _ccVisible,
                                    onPressed: _toggleCc,
                                  ),
                                  const SizedBox(width: 2),
                                ],
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _streamId == null ? null : _openPeoplePanel,
                                  icon: const Icon(Icons.groups_rounded, color: Colors.white, size: 21),
                                  tooltip: 'Co-hosts',
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _streamId == null
                                      ? null
                                      : () => showLiveInviteSheet(
                                            context,
                                            streamId: _streamId!,
                                            allowCohost: _isPrivateStream,
                                          ),
                                  icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 21),
                                  tooltip: 'Invite people',
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _toggleHostMic,
                                  icon: Icon(
                                    _agoraController.hostMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  tooltip: _agoraController.hostMicEnabled ? 'Mute mic' : 'Unmute mic',
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _agoraController.screenShareActive ? null : _toggleHostCamera,
                                  icon: Icon(
                                    _agoraController.hostCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  tooltip: _agoraController.hostCameraEnabled ? 'Camera off' : 'Camera on',
                                ),
                                if (_agoraController.canFlipCamera)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                    onPressed: _agoraController.screenShareActive || !_agoraController.hostCameraEnabled
                                        ? null
                                        : () => _agoraKey.currentState?.flipCamera(),
                                    icon: const Icon(Icons.cameraswitch_rounded, color: Colors.white, size: 21),
                                    tooltip: 'Flip camera',
                                  ),
                                if (_isPrivateStream && (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS))
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                    onPressed: _toggleScreenShare,
                                    icon: Icon(
                                      _agoraController.screenShareActive ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                                      color: _agoraController.screenShareActive ? LiveTheme.sky : Colors.white,
                                      size: 21,
                                    ),
                                    tooltip: _agoraController.screenShareActive ? 'Stop share' : 'Share screen',
                                  ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _streamId == null ? null : _shareLive,
                                  icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 21),
                                  tooltip: 'Share stream',
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _streamId == null ? null : () => showLiveGiftHistorySheet(context, streamId: _streamId!),
                                  icon: const Icon(Icons.card_giftcard_outlined, color: Colors.white, size: 21),
                                  tooltip: 'Gift history',
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _ending ? null : _confirmAndEndStream,
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: _ending
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.power_settings_new_rounded, color: Colors.white, size: 15),
                                        SizedBox(width: 4),
                                        Text(
                                          'End',
                                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (_isCohost)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(
                      children: [
                        LiveHostBar(
                          hostName: _stream?.hostName ?? 'Creator',
                          hostAvatarUrl: _stream?.hostAvatarUrl,
                          viewerCount: _viewerCount,
                          elapsedLabel: _elapsedLabel,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _toggleHostMic,
                                  icon: Icon(
                                    _agoraController.hostMicEnabled ? Icons.mic_rounded : Icons.mic_off_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  tooltip: _agoraController.hostMicEnabled ? 'Mute mic' : 'Unmute mic',
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                  onPressed: _agoraController.screenShareActive ? null : _toggleHostCamera,
                                  icon: Icon(
                                    _agoraController.hostCameraEnabled ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                                    color: Colors.white,
                                    size: 21,
                                  ),
                                  tooltip: _agoraController.hostCameraEnabled ? 'Camera off' : 'Camera on',
                                ),
                                if (_isPrivateStream && (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS))
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                                    onPressed: _toggleScreenShare,
                                    icon: Icon(
                                      _agoraController.screenShareActive ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                                      color: _agoraController.screenShareActive ? LiveTheme.sky : Colors.white,
                                      size: 21,
                                    ),
                                    tooltip: _agoraController.screenShareActive ? 'Stop share' : 'Share screen',
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _ending ? null : _leaveStream,
                            borderRadius: BorderRadius.circular(999),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text('Leave', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _ending ? null : _leaveStream,
                              borderRadius: BorderRadius.circular(999),
                              child: Container(
                                width: 36,
                                height: 36,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: LiveTheme.pillFill,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: LiveTheme.pillBorder),
                                ),
                                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: LiveHostBar(
                            hostName: _stream?.hostName ?? 'Creator',
                            hostAvatarUrl: _stream?.hostAvatarUrl,
                            viewerCount: _viewerCount,
                            elapsedLabel: _elapsedLabel,
                          ),
                        ),
                        if (_captionsSupported) ...[
                          const SizedBox(width: 4),
                          LiveAiTranslatorToggleButton(
                            enabled: true,
                            active: _ccVisible,
                            onPressed: _toggleCc,
                          ),
                          if (!_isHost) ...[
                            const SizedBox(width: 2),
                            LiveHearTranslateToggleButton(
                              enabled: true,
                              active: _hearTranslate,
                              onPressed: () => _setHearTranslate(!_hearTranslate),
                            ),
                          ],
                        ],
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                          onPressed: _streamId == null ? null : _shareLive,
                          icon: const Icon(Icons.ios_share_rounded, color: Colors.white, size: 21),
                        ),
                        if (AuthSession.instance.isSignedIn && !_isHost && _giftCatalog.isNotEmpty)
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
                            onPressed: _showGiftPicker,
                            icon: const Icon(Icons.card_giftcard_rounded, color: LiveTheme.sky, size: 21),
                          ),
                      ],
                    ),
                  ),
                const ConnectionStatusPill(darkBackground: true),
                if (_isSubscriberViewer)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xE68A30E5),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                          SizedBox(width: 5),
                          Text(
                            'Subscriber VIP • All-Access Pass',
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  )
                else if (_isPrivateStream && !_isBroadcaster && (_stream?.pricePerMinute ?? 0) > 0)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xE61F1F1F),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Colors.white12, width: 0.8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.timer_outlined, size: 13, color: Colors.amber),
                          const SizedBox(width: 5),
                          Text(
                            '${_formatSessionDuration(_sessionSeconds)} • ${_sessionCoinsCharged.toStringAsFixed(1)} coins spent (${_stream!.pricePerMinute}/min)',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                Expanded(
                  child: Stack(
                    children: [
                      Align(
                        alignment: Alignment.bottomLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, right: 80, bottom: 8),
                          child: LiveFloatingComments(
                            comments: _floatingComments,
                            isHost: _isHost,
                            onOpen: () => setState(() => _chatPanelOpen = true),
                            onReply: (c) => setState(() {
                              _replyToSender = c.sender;
                              _chatPanelOpen = true;
                            }),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 10, 12),
                          child: Material(
                            color: Colors.black.withValues(alpha: 0.55),
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: 'Live chat',
                              onPressed: () => setState(() => _chatPanelOpen = true),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 72),
                          child: LiveCaptionsOverlay(
                            visible: _ccVisible,
                            lines: _captionDisplayLines,
                          ),
                        ),
                      ),
                      if (_chatPanelOpen)
                        Positioned.fill(
                          child: LiveChatHistoryPanel(
                            comments: _chatLog,
                            controller: _chatInput,
                            onSend: _sendChatMessage,
                            onAttach: AuthSession.instance.isSignedIn ? _attachToLiveChat : null,
                            onClose: () => setState(() => _chatPanelOpen = false),
                          ),
                        ),
                    ],
                  ),
                ),
                if (_replyToSender != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Replying to $_replyToSender', style: const TextStyle(color: LiveTheme.sky, fontSize: 13)),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _replyToSender = null),
                          icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 18),
                        ),
                      ],
                    ),
                  ),
                if (_talkBackActive && !_isHost && _isPrivateStream)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, bottom: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FloatingActionButton.small(
                        heroTag: 'live_mic',
                        backgroundColor: _agoraController.micPublishEnabled ? LiveTheme.purple : Colors.grey.shade700,
                        onPressed: _toggleViewerMic,
                        child: Icon(_agoraController.micPublishEnabled ? Icons.mic_rounded : Icons.mic_off_rounded, color: Colors.white),
                      ),
                    ),
                  ),
                if (!_chatPanelOpen)
                  LiveCommentBar(
                    controller: _chatInput,
                    onSend: _sendChatMessage,
                    onAttach: AuthSession.instance.isSignedIn ? _attachToLiveChat : null,
                    hint: AuthSession.instance.isSignedIn ? 'Add a comment…' : 'Sign in to comment',
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _streamBackdrop() {
    final thumb = _stream?.thumbnailUrl;
    if (thumb != null && thumb.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.network(thumb, fit: BoxFit.cover),
          Container(color: Colors.black45),
        ],
      );
    }
    return Container(
      color: const Color(0xFF141414),
      alignment: Alignment.center,
      child: const Icon(Icons.live_tv_rounded, color: Colors.white24, size: 72),
    );
  }
}

class LiveSummaryScreen extends StatefulWidget {
  const LiveSummaryScreen({super.key, this.args});

  final LiveSummaryArgs? args;

  @override
  State<LiveSummaryScreen> createState() => _LiveSummaryScreenState();
}

class _LiveSummaryScreenState extends State<LiveSummaryScreen> {
  static const _purple = Color(0xFF8A2DDC);
  static const _sky = Color(0xFF35D3FB);

  final _streamsRepo = StreamsRepository();
  List<StreamGiftRecord> _gifts = const [];
  StreamReplayDetail? _replay;
  bool _loading = true;
  bool _busy = false;
  Timer? _replayPollTimer;
  int _replayPollTicks = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _replayPollTimer?.cancel();
    super.dispose();
  }

  int get _coinsEarned {
    final fromGifts = _gifts.fold<int>(0, (sum, g) => sum + (g.points > 0 ? g.points : 0));
    final fromArgs = widget.args?.giftPoints ?? 0;
    return fromGifts > fromArgs ? fromGifts : fromArgs;
  }

  String _coinsEarnedLabel() {
    final n = _coinsEarned;
    if (n <= 0 && _gifts.isNotEmpty) {
      final count = _gifts.fold<int>(0, (sum, g) => sum + (g.quantity <= 0 ? 1 : g.quantity));
      return count == 1 ? '1 gift earned' : '$count gifts earned';
    }
    return n == 1 ? '1 coin earned' : '$n coins earned';
  }

  Future<void> _load() async {
    final id = widget.args?.streamId;
    if (id == null || id.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final giftsFuture = _streamsRepo.giftHistory(id);
      StreamReplayDetail? replay = widget.args?.initialReplay;
      if (replay == null && widget.args?.replayUploadFailed == true) {
        replay = StreamReplayDetail(
          streamId: id,
          saveEnabled: true,
          replaySaved: false,
          recordingStatus: 'failed',
        );
      }
      if (replay == null) {
        try {
          replay = await _streamsRepo.getReplay(id);
        } catch (_) {
          replay = null;
        }
      }
      final gifts = await giftsFuture;
      if (!mounted) return;
      setState(() {
        _gifts = gifts;
        _replay = replay;
        _loading = false;
      });
      if (replay != null) _syncReplayPolling(replay);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _syncReplayPolling(StreamReplayDetail replay) {
    _replayPollTimer?.cancel();
    _replayPollTimer = null;
    if (replay.phase != ReplaySavePhase.processing) return;
    _replayPollTicks = 0;
    _replayPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollReplayStatus());
  }

  Future<void> _pollReplayStatus() async {
    final id = widget.args?.streamId;
    if (id == null || id.isEmpty || !mounted) return;
    _replayPollTicks += 1;
    if (_replayPollTicks > 40) {
      _replayPollTimer?.cancel();
      _replayPollTimer = null;
      return;
    }
    try {
      final detail = await _streamsRepo.getReplay(id);
      if (!mounted) return;
      setState(() => _replay = detail);
      if (detail.phase != ReplaySavePhase.processing) {
        _replayPollTimer?.cancel();
        _replayPollTimer = null;
      }
    } catch (_) {}
  }

  Future<void> _discardSave() async {
    final id = widget.args?.streamId;
    if (id == null || id.isEmpty || _busy) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard save?'),
        content: const Text('This cancels saving a replay for this stream.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _streamsRepo.discardSave(id);
      final detail = await _streamsRepo.getReplay(id);
      if (!mounted) return;
      _replayPollTimer?.cancel();
      _replayPollTimer = null;
      setState(() => _replay = detail);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replay save discarded')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _replayStatusCard(StreamReplayDetail replay) {
    final phase = replay.phase;
    late final Color accent;
    late final IconData icon;
    late final String title;
    late final String body;

    switch (phase) {
      case ReplaySavePhase.saved:
        accent = const Color(0xFF16A34A);
        icon = Icons.check_circle_rounded;
        title = 'Saved';
        body = 'Your replay is ready. It also appears in My replays.';
      case ReplaySavePhase.processing:
        accent = _purple;
        icon = Icons.hourglass_top_rounded;
        title = 'Processing';
        body = 'Your recording is uploading and finishing. This usually takes a moment.';
      case ReplaySavePhase.failed:
        accent = const Color(0xFFDC2626);
        icon = Icons.error_outline_rounded;
        title = 'Failed';
        body = 'Saving this replay did not complete. You can discard it or check back in My replays later.';
      case ReplaySavePhase.discarded:
        accent = Colors.grey.shade700;
        icon = Icons.delete_outline_rounded;
        title = 'Discarded';
        body = 'This stream will not be kept as a replay.';
      case ReplaySavePhase.off:
        accent = Colors.grey.shade600;
        icon = Icons.videocam_off_outlined;
        title = 'Not saved';
        body = 'Replay saving was off for this stream.';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 22),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: accent)),
              if (phase == ReplaySavePhase.processing) ...[
                const Spacer(),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(body, style: TextStyle(color: Colors.grey.shade700, height: 1.35)),
          const SizedBox(height: 14),
          Row(
            children: [
              if (replay.canWatch)
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: _purple),
                    onPressed: () => Navigator.pushNamed(context, '/live/replay', arguments: widget.args?.streamId),
                    child: const Text('Watch replay'),
                  ),
                ),
              if (replay.canWatch && replay.canDiscard) const SizedBox(width: 10),
              if (replay.canDiscard)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _discardSave,
                    child: const Text('Discard'),
                  ),
                ),
              if (phase == ReplaySavePhase.failed)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            try {
                              final detail = await _streamsRepo.getReplay(widget.args!.streamId);
                              if (!mounted) return;
                              setState(() => _replay = detail);
                              _syncReplayPolling(detail);
                            } finally {
                              if (mounted) setState(() => _busy = false);
                            }
                          },
                    child: const Text('Check again'),
                  ),
                ),
            ],
          ),
          if (phase == ReplaySavePhase.saved) ...[
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/live/replays', arguments: true),
              child: const Text('Open My replays'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final replay = _replay;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Stream ended', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Text(
              '${args?.viewerCount ?? 0} viewers · ${_coinsEarnedLabel()}',
              style: const TextStyle(color: Colors.black54),
            ),
            if (replay != null && replay.saveEnabled) ...[
              const SizedBox(height: 18),
              _replayStatusCard(replay),
            ],
            const SizedBox(height: 24),
            const Text('Gifts earned', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_gifts.isEmpty)
              const Expanded(child: Center(child: Text('No gifts in this stream', style: TextStyle(color: Colors.black45))))
            else
              Expanded(
                child: ListView.separated(
                  itemCount: _gifts.length,
                  separatorBuilder: (_, index) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final gift = _gifts[i];
                    return ListTile(
                      leading: gift.iconUrl == null
                          ? const Icon(Icons.card_giftcard_rounded)
                          : CircleAvatar(backgroundImage: NetworkImage(gift.iconUrl!)),
                      title: Text('${gift.senderName ?? 'Viewer'} sent ${gift.giftName ?? 'Gift'}'),
                      subtitle: Text(gift.quantity > 1 ? '×${gift.quantity}' : 'Gift'),
                      trailing: Text('x${gift.quantity}'),
                    );
                  },
                ),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [_purple, _sky]),
                  borderRadius: BorderRadius.all(Radius.circular(14)),
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
                  child: const Text('Done', style: TextStyle(color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class LiveInviteArgs {
  const LiveInviteArgs({required this.streamId, this.allowCohost = false});

  final String streamId;
  final bool allowCohost;
}

class LiveInviteScreen extends StatefulWidget {
  const LiveInviteScreen({super.key, this.args});

  final LiveInviteArgs? args;

  @override
  State<LiveInviteScreen> createState() => _LiveInviteScreenState();
}

class _LiveInviteScreenState extends State<LiveInviteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final streamId = widget.args?.streamId;
      if (streamId == null || streamId.isEmpty || !mounted) return;
      var allowCohost = widget.args?.allowCohost ?? false;
      if (!allowCohost) {
        try {
          final stream = await StreamsRepository().getStream(streamId);
          allowCohost = stream.isPrivate;
        } catch (_) {}
      }
      if (!mounted) return;
      await showLiveInviteSheet(context, streamId: streamId, allowCohost: allowCohost);
      if (mounted) Navigator.maybePop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}
