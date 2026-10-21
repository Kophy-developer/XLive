import 'package:flutter/material.dart';

import '../core/session/auth_session.dart';
import 'navigation/create_options_sheet.dart';

enum MainNavItem { home, explore, chats, profile }

class MainBottomNav extends StatelessWidget {
  const MainBottomNav({super.key, required this.selected});

  final MainNavItem selected;

  static const _purple = Color(0xFF8A2DDC);
  static const _sky = Color(0xFF35D3FB);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSession.instance,
      builder: (context, _) {
        final unread = AuthSession.instance.unreadTotal;
        return SafeArea(
          top: false,
          child: Container(
            height: 74,
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0x1A0A0A0A)))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BottomNavItem(
                  icon: Icons.home_rounded,
                  label: 'Home',
                  active: selected == MainNavItem.home,
                  onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (r) => false),
                ),
                _BottomNavItem(
                  icon: Icons.search_rounded,
                  label: 'Explore',
                  active: selected == MainNavItem.explore,
                  onTap: () => Navigator.pushNamed(context, '/explore'),
                ),
                GestureDetector(
                  onTap: () => showCreateOptionsSheet(context),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, _sky]), borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.add, color: Colors.white),
                  ),
                ),
                _BottomNavItem(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Chats',
                  active: selected == MainNavItem.chats,
                  badge: unread > 0 ? (unread > 99 ? '99+' : '$unread') : null,
                  onTap: () => Navigator.pushNamed(context, '/chats'),
                ),
                _BottomNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  active: selected == MainNavItem.profile,
                  onTap: () {
                    if (ModalRoute.of(context)?.settings.name != '/profile/me') {
                      Navigator.pushNamedAndRemoveUntil(context, '/profile/me', (r) => false);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({required this.icon, required this.label, required this.active, required this.onTap, this.badge});

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final String? badge;

  static const _black = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context) {
    final inner = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 24, color: _black),
            if (badge != null)
              Positioned(
                right: -8,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 14),
                  decoration: BoxDecoration(color: const Color(0xFFE53935), borderRadius: BorderRadius.circular(999)),
                  child: Text(
                    badge!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: _black, fontWeight: active ? FontWeight.w700 : FontWeight.w500)),
      ],
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8), child: inner),
      ),
    );
  }
}
