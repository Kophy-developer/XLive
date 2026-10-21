import 'package:flutter/material.dart';

import '../../core/widgets/user_avatar.dart';
import '../../features/gifts/gifts_repository.dart';
import '../../features/gifts/models/gift_models.dart';
import '../../core/network/api_friendly_messages.dart';

const _black = Color(0xFF0A0A0A);
const _muted = Color(0xFF8E8E93);
const _gradStart = Color(0xFF8A2DDC);
const _gradEnd = Color(0xFFE8487E);

class MyGiftsScreen extends StatefulWidget {
  const MyGiftsScreen({super.key});

  @override
  State<MyGiftsScreen> createState() => _MyGiftsScreenState();
}

class _MyGiftsScreenState extends State<MyGiftsScreen> {
  final _repo = GiftsRepository();
  ReceivedGiftsPage? _page;
  bool _loading = true;
  String? _error;
  int _tab = 0;

  bool get _sent => _tab == 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = _sent ? await _repo.sentGifts() : await _repo.receivedGifts();
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  void _switchTab(int tab) {
    if (_tab == tab) return;
    setState(() {
      _tab = tab;
      _page = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: _black,
        title: const Text('My Gifts', style: TextStyle(fontWeight: FontWeight.w800, color: _black)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Row(
              children: [
                _GiftTab(label: 'Received', active: _tab == 0, onTap: () => _switchTab(0)),
                const SizedBox(width: 8),
                _GiftTab(label: 'Sent', active: _tab == 1, onTap: () => _switchTab(1)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : _error != null
                      ? _GiftsMessage(icon: Icons.wifi_off_rounded, title: 'Something went wrong', subtitle: _error!, onRetry: _load)
                      : _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    final page = _page;
    final gifts = page?.gifts ?? const [];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
      children: [
        _SummaryCard(page: page, sent: _sent),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(_sent ? 'Recent sent' : 'Recent gifts', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black)),
        ),
        const SizedBox(height: 10),
        if (gifts.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: _GiftsMessage(
              icon: Icons.card_giftcard_rounded,
              title: _sent ? 'No gifts sent yet' : 'No gifts yet',
              subtitle: _sent
                  ? 'Gifts you send to creators will show up here.'
                  : 'Gifts you receive from your streams and posts will show up here.',
            ),
          )
        else
          for (final g in gifts) _GiftRow(gift: g, sent: _sent),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.page, this.sent = false});

  final ReceivedGiftsPage? page;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final totalValue = page?.totalValue ?? 0;
    final totalCash = page?.totalCash ?? 0;
    final totalCount = page?.totalCount ?? (page?.gifts.length ?? 0);
    final currency = page?.currency ?? 'USD';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_gradStart, _gradEnd],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
                child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(sent ? 'Total value sent' : 'Total gift value', style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Icon(Icons.diamond_rounded, color: Colors.white, size: 26),
              const SizedBox(width: 8),
              Text('$totalValue', style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900, height: 1)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            totalCash > 0 ? '≈ $currency ${totalCash.toStringAsFixed(2)}' : 'Diamonds earned',
            style: const TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(999)),
            child: Text(sent ? '$totalCount gifts sent' : '$totalCount gifts received', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _GiftRow extends StatelessWidget {
  const _GiftRow({required this.gift, this.sent = false});

  final ReceivedGift gift;
  final bool sent;

  @override
  Widget build(BuildContext context) {
    final icon = gift.iconUrl;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF6F6F6), borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFB300)]),
              ),
              clipBehavior: Clip.antiAlias,
              child: icon != null && icon.isNotEmpty
                  ? Image.network(icon, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22))
                  : const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(gift.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black))),
                      if (gift.quantity > 1)
                        Text('x${gift.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _muted)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (gift.senderName != null && gift.senderName!.isNotEmpty) ...[
                        UserAvatar(radius: 9, imageUrl: gift.senderAvatarUrl),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            gift.senderName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: _muted),
                          ),
                        ),
                      ] else
                        Expanded(child: Text(gift.context ?? (sent ? 'Gift sent' : 'Gift received'), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: _muted))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  children: [
                    const Icon(Icons.diamond_rounded, size: 14, color: _gradStart),
                    const SizedBox(width: 3),
                    Text('${gift.value}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _black)),
                  ],
                ),
                if (gift.createdAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(_relativeTime(gift.createdAt!), style: const TextStyle(fontSize: 11, color: _muted)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}/${time.year % 100}';
  }
}

class _GiftTab extends StatelessWidget {
  const _GiftTab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        decoration: BoxDecoration(
          gradient: active ? const LinearGradient(colors: [_gradStart, _gradEnd]) : null,
          color: active ? null : const Color(0xFFF1F1F4),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _muted,
          ),
        ),
      ),
    );
  }
}

class _GiftsMessage extends StatelessWidget {
  const _GiftsMessage({required this.icon, required this.title, required this.subtitle, this.onRetry});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_gradStart.withValues(alpha: 0.18), _gradEnd.withValues(alpha: 0.18)],
                ),
              ),
              child: Icon(icon, size: 38, color: _gradEnd),
            ),
            const SizedBox(height: 18),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: _muted, height: 1.45)),
            if (onRetry != null) ...[
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: onRetry,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _black,
                  side: const BorderSide(color: Color(0xFFE2E2E6)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
