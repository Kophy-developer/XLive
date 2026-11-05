import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/session/auth_session.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/users/models/user_models.dart';
import '../legal/legal_report_screens.dart';

class ProfileMainScreen extends StatelessWidget {
  const ProfileMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSession.instance,
      builder: (context, _) {
        final user = AuthSession.instance.user;
        final displayName = user?.effectiveDisplayName ?? 'Your profile';
        final username = user?.username == null ? '@username' : '@${user!.username}';
        final avatarUrl = user?.avatarUrl;
        final showStudio = AuthSession.instance.creatorMode;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A0A0A), size: 20),
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushNamedAndRemoveUntil(context, '/profile/me', (r) => false);
                }
              },
            ),
            centerTitle: true,
            title: const Text('Settings', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF0A0A0A))),
          ),
          body: SafeArea(
            top: false,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const SizedBox(height: 8),
                UserAvatar(radius: 48, imageUrl: avatarUrl),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF0A0A0A)),
                ),
                const SizedBox(height: 4),
                Text(
                  username,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 24),
                _ProfileMenuCard(
                  children: [
                    _ProfileTile(
                      icon: Icons.person_outline_rounded,
                      label: 'Personal Information',
                      onTap: () async {
                        final saved = await Navigator.push<bool>(context, MaterialPageRoute<bool>(builder: (_) => const EditProfileScreen()));
                        if (!context.mounted || saved != true) return;
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved')));
                      },
                    ),
                    _ProfileTile(icon: Icons.account_balance_wallet_outlined, label: 'Xlive Wallet', onTap: () => Navigator.pushNamed(context, '/wallet/xlive')),
                    _ProfileTile(icon: Icons.card_giftcard_rounded, label: 'My Gifts', onTap: () => Navigator.pushNamed(context, '/profile/gifts')),
                    _ProfileTile(icon: Icons.bookmark_border_rounded, label: 'Saved', onTap: () => Navigator.pushNamed(context, '/profile/saved')),
                    _ProfileTile(icon: Icons.notifications_none_rounded, label: 'Notifications', onTap: () => Navigator.pushNamed(context, '/profile/notifications')),
                    _ProfileTile(
                      icon: Icons.inbox_outlined,
                      label: 'Activity inbox',
                      badge: AuthSession.instance.notificationUnread > 0
                          ? (AuthSession.instance.notificationUnread > 99
                              ? '99+'
                              : '${AuthSession.instance.notificationUnread}')
                          : null,
                      onTap: () => Navigator.pushNamed(context, '/integration/push-inbox'),
                    ),
                    _ProfileTile(icon: Icons.tune_rounded, label: 'General Preference', onTap: () => Navigator.pushNamed(context, '/profile/general-preference')),
                    _ProfileTile(icon: Icons.block_rounded, label: 'Blocked accounts', onTap: () => Navigator.pushNamed(context, '/social/blocked')),
                    _ProfileTile(icon: Icons.live_tv_rounded, label: 'Live invites', onTap: () => Navigator.pushNamed(context, '/social/stream-invites')),
                    _ProfileTile(icon: Icons.tag_rounded, label: 'Hashtags', onTap: () => Navigator.pushNamed(context, '/social/hashtags')),
                    _ProfileTile(icon: Icons.lock_outline_rounded, label: 'Security', onTap: () => Navigator.pushNamed(context, '/profile/security')),
                  ],
                ),
                const SizedBox(height: 20),
                _CreatorModeToggle(
                  enabled: showStudio,
                  onChanged: (v) => AuthSession.instance.setCreatorMode(v),
                ),
                if (showStudio) ...[
                  const SizedBox(height: 20),
                  _ProfileSectionLabel('Studio'),
                  const SizedBox(height: 8),
                  _ProfileMenuCard(
                    children: [
                      _ProfileTile(icon: Icons.dashboard_customize_rounded, label: 'Creator Tools', onTap: () => Navigator.pushNamed(context, '/profile/creator/tools')),
                      _ProfileTile(icon: Icons.movie_filter_outlined, label: 'Create Clip', onTap: () => Navigator.pushNamed(context, '/profile/creator/create-clip')),
                      _ProfileTile(icon: Icons.auto_awesome_mosaic_rounded, label: 'My Created Clips', onTap: () => Navigator.pushNamed(context, '/profile/creator/created-clips')),
                      _ProfileTile(icon: Icons.cut_rounded, label: 'Edit Clips', onTap: () => Navigator.pushNamed(context, '/profile/creator/edit-clip')),
                      _ProfileTile(icon: Icons.workspace_premium_rounded, label: 'My Subscription', onTap: () => Navigator.pushNamed(context, '/profile/creator/subscription')),
                      _ProfileTile(icon: Icons.workspace_premium_outlined, label: 'Subscription plan', onTap: () => Navigator.pushNamed(context, '/profile/creator/subscription-plan')),
                      _ProfileTile(icon: Icons.storefront_outlined, label: 'Clip marketplace', onTap: () => Navigator.pushNamed(context, '/integration/clip-marketplace')),
                    ],
                  ),
                ],
                const SizedBox(height: 20),
                _ProfileSectionLabel('More'),
                const SizedBox(height: 8),
                _ProfileMenuCard(
                  children: [
                    _ProfileTile(icon: Icons.flag_outlined, label: 'Report Issue', onTap: () => Navigator.pushNamed(context, '/legal/report-issue')),
                    _ProfileTile(icon: Icons.description_outlined, label: 'Term of User', onTap: () => showTermsOfUseSheet(context)),
                    _ProfileTile(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', onTap: () => showPrivacyPolicySheet(context)),
                    _ProfileTile(icon: Icons.article_outlined, label: 'Community Guidelines', onTap: () => showCommunityGuidelinesSheet(context)),
                    _ProfileTile(
                      icon: Icons.delete_outline_rounded,
                      label: 'Delete Account',
                      destructive: true,
                      onTap: () async {
                        await showDialog<void>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete account'),
                            content: const Text(
                              'Account deletion isn’t available in the app yet. Contact support if you need help closing your account.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
                            ],
                          ),
                        );
                      },
                    ),
                    _ProfileTile(
                      icon: Icons.logout_rounded,
                      label: 'Log out',
                      destructive: true,
                      onTap: () async {
                        await AuthSession.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushNamedAndRemoveUntil(context, '/auth/sign-in', (r) => false);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CreatorModeToggle extends StatelessWidget {
  const _CreatorModeToggle({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: enabled
            ? const LinearGradient(colors: [Color(0xFF8A2DDC), Color(0xFFE8487E)])
            : null,
        color: enabled ? null : const Color(0xFFF6F6F6),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: enabled ? Colors.white.withValues(alpha: 0.18) : Colors.white,
            ),
            child: Icon(Icons.auto_awesome_rounded, size: 22, color: enabled ? Colors.white : const Color(0xFF8A2DDC)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Creator mode',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: enabled ? Colors.white : const Color(0xFF0A0A0A)),
                ),
                const SizedBox(height: 2),
                Text(
                  enabled ? 'Creator tools and metrics are visible' : 'Switch on to access creator tools',
                  style: TextStyle(fontSize: 12.5, color: enabled ? Colors.white70 : Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: enabled,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.white.withValues(alpha: 0.45),
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
      ),
    );
  }
}

class _ProfileMenuCard extends StatelessWidget {
  const _ProfileMenuCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: Colors.grey.shade300),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.badge,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? const Color(0xFFE53935) : const Color(0xFF0A0A0A);
    final iconColor = destructive ? const Color(0xFFE53935) : Colors.grey.shade600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 22, color: iconColor),
              const SizedBox(width: 14),
              Expanded(child: Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: color))),
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A2DDC),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge!,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _purple = Color(0xFF8A2DDC);
  static const int _nameMax = 20;

  final _nameCtrl = TextEditingController();
  final _aboutCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  bool _saving = false;
  bool _uploadingAvatar = false;
  String? _avatarUrl;

  String _gender = 'Not set';
  String _languageChoice = 'English';

  @override
  void initState() {
    super.initState();
    _applyUser(AuthSession.instance.user);
    _refreshProfile();
  }

  Future<void> _refreshProfile() async {
    try {
      await AuthSession.instance.refreshProfile();
      if (!mounted) return;
      setState(() => _applyUser(AuthSession.instance.user));
    } catch (_) {}
  }

  void _applyUser(XLiveUser? user) {
    _nameCtrl.text = user?.displayName ?? user?.effectiveDisplayName ?? '';
    _aboutCtrl.text = user?.bio ?? '';
    _usernameCtrl.text = user?.username ?? '';
    _avatarUrl = user?.avatarUrl;
    _gender = mapGenderFromApi(user?.gender);
    _languageChoice = user?.language == 'en' ? 'English' : 'English';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _aboutCtrl.dispose();
    _usernameCtrl.dispose();
    super.dispose();
  }

  void _showGenderSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String temp = _gender;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _SheetShell(
              title: 'Gender',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetRadioRow(label: 'Female', selected: temp == 'Female', onTap: () => setModalState(() => temp = 'Female')),
                  const SizedBox(height: 4),
                  _SheetRadioRow(label: 'Male', selected: temp == 'Male', onTap: () => setModalState(() => temp = 'Male')),
                  const SizedBox(height: 4),
                  _SheetRadioRow(label: 'Not set', selected: temp == 'Not set', onTap: () => setModalState(() => temp = 'Not set')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _gender = temp);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Set', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLanguagesSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String temp = _languageChoice;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _SheetShell(
              title: 'My Languages',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SheetRadioRow(label: 'English', selected: temp == 'English', onTap: () => setModalState(() => temp = 'English')),
                  const SizedBox(height: 4),
                  _SheetRadioRow(label: 'Other Languages', selected: temp == 'Other Languages', onTap: () => setModalState(() => temp = 'Other Languages')),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () {
                        setState(() => _languageChoice = temp);
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _pickAvatar() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 85);
    if (picked == null) return;
    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final user = await AuthSession.instance.uploadAvatar(bytes);
      if (!mounted) return;
      setState(() => _avatarUrl = user.avatarUrl);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF0A0A0A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Edit Profile', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0A0A0A))),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: SizedBox(
              width: 112,
              height: 112,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  UserAvatar(radius: 56, imageUrl: _avatarUrl),
                  if (_uploadingAvatar)
                    Positioned.fill(
                      child: ClipOval(
                        child: ColoredBox(
                          color: const Color(0x66000000),
                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: Colors.white,
                      shape: const CircleBorder(),
                      elevation: 2,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploadingAvatar ? null : _pickAvatar,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(Icons.camera_alt_rounded, size: 18, color: Colors.grey.shade700),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _nameCtrl,
                  maxLength: _nameMax,
                  buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                  decoration: InputDecoration(
                    labelText: 'Name',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _purple, width: 1.2)),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '${_nameCtrl.text.length}/$_nameMax',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Email', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 4),
          Text(
            AuthSession.instance.identifier ?? 'Account email',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _purple),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _aboutCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'About Me',
              hintText: 'Type few words about you',
              alignLabelWithHint: true,
              border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _purple, width: 1.2)),
            ),
          ),
          const SizedBox(height: 20),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Username', style: TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: _usernameCtrl,
            readOnly: true,
            decoration: InputDecoration(
              prefixText: 'Xlive.me/ ',
              prefixStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Color(0xFF0A0A0A)),
              border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
            ),
          ),
          const SizedBox(height: 20),
          _EditFieldRow(label: 'Gender', value: _gender, onTap: _showGenderSheet),
          const SizedBox(height: 4),
          Divider(height: 1, color: Colors.grey.shade300),
          const SizedBox(height: 4),
          _EditFieldRow(label: 'My languages', value: _languageChoice, onTap: _showLanguagesSheet),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await AuthSession.instance.saveProfile(
                          displayName: _nameCtrl.text.trim(),
                          bio: _aboutCtrl.text.trim(),
                          language: mapLanguageToApi(_languageChoice),
                          gender: mapGenderToApi(_gender),
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context, true);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              style: FilledButton.styleFrom(backgroundColor: _purple, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: Text(_saving ? 'Saving…' : 'Save', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EditFieldRow extends StatelessWidget {
  const _EditFieldRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Color(0xFF0A0A0A))),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 15, color: Colors.grey.shade800)),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 16),
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0A0A0A))),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetRadioRow extends StatelessWidget {
  const _SheetRadioRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const _purple = Color(0xFF8A2DDC);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
              SizedBox(
                width: 22,
                height: 22,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey.shade400, width: 2),
                        color: Colors.white,
                      ),
                    ),
                    if (selected)
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(shape: BoxShape.circle, color: _purple),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
