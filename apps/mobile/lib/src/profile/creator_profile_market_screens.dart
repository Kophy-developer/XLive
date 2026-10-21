import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../app_bottom_nav.dart';
import 'user_profile_preview_screens.dart';

const _black = Color(0xFF0A0A0A);

class CreatorProfileScreen extends StatelessWidget {
  const CreatorProfileScreen({super.key, this.isRootTab = false});

  final bool isRootTab;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSession.instance,
      builder: (context, _) {
        final userId = AuthSession.instance.user?.id;
        if (userId == null || userId.isEmpty) {
          return Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              surfaceTintColor: Colors.transparent,
              automaticallyImplyLeading: !isRootTab,
              leading: isRootTab
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
              title: const Text('Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
            ),
            bottomNavigationBar: isRootTab ? const MainBottomNav(selected: MainNavItem.profile) : null,
            body: const Center(child: Text('Sign in to view your profile.')),
          );
        }
        return OtherUserProfileScreen(
          args: OtherUserProfileArgs(userId: userId, isOwnProfile: true, isRootTab: isRootTab),
        );
      },
    );
  }
}
