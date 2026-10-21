import 'package:flutter/material.dart';

import '../../core/feed/home_feed_refresh.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _pink = Color(0xFFEC4899);
const _black = Color(0xFF0A0A0A);

Future<void> showCreateOptionsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => const _CreateOptionsSheet(),
  );
}

class _CreateOptionsSheet extends StatelessWidget {
  const _CreateOptionsSheet();

  Future<void> _go(BuildContext context, String route, {Object? arguments}) async {
    Navigator.pop(context);
    final result = await Navigator.pushNamed(context, route, arguments: arguments);
    if (result == true) HomeFeedRefresh.instance.request();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.paddingOf(context).bottom + 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 32, offset: const Offset(0, 12)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(color: const Color(0xFFE5E5EA), borderRadius: BorderRadius.circular(999)),
              ),
              const Text('Create', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 6),
              const Text(
                'Share a post, mint a collectible, or go live',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B6B72)),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _CreateOptionCard(
                      title: 'Upload media',
                      subtitle: 'Post a photo or video',
                      icon: Icons.add_photo_alternate_rounded,
                      gradient: const [_purple, _sky],
                      onTap: () => _go(context, '/profile/creator/create-clip'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _CreateOptionCard(
                      title: 'Go live',
                      subtitle: 'Start a live stream',
                      icon: Icons.sensors_rounded,
                      gradient: const [_pink, _purple],
                      onTap: () => _go(context, '/live/setup'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFFF7F7F8),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  onTap: () => _go(context, '/profile/creator/create-clip', arguments: 1),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(colors: [_purple, _pink]),
                            borderRadius: BorderRadius.all(Radius.circular(14)),
                          ),
                          child: const Icon(Icons.auto_awesome_mosaic_rounded, color: Colors.white, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Collectible clip', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _black)),
                              SizedBox(height: 4),
                              Text(
                                'Limited editions · owners & earnings',
                                style: TextStyle(fontSize: 12, color: Color(0xFF6B6B72), height: 1.3),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B6B72)),
                      ],
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

class _CreateOptionCard extends StatelessWidget {
  const _CreateOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F7F8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 26),
              ),
              const SizedBox(height: 14),
              Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 4),
              Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B6B72), height: 1.3)),
            ],
          ),
        ),
      ),
    );
  }
}
