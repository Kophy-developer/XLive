import 'dart:async';

import 'package:flutter/material.dart';

import '../socket/xlive_socket_client.dart';

class ConnectionStatusPill extends StatefulWidget {
  const ConnectionStatusPill({super.key, this.darkBackground = true});

  final bool darkBackground;

  @override
  State<ConnectionStatusPill> createState() => _ConnectionStatusPillState();
}

class _ConnectionStatusPillState extends State<ConnectionStatusPill> with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  bool _wasDisconnected = false;
  bool _showingReconnected = false;
  Timer? _reconnectedTimer;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, -0.6), end: Offset.zero).animate(
      CurvedAnimation(parent: _anim, curve: Curves.easeOutBack),
    );

    XLiveSocketClient.instance.addListener(_onSocketState);
    if (!XLiveSocketClient.instance.isConnected) {
      _wasDisconnected = true;
      _anim.value = 1.0;
    }
  }

  @override
  void dispose() {
    _reconnectedTimer?.cancel();
    XLiveSocketClient.instance.removeListener(_onSocketState);
    _anim.dispose();
    super.dispose();
  }

  void _onSocketState() {
    if (!mounted) return;
    final isConnected = XLiveSocketClient.instance.isConnected;
    if (!isConnected) {
      _reconnectedTimer?.cancel();
      _wasDisconnected = true;
      _showingReconnected = false;
      _anim.forward();
      setState(() {});
    } else if (_wasDisconnected) {
      _showingReconnected = true;
      setState(() {});
      _reconnectedTimer?.cancel();
      _reconnectedTimer = Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        _anim.reverse().then((_) {
          if (mounted) {
            setState(() {
              _wasDisconnected = false;
              _showingReconnected = false;
            });
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_wasDisconnected && !_anim.isAnimating && _anim.value == 0) {
      return const SizedBox.shrink();
    }

    final isDark = widget.darkBackground;
    final pillBg = _showingReconnected
        ? const Color(0xE610B981)
        : (isDark ? const Color(0xCC1F1F1F) : const Color(0xE62A2A2A));

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: pillBg,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showingReconnected) ...[
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  const Text(
                    'Connected',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ] else ...[
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFF59E0B)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Connecting…',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
