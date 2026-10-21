import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../features/calls/models/call_models.dart';
import '../../features/streams/models/stream_models.dart';

class AgoraCallView extends StatefulWidget {
  const AgoraCallView({
    super.key,
    required this.credentials,
    required this.callType,
    required this.channelFallback,
    this.isGroup = false,
    this.localCameraOff = false,
    this.fallback,
    this.onEngineReady,
    this.onRemoteCountChanged,
  });

  final AgoraStreamToken credentials;
  final CallMediaType callType;
  final String channelFallback;
  final bool isGroup;
  final bool localCameraOff;
  final Widget? fallback;
  final void Function(RtcEngine engine)? onEngineReady;
  final void Function(int remoteCount)? onRemoteCountChanged;

  @override
  State<AgoraCallView> createState() => _AgoraCallViewState();
}

class _AgoraCallViewState extends State<AgoraCallView> {
  RtcEngine? _engine;
  final Set<int> _remoteUids = <int>{};
  String? _error;
  String? _channelId;

  int? get _remoteUid => _remoteUids.isEmpty ? null : _remoteUids.first;

  void _notifyRemoteCount() {
    widget.onRemoteCountChanged?.call(_remoteUids.length);
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  static void _log(String message) {
    if (kDebugMode) debugPrint('[XLiveCall] $message');
  }

  Future<void> _init() async {
    final cred = widget.credentials;
    final appId = cred.appId?.trim() ?? '';
    _log('init type=${widget.callType} group=${widget.isGroup} appIdLen=${appId.length} tokenLen=${cred.token.length} channel=${cred.channelName} fallback=${widget.channelFallback} uid=${cred.uid} account=${cred.userAccount}');
    if (cred.token.isEmpty || appId.isEmpty) {
      _log('ERROR missing credentials (token or appId empty)');
      if (mounted) setState(() => _error = 'Call unavailable');
      return;
    }
    final cam = await Permission.camera.request();
    final mic = await Permission.microphone.request();
    _log('permissions mic=${mic.isGranted} cam=${cam.isGranted}');
    if (!mic.isGranted) {
      if (mounted) setState(() => _error = 'Microphone access required');
      return;
    }
    if (widget.callType == CallMediaType.video && !cam.isGranted) {
      if (mounted) setState(() => _error = 'Camera access required');
      return;
    }
    final channelId = (cred.channelName?.trim().isNotEmpty == true) ? cred.channelName!.trim() : widget.channelFallback;
    _channelId = channelId;
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (connection, elapsed) {
            _log('joinChannelSuccess channel=${connection.channelId} localUid=${connection.localUid}');
            engine.setEnableSpeakerphone(true);
          },
          onUserJoined: (connection, remoteUid, elapsed) {
            _log('userJoined remoteUid=$remoteUid');
            if (!mounted) return;
            setState(() => _remoteUids.add(remoteUid));
            _notifyRemoteCount();
          },
          onUserOffline: (connection, remoteUid, reason) {
            _log('userOffline remoteUid=$remoteUid reason=$reason');
            if (!mounted) return;
            setState(() => _remoteUids.remove(remoteUid));
            _notifyRemoteCount();
          },
          onError: (err, msg) {
            _log('AGORA ERROR code=$err msg=$msg');
          },
          onTokenPrivilegeWillExpire: (connection, token) {
            _log('tokenPrivilegeWillExpire channel=${connection.channelId}');
          },
        ),
      );
      await engine.enableAudio();
      await engine.setDefaultAudioRouteToSpeakerphone(true);
      if (widget.callType == CallMediaType.video) {
        await engine.enableVideo();
        await engine.startPreview();
      } else {
        await engine.disableVideo();
      }
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      final options = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileCommunication,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        publishMicrophoneTrack: true,
        publishCameraTrack: widget.callType == CallMediaType.video,
        autoSubscribeAudio: true,
        autoSubscribeVideo: widget.callType == CallMediaType.video,
      );
      final account = cred.userAccount?.trim();
      if (account != null && account.isNotEmpty) {
        _log('joining (account) channel=$channelId account=$account');
        await engine.joinChannelWithUserAccount(
          token: cred.token,
          channelId: channelId,
          userAccount: account,
          options: options,
        );
      } else {
        _log('joining (uid) channel=$channelId uid=${cred.uid ?? 0}');
        await engine.joinChannel(
          token: cred.token,
          channelId: channelId,
          uid: cred.uid ?? 0,
          options: options,
        );
      }
      if (!mounted) return;
      setState(() => _engine = engine);
      widget.onEngineReady?.call(engine);
    } catch (e) {
      _log('JOIN EXCEPTION $e');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    final engine = _engine;
    if (engine != null) {
      engine.leaveChannel();
      engine.release();
    }
    super.dispose();
  }

  Widget _localVideo(RtcEngine engine) {
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: engine,
        canvas: const VideoCanvas(uid: 0),
      ),
    );
  }

  Widget _remoteVideo(RtcEngine engine, int uid) {
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: engine,
        canvas: VideoCanvas(uid: uid),
        connection: RtcConnection(channelId: _channelId ?? widget.channelFallback),
      ),
    );
  }

  Widget _selfTile(RtcEngine engine) {
    if (widget.localCameraOff) {
      return Container(
        color: const Color(0xFF2A2038),
        child: const Center(child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 28)),
      );
    }
    return _localVideo(engine);
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.fallback ?? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)));
    }
    final engine = _engine;
    if (engine == null) {
      return widget.fallback ?? const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    if (widget.callType == CallMediaType.audio) {
      return widget.fallback ??
          const Center(child: Icon(Icons.phone_in_talk_rounded, size: 72, color: Colors.white70));
    }

    if (widget.isGroup) {
      return _GroupVideoGrid(
        remoteUids: _remoteUids.toList(),
        selfTile: _selfTile(engine),
        remoteBuilder: (uid) => _remoteVideo(engine, uid),
      );
    }

    final remote = _remoteUid;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (remote != null)
          _remoteVideo(engine, remote)
        else
          widget.fallback ?? const ColoredBox(color: Color(0xFF141024)),
        Positioned(
          right: 16,
          bottom: 130,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 110,
              height: 158,
              child: Container(
                color: const Color(0xFF1A1028),
                child: _selfTile(engine),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _GroupVideoGrid extends StatelessWidget {
  const _GroupVideoGrid({
    required this.remoteUids,
    required this.selfTile,
    required this.remoteBuilder,
  });

  final List<int> remoteUids;
  final Widget selfTile;
  final Widget Function(int uid) remoteBuilder;

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[
      _wrap(selfTile, 'You'),
      for (final uid in remoteUids) _wrap(remoteBuilder(uid), null),
    ];
    final count = tiles.length;
    final columns = count <= 1 ? 1 : (count <= 4 ? 2 : 3);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 90, 8, 130),
      child: GridView.count(
        crossAxisCount: columns,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
        physics: const NeverScrollableScrollPhysics(),
        children: tiles,
      ),
    );
  }

  Widget _wrap(Widget child, String? label) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        color: const Color(0xFF1A1028),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (label != null)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(8)),
                  child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
