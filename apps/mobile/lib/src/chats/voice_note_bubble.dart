import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import 'chat_theme.dart';

class VoiceNoteBubble extends StatefulWidget {
  const VoiceNoteBubble({
    super.key,
    required this.url,
    required this.mine,
    this.timeLabel,
    this.edited = false,
    this.showReadReceipt = false,
  });

  final String url;
  final bool mine;
  final String? timeLabel;
  final bool edited;
  final bool showReadReceipt;

  @override
  State<VoiceNoteBubble> createState() => _VoiceNoteBubbleState();
}

class _VoiceNoteBubbleState extends State<VoiceNoteBubble> {
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  bool _playing = false;
  bool _loading = false;
  bool _dragging = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _dragProgress = 0;
  late final List<double> _bars;

  Color get _fg => widget.mine ? Colors.white : ChatTheme.black;
  Color get _played => widget.mine ? Colors.white : ChatTheme.purple;
  Color get _unplayed => widget.mine ? Colors.white.withValues(alpha: 0.38) : const Color(0xFFB8B8C0);

  @override
  void initState() {
    super.initState();
    _bars = _waveformFromSeed(widget.url.hashCode);
  }

  List<double> _waveformFromSeed(int seed) {
    final rng = math.Random(seed);
    const count = 36;
    return List<double>.generate(count, (i) {
      final wave = 0.35 + 0.45 * math.sin(i * 0.55) * math.sin(i * 0.17 + 1.2);
      final jitter = 0.2 + rng.nextDouble() * 0.8;
      return (wave * jitter).clamp(0.18, 1.0);
    });
  }

  Future<void> _ensurePlayer() async {
    if (_player != null) return;
    final player = AudioPlayer();
    _player = player;
    _stateSub = player.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.processingState == ProcessingState.completed) {
        player.pause();
        player.seek(Duration.zero);
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
        return;
      }
      setState(() {
        _playing = state.playing;
        _loading = state.processingState == ProcessingState.loading ||
            state.processingState == ProcessingState.buffering;
      });
    });
    _posSub = player.positionStream.listen((p) {
      if (!mounted || _dragging) return;
      setState(() => _position = p);
    });
    _durSub = player.durationStream.listen((d) {
      if (mounted && d != null) setState(() => _duration = d);
    });
    try {
      await player.setUrl(widget.url);
    } catch (_) {}
  }

  Future<void> _toggle() async {
    await _ensurePlayer();
    final player = _player;
    if (player == null) return;
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  Future<void> _seekToProgress(double progress) async {
    await _ensurePlayer();
    final player = _player;
    if (player == null) return;
    final total = _duration.inMilliseconds;
    if (total <= 0) return;
    final target = Duration(milliseconds: (total * progress.clamp(0.0, 1.0)).round());
    await player.seek(target);
    if (mounted) setState(() => _position = target);
  }

  @override
  void dispose() {
    _stateSub?.cancel();
    _posSub?.cancel();
    _durSub?.cancel();
    _player?.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration.inMilliseconds;
    final liveProgress = total > 0 ? (_position.inMilliseconds / total).clamp(0.0, 1.0) : 0.0;
    final progress = _dragging ? _dragProgress : liveProgress;
    final labelDuration = _dragging && total > 0
        ? Duration(milliseconds: (total * progress).round())
        : (_playing || _position > Duration.zero || _dragging ? _position : _duration);
    final label = _duration > Duration.zero || _dragging ? _fmt(labelDuration) : '';

    return Container(
      width: 248,
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: widget.mine ? ChatTheme.purple : Colors.white,
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: widget.mine ? const Radius.circular(6) : null,
          bottomLeft: widget.mine ? null : const Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: widget.mine ? 0.12 : 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.mine ? Colors.white.withValues(alpha: 0.2) : ChatTheme.purple.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: _fg),
                    )
                  : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: _fg, size: 24),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) async {
                        final p = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        setState(() {
                          _dragging = true;
                          _dragProgress = p;
                        });
                        await _seekToProgress(p);
                        if (mounted) setState(() => _dragging = false);
                      },
                      onHorizontalDragStart: (details) {
                        final p = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        setState(() {
                          _dragging = true;
                          _dragProgress = p;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        final p = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                        setState(() => _dragProgress = p);
                      },
                      onHorizontalDragEnd: (_) async {
                        await _seekToProgress(_dragProgress);
                        if (mounted) setState(() => _dragging = false);
                      },
                      onHorizontalDragCancel: () {
                        if (mounted) setState(() => _dragging = false);
                      },
                      child: SizedBox(
                        height: 34,
                        child: CustomPaint(
                          painter: _WhatsAppWavePainter(
                            bars: _bars,
                            progress: progress,
                            played: _played,
                            unplayed: _unplayed,
                          ),
                          size: Size(constraints.maxWidth, 34),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _fg.withValues(alpha: 0.82))),
                    const Spacer(),
                    if (widget.timeLabel != null && widget.timeLabel!.trim().isNotEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.edited) ...[
                            Text(
                              'edited',
                              style: TextStyle(
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                color: _fg.withValues(alpha: 0.65),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            widget.timeLabel!,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.15,
                              color: _fg.withValues(alpha: 0.72),
                            ),
                          ),
                          if (widget.showReadReceipt) ...[
                            const SizedBox(width: 3),
                            Icon(Icons.done_all_rounded, size: 14, color: _fg.withValues(alpha: 0.9)),
                          ],
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhatsAppWavePainter extends CustomPainter {
  _WhatsAppWavePainter({
    required this.bars,
    required this.progress,
    required this.played,
    required this.unplayed,
  });

  final List<double> bars;
  final double progress;
  final Color played;
  final Color unplayed;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;
    final barWidth = size.width / (bars.length * 1.85);
    final gap = barWidth * 0.85;
    final radius = Radius.circular(barWidth);
    final playedPaint = Paint()..color = played;
    final unplayedPaint = Paint()..color = unplayed;
    final threshold = progress * size.width;

    for (var i = 0; i < bars.length; i++) {
      final h = math.max(4.0, bars[i] * size.height);
      final x = i * (barWidth + gap);
      final y = (size.height - h) / 2;
      final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, barWidth, h), radius);
      final centerX = x + barWidth / 2;
      canvas.drawRRect(rect, centerX <= threshold ? playedPaint : unplayedPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhatsAppWavePainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.played != played ||
        oldDelegate.unplayed != unplayed ||
        oldDelegate.bars != bars;
  }
}



