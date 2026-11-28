import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/widgets/user_avatar.dart';
import '../../features/streams/models/stream_models.dart';
import 'agora_stream_controller.dart';

class AgoraSttChunk {
  const AgoraSttChunk({
    required this.text,
    required this.segmentId,
    required this.isFinal,
    this.sourceLang,
  });

  final String text;
  final String segmentId;
  final bool isFinal;
  final String? sourceLang;
}

class AgoraStreamView extends StatefulWidget {
  const AgoraStreamView({
    super.key,
    required this.credentials,
    required this.isHost,
    this.isCohost = false,
    required this.channelFallback,
    this.controller,
    this.fallback,
    this.onSttChunk,
    this.recordLocally = false,
    this.hostName,
    this.hostAvatarUrl,
    this.hostUserId,
    this.cohosts = const [],
    this.localDisplayName,
    this.localAvatarUrl,
  });

  final AgoraStreamToken credentials;
  final bool isHost;
  final bool isCohost;
  final String channelFallback;
  final AgoraStreamController? controller;
  final Widget? fallback;
  final ValueChanged<AgoraSttChunk>? onSttChunk;
  final bool recordLocally;
  final String? hostName;
  final String? hostAvatarUrl;
  final String? hostUserId;
  final List<StreamCohostMember> cohosts;
  final String? localDisplayName;
  final String? localAvatarUrl;

  bool get isBroadcaster => isHost || isCohost;

  @override
  State<AgoraStreamView> createState() => AgoraStreamViewState();
}

class _BroadcasterTileData {
  const _BroadcasterTileData({
    required this.uid,
    required this.isLocal,
    required this.isHost,
    required this.name,
    this.avatarUrl,
    this.isVideoMuted = false,
    this.isAudioMuted = false,
    this.isSpeaking = false,
  });

  final int uid;
  final bool isLocal;
  final bool isHost;
  final String name;
  final String? avatarUrl;
  final bool isVideoMuted;
  final bool isAudioMuted;
  final bool isSpeaking;
}

class AgoraStreamViewState extends State<AgoraStreamView> {
  RtcEngine? _engine;
  MediaRecorder? _mediaRecorder;
  final List<int> _remoteUids = [];
  final Map<int, bool> _remoteVideoMuted = {};
  final Map<int, bool> _remoteAudioMuted = {};
  Set<int> _speakingUids = {};
  String? _error;
  String? _channelId;
  String? _recordingPath;
  bool _talkBackActive = false;
  bool _micPublishEnabled = false;
  bool _hostMicEnabled = true;
  bool _hostCameraEnabled = true;
  bool _screenShareActive = false;
  bool _remoteAudioDucked = false;
  int _videoDeviceCount = 0;

  bool get canFlipCamera => widget.isBroadcaster && _videoDeviceCount > 1;

  Future<void> flipCamera() async {
    final engine = _engine;
    if (engine == null || !canFlipCamera) return;
    await engine.switchCamera();
  }

  @override
  void initState() {
    super.initState();
    widget.controller?.addListener(_onControllerChanged);
    _init();
  }

  void _onControllerChanged() {
    final c = widget.controller;
    if (c == null || !mounted) return;
    _applyTalkBack(c.talkBackActive, c.micPublishEnabled);
    if (_remoteAudioDucked != c.remoteAudioDucked) {
      _remoteAudioDucked = c.remoteAudioDucked;
      unawaited(_applyRemoteAudioDuck(_remoteAudioDucked));
    }
    if (widget.isBroadcaster && _hostMicEnabled != c.hostMicEnabled) {
      _hostMicEnabled = c.hostMicEnabled;
      _engine?.enableLocalAudio(c.hostMicEnabled);
      _engine?.muteLocalAudioStream(!c.hostMicEnabled);
      if (mounted) setState(() {});
    }
    if (widget.isBroadcaster && _hostCameraEnabled != c.hostCameraEnabled && !_screenShareActive) {
      _hostCameraEnabled = c.hostCameraEnabled;
      _engine?.enableLocalVideo(c.hostCameraEnabled);
      _engine?.muteLocalVideoStream(!c.hostCameraEnabled);
      if (mounted) setState(() {});
    }
    if (widget.isBroadcaster && _screenShareActive != c.screenShareActive) {
      _applyScreenShare(c.screenShareActive);
    }
  }

  Future<void> _applyRemoteAudioDuck(bool ducked) async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.adjustPlaybackSignalVolume(ducked ? 12 : 100);
    } catch (_) {}
  }

  Future<void> _applyScreenShare(bool active) async {
    final engine = _engine;
    if (!widget.isBroadcaster || engine == null) return;
    if (_screenShareActive == active) return;
    try {
      if (active) {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          try {
            await const MethodChannel('com.xlive.app/screenshare').invokeMethod('showBroadcastPicker');
          } catch (_) {}
        }
        await engine.startScreenCapture(
          const ScreenCaptureParameters2(
            captureAudio: false,
            captureVideo: true,
            videoParams: ScreenVideoParameters(
              dimensions: VideoDimensions(width: 1280, height: 720),
              frameRate: 15,
              bitrate: 1200,
            ),
          ),
        );
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishCameraTrack: false,
            publishScreenTrack: true,
            publishSecondaryScreenTrack: false,
            publishScreenCaptureVideo: true,
            publishScreenCaptureAudio: false,
            publishMicrophoneTrack: true,
          ),
        );
        _screenShareActive = true;
        if (mounted) setState(() {});
      } else {
        await engine.stopScreenCapture();
        final camOn = widget.controller?.hostCameraEnabled ?? _hostCameraEnabled;
        await engine.enableLocalVideo(camOn);
        await engine.muteLocalVideoStream(!camOn);
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            publishCameraTrack: camOn,
            publishScreenTrack: false,
            publishScreenCaptureVideo: false,
            publishScreenCaptureAudio: false,
            publishMicrophoneTrack: widget.controller?.hostMicEnabled ?? _hostMicEnabled,
          ),
        );
        _screenShareActive = false;
        _hostCameraEnabled = camOn;
        if (mounted) setState(() {});
      }
    } catch (e) {
      try {
        await engine.stopScreenCapture();
        final camOn = widget.controller?.hostCameraEnabled ?? _hostCameraEnabled;
        await engine.enableLocalVideo(camOn);
        await engine.muteLocalVideoStream(!camOn);
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            publishCameraTrack: camOn,
            publishScreenTrack: false,
            publishScreenCaptureVideo: false,
            publishMicrophoneTrack: widget.controller?.hostMicEnabled ?? _hostMicEnabled,
          ),
        );
      } catch (_) {}
      widget.controller?.setScreenShareActive(false);
      _screenShareActive = false;
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(active ? 'Screen share unavailable' : 'Could not stop screen share')),
        );
      }
    }
  }

  Future<String?> stopLocalRecording() async {
    final recorder = _mediaRecorder;
    final engine = _engine;
    final path = _recordingPath;
    _mediaRecorder = null;
    _recordingPath = null;
    if (recorder == null) return null;
    try {
      await recorder.stopRecording();
    } catch (_) {}
    if (engine != null) {
      try {
        await engine.destroyMediaRecorder(recorder);
      } catch (_) {}
    }
    if (path == null || path.isEmpty) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    if (await file.length() <= 0) return null;
    return path;
  }

  Future<void> tearDown() async {
    if (_screenShareActive) {
      try {
        await _engine?.stopScreenCapture();
      } catch (_) {}
      _screenShareActive = false;
    }
    if (_mediaRecorder != null) {
      final path = await stopLocalRecording();
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
    }
    final engine = _engine;
    _engine = null;
    if (engine != null) {
      await engine.leaveChannel();
      await engine.release();
    }
    if (mounted) setState(() {});
  }

  Future<void> _startLocalRecording() async {
    if (!widget.isHost || !widget.recordLocally) return;
    final engine = _engine;
    final channelId = _channelId;
    if (engine == null || channelId == null || channelId.isEmpty) return;
    if (_mediaRecorder != null) return;
    try {
      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}${Platform.pathSeparator}xlive_replay_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final MediaRecorder? recorder = await engine.createMediaRecorder(
        RecorderStreamInfo(channelId: channelId, uid: 0),
      );
      if (recorder == null) return;
      _mediaRecorder = recorder;
      _recordingPath = filePath;
      await recorder.setMediaRecorderObserver(
        MediaRecorderObserver(
          onRecorderStateChanged: (channelId, uid, state, reason) {
            if (state == RecorderState.recorderStateError) {
              _recordingPath = null;
            }
          },
        ),
      );
      await recorder.startRecording(
        MediaRecorderConfiguration(
          storagePath: filePath,
          containerFormat: MediaRecorderContainerFormat.formatMp4,
          streamType: MediaRecorderStreamType.streamTypeBoth,
        ),
      );
    } catch (_) {
      final failed = _mediaRecorder;
      _mediaRecorder = null;
      _recordingPath = null;
      if (failed != null) {
        try {
          await engine.destroyMediaRecorder(failed);
        } catch (_) {}
      }
    }
  }

  Future<void> _init() async {
    final cred = widget.credentials;
    final appId = cred.appId?.trim() ?? '';
    if (cred.token.isEmpty || appId.isEmpty) {
      if (mounted) setState(() => _error = 'Live video unavailable');
      return;
    }
    if (widget.isBroadcaster) {
      final cam = await Permission.camera.request();
      final mic = await Permission.microphone.request();
      if (!cam.isGranted || !mic.isGranted) {
        if (mounted) setState(() => _error = 'Camera and microphone access required');
        return;
      }
    } else {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted && widget.controller?.talkBackActive == true) {
        if (mounted) setState(() => _error = 'Microphone access required for talk-back');
        return;
      }
    }
    final channelId = (cred.channelName?.trim().isNotEmpty == true) ? cred.channelName!.trim() : widget.channelFallback;
    _channelId = channelId;
    try {
      final engine = createAgoraRtcEngine();
      await engine.initialize(RtcEngineContext(appId: appId));
      engine.registerEventHandler(
        RtcEngineEventHandler(
          onUserJoined: (connection, remoteUid, elapsed) {
            if (mounted) {
              setState(() {
                if (!_remoteUids.contains(remoteUid)) {
                  _remoteUids.add(remoteUid);
                }
                _remoteVideoMuted[remoteUid] = false;
                _remoteAudioMuted[remoteUid] = false;
              });
            }
          },
          onUserOffline: (connection, remoteUid, reason) {
            widget.controller?.markRemoteScreenShare(remoteUid, false);
            if (mounted) {
              setState(() {
                _remoteUids.remove(remoteUid);
                _remoteVideoMuted.remove(remoteUid);
                _remoteAudioMuted.remove(remoteUid);
                _speakingUids.remove(remoteUid);
              });
            }
          },
          onUserMuteVideo: (connection, remoteUid, muted) {
            if (mounted) {
              setState(() {
                _remoteVideoMuted[remoteUid] = muted;
              });
            }
          },
          onUserMuteAudio: (connection, remoteUid, muted) {
            if (mounted) {
              setState(() {
                _remoteAudioMuted[remoteUid] = muted;
              });
            }
          },
          onLocalVideoStateChanged: (source, state, reason) {
            if (source == VideoSourceType.videoSourceScreen ||
                source == VideoSourceType.videoSourceScreenPrimary) {
              if (state == LocalVideoStreamState.localVideoStreamStateStopped ||
                  state == LocalVideoStreamState.localVideoStreamStateFailed) {
                if (_screenShareActive) {
                  _applyScreenShare(false);
                  widget.controller?.setScreenShareActive(false);
                }
              }
            }
          },
          onRemoteVideoStateChanged: (connection, remoteUid, state, reason, elapsed) {
            if (mounted) {
              final isStopped = state == RemoteVideoState.remoteVideoStateStopped ||
                  state == RemoteVideoState.remoteVideoStateFailed;
              if (isStopped) widget.controller?.markRemoteScreenShare(remoteUid, false);
              if (_remoteVideoMuted[remoteUid] != isStopped) {
                setState(() {
                  _remoteVideoMuted[remoteUid] = isStopped;
                });
              }
            }
          },
          onVideoSizeChanged: (connection, sourceType, uid, width, height, rotation) {
            final isScreen = sourceType == VideoSourceType.videoSourceScreen ||
                sourceType == VideoSourceType.videoSourceScreenPrimary ||
                sourceType == VideoSourceType.videoSourceScreenSecondary;
            if (uid != 0 && isScreen && !_screenShareActive) {
              widget.controller?.markRemoteScreenShare(uid, true);
            }
          },
          onAudioVolumeIndication: (connection, speakers, speakerNumber, totalVolume) {
            if (!mounted) return;
            final speaking = <int>{};
            for (final speaker in speakers) {
              if ((speaker.volume ?? 0) > 12) {
                speaking.add(speaker.uid ?? 0);
              }
            }
            if (!setEquals(_speakingUids, speaking)) {
              setState(() => _speakingUids = speaking);
            }
          },
          onStreamMessage: (connection, remoteUid, streamId, data, length, sentTs) {
            if (!widget.isHost) return;
            final chunk = _parseSttChunk(data);
            if (chunk != null) widget.onSttChunk?.call(chunk);
          },
        ),
      );
      await engine.enableVideo();
      if (widget.isBroadcaster) {
        await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
        _hostMicEnabled = widget.controller?.hostMicEnabled ?? true;
        _hostCameraEnabled = widget.controller?.hostCameraEnabled ?? true;
        await engine.enableLocalAudio(_hostMicEnabled);
        await engine.enableLocalVideo(_hostCameraEnabled);
        await engine.startPreview();
      } else {
        await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
        await engine.enableLocalAudio(false);
      }
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );
      final joinOptions = ChannelMediaOptions(
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
        clientRoleType: widget.isBroadcaster ? ClientRoleType.clientRoleBroadcaster : ClientRoleType.clientRoleAudience,
        publishCameraTrack: widget.isBroadcaster && _hostCameraEnabled,
        publishMicrophoneTrack: widget.isBroadcaster && _hostMicEnabled,
      );
      final account = cred.userAccount?.trim();
      if (account != null && account.isNotEmpty) {
        await engine.joinChannelWithUserAccount(
          token: cred.token,
          channelId: channelId,
          userAccount: account,
          options: joinOptions,
        );
      } else {
        await engine.joinChannel(
          token: cred.token,
          channelId: channelId,
          uid: cred.uid ?? 0,
          options: joinOptions,
        );
      }
      if (widget.isBroadcaster) {
        try {
          final devices = await engine.getVideoDeviceManager().enumerateVideoDevices();
          _videoDeviceCount = devices.length;
        } catch (_) {
          if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android)) {
            _videoDeviceCount = 2;
          }
        }
        widget.controller?.setCanFlipCamera(_videoDeviceCount > 1);
      }
      if (!mounted) return;
      setState(() => _engine = engine);
      await _startLocalRecording();
      final c = widget.controller;
      if (c != null && !widget.isBroadcaster) {
        await _applyTalkBack(c.talkBackActive, c.micPublishEnabled);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _applyTalkBack(bool active, bool micEnabled) async {
    if (widget.isBroadcaster) return;
    final engine = _engine;
    if (engine == null) {
      _talkBackActive = active;
      _micPublishEnabled = micEnabled;
      return;
    }
    if (_talkBackActive && active && _micPublishEnabled != micEnabled) {
      _micPublishEnabled = micEnabled;
      await engine.enableLocalAudio(micEnabled);
      await engine.updateChannelMediaOptions(
        ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: false,
          publishMicrophoneTrack: micEnabled,
        ),
      );
      if (mounted) setState(() {});
      return;
    }
    if (_talkBackActive == active && _micPublishEnabled == micEnabled) return;
    _talkBackActive = active;
    _micPublishEnabled = micEnabled;
    if (active) {
      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: false,
          publishMicrophoneTrack: true,
        ),
      );
      await engine.enableLocalAudio(micEnabled);
      await engine.muteLocalVideoStream(true);
    } else {
      await engine.enableLocalAudio(false);
      await engine.muteLocalVideoStream(true);
      await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
      await engine.updateChannelMediaOptions(
        const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleAudience,
          publishCameraTrack: false,
          publishMicrophoneTrack: false,
        ),
      );
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant AgoraStreamView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
      _onControllerChanged();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    final recorder = _mediaRecorder;
    final engine = _engine;
    final sharing = _screenShareActive;
    _mediaRecorder = null;
    _engine = null;
    _screenShareActive = false;
    if (engine != null && sharing) {
      engine.stopScreenCapture().catchError((_) {});
    }
    if (recorder != null && engine != null) {
      recorder.stopRecording().then((_) {
        engine.destroyMediaRecorder(recorder);
        engine.leaveChannel();
        engine.release();
      }).catchError((_) {
        engine.leaveChannel();
        engine.release();
      });
    } else if (engine != null) {
      engine.leaveChannel();
      engine.release();
    }
    super.dispose();
  }

  AgoraSttChunk? _parseSttChunk(Uint8List data) {
    if (data.isEmpty) return null;
    try {
      final raw = utf8.decode(data, allowMalformed: true).trim();
      if (raw.isEmpty) return null;
      if (raw.startsWith('{')) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final map = Map<String, dynamic>.from(decoded);
          final words = map['words'];
          String? text = map['text']?.toString() ?? map['content']?.toString() ?? map['transcript']?.toString();
          var isFinal = map['isFinal'] == true || map['final'] == true;
          String? segmentId = map['segmentId']?.toString() ?? map['uid']?.toString();
          String? sourceLang = map['sourceLang']?.toString() ?? map['lang']?.toString() ?? map['language']?.toString();
          if ((text == null || text.isEmpty) && words is List && words.isNotEmpty) {
            final last = words.last;
            if (last is Map) {
              text = last['text']?.toString();
              isFinal = last['isFinal'] == true || last['is_final'] == true || isFinal;
              segmentId ??= last['uid']?.toString() ?? last['segmentId']?.toString();
            }
          }
          if (text == null || text.trim().isEmpty) return null;
          return AgoraSttChunk(
            text: text.trim(),
            segmentId: (segmentId == null || segmentId.isEmpty)
                ? 'seg_${DateTime.now().millisecondsSinceEpoch}'
                : segmentId,
            isFinal: isFinal,
            sourceLang: sourceLang,
          );
        }
      }
      if (RegExp(r'^[\x20-\x7E\u00A0-\uFFFF]+$').hasMatch(raw) && raw.length < 500) {
        return AgoraSttChunk(
          text: raw,
          segmentId: 'seg_${DateTime.now().millisecondsSinceEpoch}',
          isFinal: true,
        );
      }
    } catch (_) {}
    return null;
  }

  List<_BroadcasterTileData> _getBroadcasterTiles() {
    final list = <_BroadcasterTileData>[];
    final isBroadcaster = widget.isBroadcaster;

    if (isBroadcaster) {
      final isLocalHost = widget.isHost;
      final localTile = _BroadcasterTileData(
        uid: 0,
        isLocal: true,
        isHost: isLocalHost,
        name: isLocalHost
            ? (widget.hostName ?? widget.localDisplayName ?? 'You (Host)')
            : (widget.localDisplayName ?? 'You (Co-host)'),
        avatarUrl: isLocalHost ? (widget.hostAvatarUrl ?? widget.localAvatarUrl) : widget.localAvatarUrl,
        isVideoMuted: !_screenShareActive && !_hostCameraEnabled,
        isAudioMuted: !_hostMicEnabled,
        isSpeaking: _speakingUids.contains(0),
      );

      if (isLocalHost) {
        list.add(localTile);
        for (var i = 0; i < _remoteUids.length && list.length < 4; i++) {
          final rUid = _remoteUids[i];
          final member = (i < widget.cohosts.length) ? widget.cohosts[i] : null;
          list.add(_BroadcasterTileData(
            uid: rUid,
            isLocal: false,
            isHost: false,
            name: member?.label ?? 'Co-host ${i + 1}',
            avatarUrl: member?.avatarUrl,
            isVideoMuted: _remoteVideoMuted[rUid] == true,
            isAudioMuted: _remoteAudioMuted[rUid] == true,
            isSpeaking: _speakingUids.contains(rUid),
          ));
        }
      } else {
        if (_remoteUids.isNotEmpty) {
          final hostUid = _remoteUids.first;
          list.add(_BroadcasterTileData(
            uid: hostUid,
            isLocal: false,
            isHost: true,
            name: widget.hostName ?? 'Host',
            avatarUrl: widget.hostAvatarUrl,
            isVideoMuted: _remoteVideoMuted[hostUid] == true,
            isAudioMuted: _remoteAudioMuted[hostUid] == true,
            isSpeaking: _speakingUids.contains(hostUid),
          ));
        }
        list.add(localTile);
        for (var i = 1; i < _remoteUids.length && list.length < 4; i++) {
          final rUid = _remoteUids[i];
          final memberIndex = i - 1;
          final member = (memberIndex < widget.cohosts.length) ? widget.cohosts[memberIndex] : null;
          list.add(_BroadcasterTileData(
            uid: rUid,
            isLocal: false,
            isHost: false,
            name: member?.label ?? 'Co-host ${i + 1}',
            avatarUrl: member?.avatarUrl,
            isVideoMuted: _remoteVideoMuted[rUid] == true,
            isAudioMuted: _remoteAudioMuted[rUid] == true,
            isSpeaking: _speakingUids.contains(rUid),
          ));
        }
      }
    } else {
      if (_remoteUids.isNotEmpty) {
        final hostUid = _remoteUids.first;
        list.add(_BroadcasterTileData(
          uid: hostUid,
          isLocal: false,
          isHost: true,
          name: widget.hostName ?? 'Host',
          avatarUrl: widget.hostAvatarUrl,
          isVideoMuted: _remoteVideoMuted[hostUid] == true,
          isAudioMuted: _remoteAudioMuted[hostUid] == true,
          isSpeaking: _speakingUids.contains(hostUid),
        ));
        for (var i = 1; i < _remoteUids.length && list.length < 4; i++) {
          final rUid = _remoteUids[i];
          final memberIndex = i - 1;
          final member = (memberIndex < widget.cohosts.length) ? widget.cohosts[memberIndex] : null;
          list.add(_BroadcasterTileData(
            uid: rUid,
            isLocal: false,
            isHost: false,
            name: member?.label ?? 'Co-host $i',
            avatarUrl: member?.avatarUrl,
            isVideoMuted: _remoteVideoMuted[rUid] == true,
            isAudioMuted: _remoteAudioMuted[rUid] == true,
            isSpeaking: _speakingUids.contains(rUid),
          ));
        }
      }
    }

    return list;
  }

  Widget _buildTile(RtcEngine engine, _BroadcasterTileData tile, {required bool isCompact}) {
    Widget videoContent;
    if (tile.isVideoMuted) {
      videoContent = _buildCameraOffPlaceholder(tile, isCompact: isCompact);
    } else if (tile.isLocal) {
      videoContent = AgoraVideoView(
        key: ValueKey('local_tile_${tile.uid}_${_screenShareActive ? "screen" : "camera"}'),
        controller: VideoViewController(
          rtcEngine: engine,
          canvas: VideoCanvas(
            uid: 0,
            renderMode: _screenShareActive ? RenderModeType.renderModeFit : RenderModeType.renderModeHidden,
            sourceType: _screenShareActive
                ? VideoSourceType.videoSourceScreen
                : VideoSourceType.videoSourceCamera,
          ),
        ),
      );
    } else {
      videoContent = AgoraVideoView(
        key: ValueKey('remote_tile_${tile.uid}'),
        controller: VideoViewController.remote(
          rtcEngine: engine,
          canvas: VideoCanvas(
            uid: tile.uid,
            renderMode: RenderModeType.renderModeHidden,
          ),
          connection: RtcConnection(channelId: _channelId ?? widget.channelFallback),
        ),
      );
    }

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: [
          videoContent,
          if (tile.isSpeaking)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: const Color(0xFF00F2FE),
                      width: 2.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x6600F2FE),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            left: 8,
            bottom: 8,
            child: _buildBroadcasterBadgePill(tile, isCompact: isCompact),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraOffPlaceholder(_BroadcasterTileData tile, {required bool isCompact}) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF222228), Color(0xFF111114)],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: tile.isHost
                    ? const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)])
                    : const LinearGradient(colors: [Color(0xFF35D3FB), Color(0xFF8A2DDC)]),
              ),
              child: UserAvatar(
                imageUrl: tile.avatarUrl,
                radius: isCompact ? 22 : 32,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              tile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: isCompact ? 11 : 13,
              ),
            ),
            const SizedBox(height: 3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_rounded, color: Colors.white54, size: isCompact ? 10 : 12),
                  const SizedBox(width: 3),
                  Text(
                    'Camera off',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: isCompact ? 9 : 10.5,
                      fontWeight: FontWeight.w600,
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

  Widget _buildBroadcasterBadgePill(_BroadcasterTileData tile, {required bool isCompact}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 6 : 8, vertical: isCompact ? 3 : 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white12, width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tile.isHost) ...[
            Icon(Icons.stars_rounded, color: const Color(0xFFFFC107), size: isCompact ? 11 : 13),
            const SizedBox(width: 3),
            Text(
              'Host',
              style: TextStyle(
                color: const Color(0xFFFFC107),
                fontWeight: FontWeight.w800,
                fontSize: isCompact ? 9.5 : 11,
              ),
            ),
          ] else ...[
            Icon(Icons.groups_rounded, color: const Color(0xFF35D3FB), size: isCompact ? 11 : 13),
            const SizedBox(width: 3),
            Text(
              'Co-host',
              style: TextStyle(
                color: const Color(0xFF35D3FB),
                fontWeight: FontWeight.w800,
                fontSize: isCompact ? 9.5 : 11,
              ),
            ),
          ],
          const SizedBox(width: 4),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: isCompact ? 70 : 110),
            child: Text(
              tile.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: isCompact ? 9.5 : 11,
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (tile.isAudioMuted)
            Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: isCompact ? 11 : 12)
          else if (tile.isSpeaking)
            Icon(Icons.graphic_eq_rounded, color: const Color(0xFF00F2FE), size: isCompact ? 11 : 12)
          else
            Icon(Icons.mic_rounded, color: Colors.white60, size: isCompact ? 10 : 11.5),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 48),
              const SizedBox(height: 12),
              Text(
                widget.isBroadcaster ? 'Could not start camera' : 'Could not join live video',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }
    final engine = _engine;
    if (engine == null) {
      return widget.fallback ?? const Center(child: CircularProgressIndicator(color: Colors.white));
    }

    final tiles = _getBroadcasterTiles();
    if (tiles.isEmpty) {
      if (widget.isBroadcaster) {
        return const Center(
          child: Text('Starting camera…', style: TextStyle(color: Colors.white70, fontSize: 16)),
        );
      }
      return widget.fallback ??
          const Center(
            child: Text('Waiting for host…', style: TextStyle(color: Colors.white70, fontSize: 16)),
          );
    }

    if (tiles.length == 1) {
      return _buildTile(engine, tiles[0], isCompact: false);
    }

    if (tiles.length == 2) {
      return Column(
        children: [
          Expanded(child: _buildTile(engine, tiles[0], isCompact: false)),
          Container(height: 2, color: const Color(0xFF0A0A0C)),
          Expanded(child: _buildTile(engine, tiles[1], isCompact: false)),
        ],
      );
    }

    if (tiles.length == 3) {
      return Column(
        children: [
          Expanded(child: _buildTile(engine, tiles[0], isCompact: false)),
          Container(height: 2, color: const Color(0xFF0A0A0C)),
          Expanded(
            child: Row(
              children: [
                Expanded(child: _buildTile(engine, tiles[1], isCompact: true)),
                Container(width: 2, color: const Color(0xFF0A0A0C)),
                Expanded(child: _buildTile(engine, tiles[2], isCompact: true)),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildTile(engine, tiles[0], isCompact: true)),
              Container(width: 2, color: const Color(0xFF0A0A0C)),
              Expanded(child: _buildTile(engine, tiles[1], isCompact: true)),
            ],
          ),
        ),
        Container(height: 2, color: const Color(0xFF0A0A0C)),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildTile(engine, tiles[2], isCompact: true)),
              Container(width: 2, color: const Color(0xFF0A0A0C)),
              Expanded(child: _buildTile(engine, tiles[3], isCompact: true)),
            ],
          ),
        ),
      ],
    );
  }
}
