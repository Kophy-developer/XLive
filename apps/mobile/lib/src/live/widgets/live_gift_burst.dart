import 'dart:async';

import 'package:flutter/material.dart';

import '../live_theme.dart';

class LiveGiftBurst {
  LiveGiftBurst({
    required this.id,
    required this.senderName,
    required this.giftLabel,
    this.quantity = 1,
    this.toHost = false,
  });

  final String id;
  final String senderName;
  final String giftLabel;
  final int quantity;
  final bool toHost;
  final DateTime createdAt = DateTime.now();
}

class LiveGiftBurstOverlay extends StatefulWidget {
  const LiveGiftBurstOverlay({super.key, required this.bursts});

  final List<LiveGiftBurst> bursts;

  @override
  State<LiveGiftBurstOverlay> createState() => _LiveGiftBurstOverlayState();
}

class _LiveGiftBurstOverlayState extends State<LiveGiftBurstOverlay> with SingleTickerProviderStateMixin {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final active = widget.bursts.where((b) => now.difference(b.createdAt) < const Duration(seconds: 3)).toList();
    if (active.isEmpty) return const SizedBox.shrink();

    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: active.map((b) {
            final t = now.difference(b.createdAt).inMilliseconds / 3000.0;
            final scale = 0.85 + (1 - t) * 0.25;
            final opacity = (1 - t).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: scale,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [LiveTheme.purple, LiveTheme.sky]),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: LiveTheme.purple.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 2)],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 36),
                      const SizedBox(height: 6),
                      Text(
                        b.senderName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text(
                        b.toHost
                            ? 'sent ${b.giftLabel}${b.quantity > 1 ? ' x${b.quantity}' : ''} to you'
                            : 'sent ${b.giftLabel}${b.quantity > 1 ? ' x${b.quantity}' : ''}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
