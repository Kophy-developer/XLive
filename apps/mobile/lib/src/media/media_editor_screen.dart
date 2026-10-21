import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

import 'media_composer.dart';
import 'media_editor_models.dart';
import 'freeform_image_crop.dart';
import 'media_picker_utils.dart';

const _bg = Color(0xFF0A0A0A);
const _panel = Color(0xFF1C1C1E);
const _track = Color(0xFF2A2A2E);
const _purple = Color(0xFF8A3FFC);
const _muted = Color(0xFF9E9E9E);

class MediaEditorScreen extends StatefulWidget {
  const MediaEditorScreen({super.key, required this.source});

  final PickedGalleryMedia source;

  @override
  State<MediaEditorScreen> createState() => _MediaEditorScreenState();
}

class _MediaEditorScreenState extends State<MediaEditorScreen> {
  VideoPlayerController? _player;
  VideoPlayerController? _addedVideoPlayer;
  AudioPlayer? _musicPlayer;
  AudioRecorder? _recorder;
  Timer? _recordTimer;

  late MediaEditProject _project;
  MediaEditorTool _tool = MediaEditorTool.edit;
  bool _ready = false;
  bool _exporting = false;
  bool _recording = false;
  int _recordSec = 0;
  RangeValues _trim = const RangeValues(0, 30);
  bool _previewPlaying = false;

  bool get _isVideo => widget.source.isVideo;
  bool get _showPlayButton => _isVideo || _project.hasAudioExtras;
  double get _clipLength => (_trim.end - _trim.start).clamp(0.5, 600.0);

  @override
  void initState() {
    super.initState();
    _project = MediaEditProject(
      sourcePath: widget.source.file.path,
      isVideo: widget.source.isVideo,
    );
    if (_isVideo) {
      _initVideo();
    } else {
      setState(() => _ready = true);
    }
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.file(File(widget.source.file.path));
    _player = controller;
    try {
      await controller.initialize();
      controller.addListener(_onVideoTick);
      await controller.setVolume(_project.muteOriginal ? 0 : _project.originalVolume);
      if (!mounted) return;
      final seconds = controller.value.duration.inMilliseconds / 1000.0;
      final maxS = seconds > 1 ? seconds : 30.0;
      final end = maxS < 30 ? maxS : 30.0;
      setState(() {
        _ready = true;
        _trim = RangeValues(0, end);
        _project = _project.copyWith(durationSec: maxS, trimEndSec: end);
      });
    } catch (_) {
      if (mounted) setState(() => _ready = true);
    }
  }

  void _onVideoTick() {
    final p = _player;
    if (p == null || !mounted) return;
    final playing = p.value.isPlaying;
    if (playing != _previewPlaying) {
      setState(() => _previewPlaying = playing);
    }
    if (!playing) return;
    final pos = p.value.position.inMilliseconds / 1000.0;
    if (pos >= _trim.end - 0.05) {
      _stopPreviewAtTrimStart();
    }
  }

  Future<void> _stopPreviewAtTrimStart() async {
    await _player?.pause();
    await _musicPlayer?.pause();
    await _player?.seekTo(Duration(milliseconds: (_trim.start * 1000).round()));
    if (mounted) setState(() => _previewPlaying = false);
  }

  Future<void> _applyMuteToPlayer() async {
    await _player?.setVolume(_project.muteOriginal ? 0 : _project.originalVolume);
  }

  Future<void> _prepareMusicClip() async {
    final music = _musicPlayer;
    final path = _project.musicPath;
    if (music == null || path == null || path.isEmpty) return;
    final start = _project.musicStartSec.clamp(0, _project.maxMusicStartSec);
    final end = start + _clipLength;
    await music.setVolume(_project.musicVolume);
    await music.setFilePath(path);
    try {
      await music.setClip(
        start: Duration(milliseconds: (start * 1000).round()),
        end: Duration(milliseconds: (end * 1000).round()),
      );
    } catch (_) {
      await music.seek(Duration(milliseconds: (start * 1000).round()));
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _player?.removeListener(_onVideoTick);
    _recorder?.dispose();
    _musicPlayer?.dispose();
    _addedVideoPlayer?.dispose();
    _player?.dispose();
    super.dispose();
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toInt().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  Future<void> _togglePlay() async {
    if (_isVideo) {
      final p = _player;
      if (p == null || !_ready) return;
      if (p.value.isPlaying) {
        await p.pause();
        await _musicPlayer?.pause();
        setState(() => _previewPlaying = false);
      } else {
        await _applyMuteToPlayer();
        await p.seekTo(Duration(milliseconds: (_trim.start * 1000).round()));
        if (_project.hasMusic) {
          await _prepareMusicClip();
          await _musicPlayer?.play();
        }
        await p.play();
        setState(() => _previewPlaying = true);
      }
      return;
    }
    if (!_project.hasAudioExtras) return;
    final music = _musicPlayer;
    if (music == null) return;
    if (music.playing) {
      await music.pause();
      setState(() => _previewPlaying = false);
    } else {
      await _prepareMusicClip();
      await music.play();
      setState(() => _previewPlaying = true);
      final clipMs = (_clipLength * 1000).round();
      Future<void>.delayed(Duration(milliseconds: clipMs), () async {
        if (!mounted) return;
        if (_musicPlayer?.playing == true) {
          await _musicPlayer?.pause();
          if (mounted) setState(() => _previewPlaying = false);
        }
      });
    }
  }

  Future<void> _toggleMute() async {
    final next = !_project.muteOriginal;
    setState(() => _project = _project.copyWith(muteOriginal: next));
    await _player?.setVolume(next ? 0 : _project.originalVolume);
  }

  Future<void> _pickMusic() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['mp3', 'm4a', 'aac', 'wav'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    await _musicPlayer?.dispose();
    final player = AudioPlayer();
    await player.setFilePath(path);
    final musicDur = player.duration?.inMilliseconds ?? 0;
    _musicPlayer = player;
    setState(() {
      _project = _project.copyWith(
        musicPath: path,
        musicTitle: result!.files.single.name,
        musicStartSec: 0,
        musicDurationSec: musicDur / 1000.0,
      );
      _tool = MediaEditorTool.music;
    });
  }

  Future<void> _pickAddedVideo() async {
    final picked = await pickGalleryMedia(context, kind: GalleryMediaKind.video);
    if (picked == null) return;
    await _addedVideoPlayer?.dispose();
    final controller = VideoPlayerController.file(File(picked.file.path));
    await controller.initialize();
    _addedVideoPlayer = controller;
    setState(() {
      _project = _project.copyWith(addedVideoPath: picked.file.path);
      _tool = MediaEditorTool.addVideo;
    });
  }

  Future<void> _toggleVoiceRecord() async {
    if (_recording) {
      _recordTimer?.cancel();
      final recorder = _recorder;
      _recorder = null;
      setState(() => _recording = false);
      final path = recorder == null ? null : await recorder.stop();
      await recorder?.dispose();
      if (path != null && path.isNotEmpty) {
        setState(() => _project = _project.copyWith(voicePath: path));
      }
      return;
    }
    final recorder = AudioRecorder();
    final ok = await recorder.hasPermission();
    if (!ok) {
      await recorder.dispose();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Microphone access required')));
      }
      return;
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _recorder = recorder;
    _recordSec = 0;
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordSec++);
    });
    setState(() => _recording = true);
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      await _player?.pause();
      await _musicPlayer?.pause();
      final project = _project.copyWith(trimStartSec: _trim.start, trimEndSec: _trim.end);
      final path = await MediaComposer.export(project);
      if (!mounted) return;
      Navigator.pop(context, EditedMediaResult(path: path, isVideo: project.resultIsVideo));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  double get _cropRatio {
    return switch (_project.cropAspect) {
      MediaCropAspect.square => 1,
      MediaCropAspect.portrait => 4 / 5,
      MediaCropAspect.landscape => 16 / 9,
      MediaCropAspect.original => _isVideo && _player != null && _player!.value.isInitialized
          ? _player!.value.aspectRatio
          : 9 / 16,
    };
  }

  Widget _preview() {
    final filter = _project.filter.matrix;
    Widget child;
    if (_isVideo && _player != null && _player!.value.isInitialized) {
      child = FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _player!.value.size.width,
          height: _player!.value.size.height,
          child: VideoPlayer(_player!),
        ),
      );
    } else {
      child = Image.file(File(_project.sourcePath), fit: BoxFit.cover, key: ValueKey(_project.sourcePath));
    }
    if (filter != null && _project.filterId != 'none') {
      child = ColorFiltered(colorFilter: ColorFilter.matrix(filter), child: child);
    }

    final playing = _previewPlaying ||
        (_isVideo ? (_player?.value.isPlaying == true) : (_musicPlayer?.playing == true));

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Colors.black, child: Center(child: AspectRatio(aspectRatio: _cropRatio, child: ClipRect(child: child)))),
        if (_project.hasAddedVideo && _addedVideoPlayer != null && _addedVideoPlayer!.value.isInitialized)
          Positioned(
            right: 12,
            bottom: 12,
            width: 96,
            height: 140,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: VideoPlayer(_addedVideoPlayer!),
            ),
          ),
        if (_showPlayButton)
          Center(
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _togglePlay,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tools = <MediaEditorTool>[
      MediaEditorTool.edit,
      MediaEditorTool.music,
      MediaEditorTool.voice,
      if (!_isVideo) MediaEditorTool.addVideo,
      MediaEditorTool.filter,
    ];
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _exporting ? null : () => Navigator.pop(context),
        ),
        title: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: _exporting ? null : _export,
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _bg,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: _exporting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Done', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: _ready ? _preview() : const Center(child: CircularProgressIndicator(color: Colors.white54)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_isVideo)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Trim ${_fmt(_trim.start)} – ${_fmt(_trim.end)}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      TextButton(
                        onPressed: _toggleMute,
                        child: Text(_project.muteOriginal ? 'Unmute' : 'Mute', style: const TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: _trim,
                    min: 0,
                    max: _project.durationSec <= 0 ? 1 : _project.durationSec,
                    activeColor: _purple,
                    inactiveColor: _track,
                    onChanged: (v) {
                      if (v.end - v.start < 1) return;
                      setState(() {
                        _trim = v;
                        final maxStart = _project.musicDurationSec <= 0
                            ? 0.0
                            : (_project.musicDurationSec - (v.end - v.start)).clamp(0.0, _project.musicDurationSec);
                        final musicStart = _project.musicStartSec.clamp(0.0, maxStart);
                        _project = _project.copyWith(
                          trimStartSec: v.start,
                          trimEndSec: v.end,
                          musicStartSec: musicStart,
                        );
                      });
                      _player?.seekTo(Duration(milliseconds: (v.start * 1000).round()));
                    },
                  ),
                ],
              ),
            ),
          _trackPanel(),
          _toolPanel(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: tools.map((t) => _toolButton(t)).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _trackRow(
            _isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
            _isVideo ? 'Main video' : 'Photo',
            _isVideo ? _fmt(_trim.end - _trim.start) : 'Ready',
          ),
          if (_project.hasMusic) _trackRow(Icons.music_note_rounded, _project.musicTitle ?? 'Music', 'Added'),
          if (_project.hasVoice) _trackRow(Icons.mic_rounded, 'Voice recording', _recording ? '${_recordSec}s' : 'Added'),
          if (_project.hasAddedVideo) _trackRow(Icons.movie_rounded, 'Added video', 'Added'),
        ],
      ),
    );
  }

  Widget _trackRow(IconData icon, String title, String meta) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: _purple, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600))),
          Text(meta, style: const TextStyle(color: _muted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _toolPanel() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(14)),
      child: switch (_tool) {
        MediaEditorTool.edit => _editPanel(),
        MediaEditorTool.music => _musicPanel(),
        MediaEditorTool.voice => _voicePanel(),
        MediaEditorTool.filter => _filterPanel(),
        MediaEditorTool.addVideo => _addVideoPanel(),
      },
    );
  }

  Widget _editPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_isVideo ? 'Crop & trim' : 'Crop', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        if (!_isVideo) ...[
          FilledButton.icon(
            onPressed: () async {
              final cropped = await openFreeformImageCrop(context, _project.sourcePath);
              if (cropped == null || !mounted) return;
              setState(() {
                _project = _project.copyWith(
                  sourcePath: cropped,
                  cropAspect: MediaCropAspect.original,
                );
              });
            },
            icon: const Icon(Icons.crop_free_rounded),
            label: const Text('Free crop'),
            style: FilledButton.styleFrom(backgroundColor: _purple),
          ),
          const SizedBox(height: 12),
          Text('Quick ratios', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          const SizedBox(height: 8),
        ],
        Wrap(
          spacing: 8,
          children: MediaCropAspect.values.map((a) {
            final label = switch (a) {
              MediaCropAspect.original => 'Original',
              MediaCropAspect.square => '1:1',
              MediaCropAspect.portrait => '4:5',
              MediaCropAspect.landscape => '16:9',
            };
            final on = _project.cropAspect == a;
            return ChoiceChip(
              label: Text(label),
              selected: on,
              onSelected: (_) => setState(() => _project = _project.copyWith(cropAspect: a)),
              selectedColor: _purple,
              labelStyle: TextStyle(color: on ? Colors.white : _muted, fontWeight: FontWeight.w600),
            );
          }).toList(),
        ),
        if (_isVideo) ...[
          const SizedBox(height: 8),
          Text('Use the trim slider above to cut the clip.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        ],
      ],
    );
  }

  Widget _musicPanel() {
    final maxStart = _project.maxMusicStartSec;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _pickMusic,
                icon: const Icon(Icons.library_music_rounded),
                label: Text(_project.hasMusic ? 'Change music' : 'Add music'),
                style: FilledButton.styleFrom(backgroundColor: _purple),
              ),
            ),
            if (_project.hasMusic) ...[
              const SizedBox(width: 8),
              IconButton(
                onPressed: () async {
                  await _musicPlayer?.stop();
                  await _musicPlayer?.dispose();
                  _musicPlayer = null;
                  setState(() => _project = _project.copyWith(clearMusic: true));
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              ),
            ],
          ],
        ),
        if (_project.hasMusic) ...[
          const SizedBox(height: 12),
          Text(
            'Music segment for ${_fmt(_clipLength)} video',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
          if (maxStart > 0.05) ...[
            Slider(
              value: _project.musicStartSec.clamp(0, maxStart),
              min: 0,
              max: maxStart,
              activeColor: _purple,
              onChanged: (v) {
                setState(() => _project = _project.copyWith(musicStartSec: v));
              },
            ),
            Text(
              'Starts at ${_fmt(_project.musicStartSec)} · ends ${_fmt(_project.musicStartSec + _clipLength)}',
              style: const TextStyle(color: _muted, fontSize: 12),
            ),
          ] else
            Text(
              'Song is shorter than or equal to the clip — full track will be used.',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          const SizedBox(height: 8),
          Text('Music volume', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          Slider(
            value: _project.musicVolume,
            activeColor: _purple,
            onChanged: (v) async {
              setState(() => _project = _project.copyWith(musicVolume: v));
              await _musicPlayer?.setVolume(v);
            },
          ),
        ],
      ],
    );
  }

  Widget _voicePanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: _toggleVoiceRecord,
          icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded),
          label: Text(_recording ? 'Stop (${_recordSec}s)' : 'Record voiceover'),
          style: FilledButton.styleFrom(backgroundColor: _recording ? Colors.redAccent : _purple),
        ),
        if (_project.hasVoice) ...[
          const SizedBox(height: 12),
          Text('Voice volume', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          Slider(
            value: _project.voiceVolume,
            activeColor: _purple,
            onChanged: (v) => setState(() => _project = _project.copyWith(voiceVolume: v)),
          ),
          TextButton(
            onPressed: () => setState(() => _project = _project.copyWith(clearVoice: true)),
            child: const Text('Remove voiceover', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ],
    );
  }

  Widget _filterPanel() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: mediaFilterPresets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = mediaFilterPresets[i];
          final on = _project.filterId == f.id;
          return ChoiceChip(
            label: Text(f.label),
            selected: on,
            onSelected: (_) => setState(() => _project = _project.copyWith(filterId: f.id)),
            selectedColor: _purple,
            labelStyle: TextStyle(color: on ? Colors.white : _muted, fontWeight: FontWeight.w600),
          );
        },
      ),
    );
  }

  Widget _addVideoPanel() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FilledButton.icon(
          onPressed: _pickAddedVideo,
          icon: const Icon(Icons.video_library_rounded),
          label: Text(_project.hasAddedVideo ? 'Change video' : 'Add video'),
          style: FilledButton.styleFrom(backgroundColor: _purple),
        ),
        if (_project.hasAddedVideo)
          TextButton(
            onPressed: () {
              _addedVideoPlayer?.dispose();
              _addedVideoPlayer = null;
              setState(() => _project = _project.copyWith(clearAddedVideo: true));
            },
            child: const Text('Remove video', style: TextStyle(color: Colors.redAccent)),
          ),
      ],
    );
  }

  Widget _toolButton(MediaEditorTool tool) {
    final on = _tool == tool;
    final icon = switch (tool) {
      MediaEditorTool.edit => Icons.crop_rounded,
      MediaEditorTool.music => Icons.music_note_rounded,
      MediaEditorTool.voice => Icons.mic_rounded,
      MediaEditorTool.filter => Icons.auto_awesome_rounded,
      MediaEditorTool.addVideo => Icons.movie_rounded,
    };
    final label = switch (tool) {
      MediaEditorTool.edit => 'Edit',
      MediaEditorTool.music => 'Music',
      MediaEditorTool.voice => 'Voice',
      MediaEditorTool.filter => 'Filter',
      MediaEditorTool.addVideo => 'Video',
    };
    return InkWell(
      onTap: () => setState(() => _tool = tool),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: on ? _purple : Colors.white70, size: 24),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: on ? Colors.white : _muted, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

Future<EditedMediaResult?> openMediaEditor(BuildContext context, PickedGalleryMedia source) {
  return Navigator.push<EditedMediaResult>(
    context,
    MaterialPageRoute(builder: (_) => MediaEditorScreen(source: source)),
  );
}
