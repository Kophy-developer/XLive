import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:video_player/video_player.dart';

import '../../core/feed/home_feed_refresh.dart';
import '../../core/network/api_friendly_messages.dart';
import '../../features/clips/clips_repository.dart';
import '../../features/videos/videos_repository.dart';
import '../media/media_editor_models.dart';
import '../media/media_editor_screen.dart';
import '../media/media_picker_utils.dart';

const _black = Color(0xFF0A0A0A);
const _grey = Color(0xFF8E8E93);
const _fieldBg = Color(0xFFF4F4F6);
const _purpleA = Color(0xFF8A3FFC);
const _pink = Color(0xFFEC4899);

LinearGradient get _brandGradient => const LinearGradient(colors: [_purpleA, _pink]);

class EditClipMediaPickerScreen extends StatefulWidget {
  const EditClipMediaPickerScreen({super.key});

  @override
  State<EditClipMediaPickerScreen> createState() => _EditClipMediaPickerScreenState();
}

class _EditClipMediaPickerScreenState extends State<EditClipMediaPickerScreen> {
  bool _picking = false;

  Future<void> _pick() async {
    setState(() => _picking = true);
    try {
      final picked = await pickGalleryMedia(context, kind: GalleryMediaKind.video, allowCamera: true);
      if (!mounted) return;
      if (picked == null) {
        setState(() => _picking = false);
        return;
      }
      final edited = await Navigator.push<EditedMediaResult>(
        context,
        MaterialPageRoute(builder: (_) => MediaEditorScreen(source: picked)),
      );
      if (!mounted || edited == null) {
        setState(() => _picking = false);
        return;
      }
      await Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(builder: (_) => EditClipScreen(file: XFile(edited.path))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _picking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Edit clip', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(28)),
                child: const Icon(Icons.movie_creation_outlined, color: Colors.white, size: 44),
              ),
              const SizedBox(height: 24),
              const Text('Pick a video to clip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 8),
              const Text(
                'Choose a video from your gallery, trim the part you want, then publish it as a clip.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: _grey, height: 1.4),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(14)),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _picking ? null : _pick,
                      borderRadius: BorderRadius.circular(14),
                      child: Center(
                        child: _picking
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Choose video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                      ),
                    ),
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

class EditClipScreen extends StatefulWidget {
  const EditClipScreen({super.key, required this.file});

  final XFile file;

  @override
  State<EditClipScreen> createState() => _EditClipScreenState();
}

class _EditClipScreenState extends State<EditClipScreen> {
  final _videosRepo = VideosRepository();
  final _clipsRepo = ClipsRepository();
  final _title = TextEditingController();
  final _price = TextEditingController();

  late String _filePath = widget.file.path;
  VideoPlayerController? _player;
  bool _playerReady = false;
  bool _playerFailed = false;
  double _maxSeconds = 180;
  RangeValues _range = const RangeValues(0, 30);
  bool _collectible = false;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _player?.dispose();
    _player = null;
    setState(() {
      _playerReady = false;
      _playerFailed = false;
    });
    final controller = VideoPlayerController.file(File(_filePath));
    _player = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      final seconds = controller.value.duration.inMilliseconds / 1000.0;
      final maxS = seconds > 1 ? seconds : 180.0;
      final end = maxS < 30 ? maxS : 30.0;
      setState(() {
        _playerReady = true;
        _maxSeconds = maxS;
        _range = RangeValues(0, end);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _playerFailed = true);
    }
  }

  Future<void> _openEditor() async {
    await _player?.pause();
    if (!mounted) return;
    final edited = await openMediaEditor(
      context,
      PickedGalleryMedia(file: XFile(_filePath), isVideo: true),
    );
    if (!mounted || edited == null) return;
    setState(() => _filePath = edited.path);
    await _initPlayer();
  }

  @override
  void dispose() {
    _title.dispose();
    _price.dispose();
    _player?.dispose();
    super.dispose();
  }

  String _fmt(double s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toInt().toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _togglePlay() {
    final p = _player;
    if (p == null || !_playerReady) return;
    if (p.value.isPlaying) {
      p.pause();
    } else {
      p.play();
    }
    setState(() {});
  }

  void _onRangeChanged(RangeValues v) {
    if (v.end - v.start < 1) return;
    setState(() => _range = v);
    _player?.seekTo(Duration(milliseconds: (v.start * 1000).round()));
  }

  Future<void> _publish() async {
    if (_title.text.trim().isEmpty) {
      _toast('Add a title for your clip');
      return;
    }
    setState(() => _publishing = true);
    try {
      final filename = uploadFilenameFor(PickedGalleryMedia(file: XFile(_filePath), isVideo: true));
      final uploaded = await _videosRepo.uploadVideoFile(
        _filePath,
        filename: filename,
        title: _title.text.trim(),
        fields: const {'soundCopyrightChecked': 'true'},
      );
      await _clipsRepo.createClip(
        sourceType: 'video',
        sourceId: uploaded.id,
        startMs: (_range.start * 1000).round(),
        endMs: (_range.end * 1000).round(),
        title: _title.text.trim(),
        price: _collectible ? int.tryParse(_price.text.trim()) : null,
        isCollectible: _collectible,
      );
      if (!mounted) return;
      _toast('Clip published');
      HomeFeedRefresh.instance.request();
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast(friendlyApiMessage(e));
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Edit clip', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
        actions: [
          TextButton(
            onPressed: _publishing ? null : _openEditor,
            child: const Text('Edit media', style: TextStyle(fontWeight: FontWeight.w700, color: _purpleA)),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + MediaQuery.paddingOf(context).bottom),
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: _playerReady && _player != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _player!.value.size.width,
                            height: _player!.value.size.height,
                            child: VideoPlayer(_player!),
                          ),
                        ),
                        Container(color: Colors.black26),
                        Center(
                          child: IconButton(
                            onPressed: _togglePlay,
                            icon: Icon(
                              _player!.value.isPlaying ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 56,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: _fieldBg,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_playerFailed ? Icons.videocam_off_rounded : Icons.play_circle_outline_rounded, size: 56, color: _grey),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _filePath.split(Platform.pathSeparator).last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _black),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _publishing ? null : _openEditor,
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Edit media', style: TextStyle(fontWeight: FontWeight.w700)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _purpleA,
                side: const BorderSide(color: _purpleA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Trim', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _black)),
              Text('${_fmt(_range.start)}  –  ${_fmt(_range.end)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _grey)),
            ],
          ),
          RangeSlider(
            values: _range,
            min: 0,
            max: _maxSeconds,
            divisions: _maxSeconds >= 1 ? _maxSeconds.round().clamp(1, 600) : null,
            activeColor: _purpleA,
            inactiveColor: _fieldBg,
            labels: RangeLabels(_fmt(_range.start), _fmt(_range.end)),
            onChanged: _onRangeChanged,
          ),
          const SizedBox(height: 12),
          const Text('TITLE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.4)),
          const SizedBox(height: 8),
          _input(_title, 'What happened in this clip?'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Collectible clip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black)),
                    const SizedBox(height: 4),
                    const Text('Sell this clip in the marketplace', style: TextStyle(fontSize: 13, color: _grey)),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _collectible,
                activeTrackColor: _purpleA,
                onChanged: (v) => setState(() => _collectible = v),
              ),
            ],
          ),
          if (_collectible) ...[
            const SizedBox(height: 12),
            const Text('PRICE (COINS)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _grey, letterSpacing: 0.4)),
            const SizedBox(height: 8),
            _input(_price, 'e.g. 5', keyboardType: TextInputType.number, suffixText: 'coins'),
          ],
          const SizedBox(height: 28),
          SizedBox(
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: _brandGradient, borderRadius: BorderRadius.circular(14)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _publishing ? null : _publish,
                  borderRadius: BorderRadius.circular(14),
                  child: Center(
                    child: _publishing
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Publish clip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _input(TextEditingController c, String hint, {int maxLines = 1, TextInputType? keyboardType, String? suffixText}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 15, color: _black),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _grey),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: _grey, fontWeight: FontWeight.w600),
        filled: true,
        fillColor: _fieldBg,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
