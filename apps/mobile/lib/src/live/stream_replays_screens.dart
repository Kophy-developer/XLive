import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../core/media/media_url.dart';
import '../../core/session/auth_session.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/streams/models/stream_models.dart';
import '../../features/streams/streams_repository.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _purpleBright = Color(0xFF8A3FFC);
const _pink = Color(0xFFEC4899);
const _black = Color(0xFF0A0A0A);
const _muted = Color(0xFF8E8E99);
const _field = Color(0xFFF4F4F6);
const _page = Color(0xFFFAFAFB);
const _hairline = Color(0xFFE9E9EF);

LinearGradient get _brandGradient => const LinearGradient(
      colors: [_purpleBright, _pink],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

String _formatDuration(int seconds) {
  if (seconds <= 0) return '';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) {
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }
  if (m > 0) {
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }
  return '${s}s';
}

class StreamReplaysScreen extends StatefulWidget {
  const StreamReplaysScreen({super.key, this.initialMine = false});

  final bool initialMine;

  @override
  State<StreamReplaysScreen> createState() => _StreamReplaysScreenState();
}

class _StreamReplaysScreenState extends State<StreamReplaysScreen> with SingleTickerProviderStateMixin {
  final _repo = StreamsRepository();
  late final TabController _tabs;
  List<LiveStream> _all = const [];
  List<LiveStream> _mine = const [];
  bool _loadingAll = true;
  bool _loadingMine = true;
  String? _errorAll;
  String? _errorMine;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialMine ? 1 : 0);
    _loadAll();
    if (AuthSession.instance.isSignedIn) {
      _loadMine();
    } else {
      _loadingMine = false;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loadingAll = true;
      _errorAll = null;
    });
    try {
      final items = await _repo.listReplays(limit: 40);
      if (!mounted) return;
      setState(() {
        _all = items;
        _loadingAll = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAll = false;
        _errorAll = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _loadMine() async {
    if (!AuthSession.instance.isSignedIn) {
      setState(() {
        _mine = const [];
        _loadingMine = false;
        _errorMine = null;
      });
      return;
    }
    setState(() {
      _loadingMine = true;
      _errorMine = null;
    });
    try {
      final items = await _repo.listMyReplays(limit: 40);
      if (!mounted) return;
      setState(() {
        _mine = items;
        _loadingMine = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMine = false;
        _errorMine = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _openDetail(LiveStream stream) async {
    await Navigator.pushNamed(context, '/live/replay', arguments: stream.id);
    if (!mounted) return;
    _loadAll();
    _loadMine();
  }

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: 'Stream replays',
      body: ColoredBox(
        color: _page,
        child: Column(
          children: [
            Material(
              color: Colors.white,
              child: TabBar(
                controller: _tabs,
                labelColor: _purple,
                unselectedLabelColor: Colors.grey.shade600,
                indicatorColor: _purple,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                tabs: const [
                  Tab(text: 'Discover'),
                  Tab(text: 'My replays'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  RefreshIndicator(
                    color: _purple,
                    onRefresh: _loadAll,
                    child: _ReplayListBody(
                      loading: _loadingAll,
                      error: _errorAll,
                      items: _all,
                      emptyTitle: 'No replays yet',
                      emptySubtitle: 'Saved streams appear here once creators finish and keep a replay.',
                      onRetry: _loadAll,
                      onOpen: _openDetail,
                    ),
                  ),
                  RefreshIndicator(
                    color: _purple,
                    onRefresh: _loadMine,
                    child: !AuthSession.instance.isSignedIn
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
                              const _ReplayEmpty(
                                icon: Icons.lock_outline_rounded,
                                title: 'Sign in to see your replays',
                                subtitle: 'Your saved streams show up in this tab.',
                              ),
                            ],
                          )
                        : _ReplayListBody(
                            loading: _loadingMine,
                            error: _errorMine,
                            items: _mine,
                            emptyTitle: 'No saved replays',
                            emptySubtitle: 'Turn on Save replay when going live. Finished streams show up here automatically.',
                            onRetry: _loadMine,
                            onOpen: _openDetail,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StreamReplayDetailScreen extends StatefulWidget {
  const StreamReplayDetailScreen({super.key, required this.streamId});

  final String streamId;

  @override
  State<StreamReplayDetailScreen> createState() => _StreamReplayDetailScreenState();
}

class _StreamReplayDetailScreenState extends State<StreamReplayDetailScreen> {
  final _repo = StreamsRepository();
  LiveStream? _stream;
  StreamReplayDetail? _replay;
  StreamTranscriptDoc? _transcript;
  VideoPlayerController? _player;
  bool _loading = true;
  String? _error;
  bool _showTranscript = false;
  bool _playerReady = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _playerReady = false;
    });
    try {
      final results = await Future.wait([
        _repo.getStream(widget.streamId),
        _repo.getReplay(widget.streamId),
        _repo.getTranscript(widget.streamId),
      ]);
      if (!mounted) return;
      final stream = results[0] as LiveStream;
      final replay = results[1] as StreamReplayDetail;
      final transcript = results[2] as StreamTranscriptDoc;
      setState(() {
        _stream = stream;
        _replay = replay;
        _transcript = transcript;
        _loading = false;
      });
      await _bindPlayer(replay.replayUrl ?? stream.replayUrl);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _bindPlayer(String? url) async {
    await _player?.dispose();
    _player = null;
    if (!mounted) return;
    setState(() => _playerReady = false);
    if (url == null || url.isEmpty) return;
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(resolveMediaUrl(url, resourceType: 'video')),
    );
    try {
      await controller.initialize();
      controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      controller.addListener(() {
        if (mounted) setState(() {});
      });
      setState(() {
        _player = controller;
        _playerReady = true;
      });
    } catch (_) {
      await controller.dispose();
      if (mounted) setState(() => _playerReady = false);
    }
  }

  void _togglePlay() {
    final p = _player;
    if (p == null || !p.value.isInitialized) return;
    setState(() {
      if (p.value.isPlaying) {
        p.pause();
      } else {
        p.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    final replay = _replay;
    final url = replay?.replayUrl ?? stream?.replayUrl;
    final durationLabel = _formatDuration(stream?.durationSeconds ?? 0);
    final metaBits = <String>[
      if (stream?.hostName != null && stream!.hostName!.trim().isNotEmpty) stream.hostName!,
      if (durationLabel.isNotEmpty) durationLabel,
      if (stream?.hasTranscript == true || (_transcript?.saved ?? false)) 'Transcript',
    ];

    return XLiveSubpage(
      title: stream?.title ?? 'Replay',
      actions: [
        if ((_transcript?.fullText.isNotEmpty ?? false) || (_transcript?.segments.isNotEmpty ?? false))
          IconButton(
            tooltip: 'Transcript',
            onPressed: () => setState(() => _showTranscript = !_showTranscript),
            icon: Icon(
              _showTranscript ? Icons.closed_caption_rounded : Icons.closed_caption_outlined,
              color: _black,
            ),
          ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _purple))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _purple),
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _purple,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _ReplayCinemaPlayer(
                        player: _player,
                        ready: _playerReady,
                        hasUrl: url != null && url.isNotEmpty,
                        onToggle: _togglePlay,
                      ),
                      const SizedBox(height: 22),
                      Text(
                        stream?.title ?? 'Replay',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: _black,
                          height: 1.2,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (metaBits.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          metaBits.join('  ·  '),
                          style: const TextStyle(color: _muted, fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                      ],
                      if (stream?.hostName != null) ...[
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            UserAvatar(
                              imageUrl: stream?.hostAvatarUrl,
                              radius: 18,
                              backgroundColor: const Color(0xFFEDE7F6),
                              iconColor: _purple,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                stream!.hostName!,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: _black),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (_showTranscript) ...[
                        const SizedBox(height: 22),
                        const Text('Transcript', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _field,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            (_transcript?.fullText.isNotEmpty ?? false)
                                ? _transcript!.fullText
                                : (_transcript?.segments.map((s) => s.text).where((t) => t.isNotEmpty).join('\n') ??
                                    'No transcript saved.'),
                            style: TextStyle(color: Colors.grey.shade800, height: 1.45, fontSize: 14),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _ReplayCinemaPlayer extends StatelessWidget {
  const _ReplayCinemaPlayer({
    required this.player,
    required this.ready,
    required this.hasUrl,
    required this.onToggle,
  });

  final VideoPlayerController? player;
  final bool ready;
  final bool hasUrl;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final p = player;
    final playing = p?.value.isPlaying == true;
    final aspect = (ready && p != null && p.value.aspectRatio > 0) ? p.value.aspectRatio : 16 / 9;

    return AspectRatio(
      aspectRatio: aspect,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF111114),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF1A1A20), Color(0xFF0C0C0F)],
                  ),
                ),
              ),
              if (ready && p != null)
                GestureDetector(
                  onTap: onToggle,
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: p.value.size.width,
                      height: p.value.size.height,
                      child: VideoPlayer(p),
                    ),
                  ),
                )
              else if (!hasUrl)
                const Center(
                  child: Text(
                    'Replay unavailable',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                )
              else
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white70),
                  ),
                ),
              if (ready && p != null && !playing)
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _brandGradient,
                        boxShadow: [
                          BoxShadow(
                            color: _purple.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayListBody extends StatelessWidget {
  const _ReplayListBody({
    required this.loading,
    required this.error,
    required this.items,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRetry,
    required this.onOpen,
  });

  final bool loading;
  final String? error;
  final List<LiveStream> items;
  final String emptyTitle;
  final String emptySubtitle;
  final VoidCallback onRetry;
  final ValueChanged<LiveStream> onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
        itemCount: 5,
        separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: _hairline, indent: 78, endIndent: 20),
        itemBuilder: (_, _) => const _ReplayRowSkeleton(),
      );
    }
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          Text(error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
          const SizedBox(height: 14),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purple),
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          _ReplayEmpty(icon: Icons.video_library_outlined, title: emptyTitle, subtitle: emptySubtitle),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
      itemCount: items.length,
      separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1, color: _hairline, indent: 78, endIndent: 20),
      itemBuilder: (_, i) {
        final item = items[i];
        return _ReplayRow(stream: item, onTap: () => onOpen(item));
      },
    );
  }
}

class _ReplayRowSkeleton extends StatelessWidget {
  const _ReplayRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEBEBEB),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 16,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEBEBEB),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: 140,
                  height: 12,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFEBEBEB),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplayRow extends StatelessWidget {
  const _ReplayRow({required this.stream, required this.onTap});

  final LiveStream stream;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = _formatDuration(stream.durationSeconds);
    final meta = <String>[
      if ((stream.hostName ?? '').trim().isNotEmpty) stream.hostName!.trim(),
      if (duration.isNotEmpty) duration,
      if (stream.isPrivate) 'Private',
      if (stream.hasTranscript || stream.transcriptSaved) 'Transcript',
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              UserAvatar(
                imageUrl: stream.hostAvatarUrl,
                radius: 24,
                backgroundColor: const Color(0xFFEDE7F6),
                iconColor: _purple,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stream.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: _black,
                        height: 1.25,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        meta.join('  ·  '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: _muted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _brandGradient,
                ),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReplayEmpty extends StatelessWidget {
  const _ReplayEmpty({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF3E8FF),
              border: Border.all(color: const Color(0xFFE9D5FF)),
            ),
            child: Icon(icon, color: _purple, size: 30),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.2),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.45),
          ),
        ],
      ),
    );
  }
}
