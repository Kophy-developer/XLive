import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../features/users/users_repository.dart';
import '../../features/notifications/notifications_repository.dart';
import '../../features/users/models/user_models.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _black = Color(0xFF0A0A0A);

enum KeywordFeedScope { forYou, following, friends }

class AddKeywordResult {
  const AddKeywordResult({required this.word, required this.scopes});

  final String word;
  final Set<KeywordFeedScope> scopes;
}

class FilteredKeywordEntry {
  FilteredKeywordEntry({required this.word, required this.scopes});

  final String word;
  final Set<KeywordFeedScope> scopes;

  String get filterFromLabel {
    const order = [KeywordFeedScope.forYou, KeywordFeedScope.following, KeywordFeedScope.friends];
    const map = {KeywordFeedScope.forYou: 'For You', KeywordFeedScope.following: 'Following', KeywordFeedScope.friends: 'Friends'};
    final parts = [for (final k in order) if (scopes.contains(k)) map[k]!];
    return parts.join(', ');
  }
}

String _quoteKeyword(String w) => '“${w.replaceAll('"', '')}”';

Future<bool?> showDeleteKeywordDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black45,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Delete Keyword',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black),
            ),
            const SizedBox(height: 12),
            Text(
              'Are you sure you want to permanently delete this Keyword?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  elevation: 0,
                ),
                child: const Text('Delete Keyword', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _black,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('No, cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SubpageScaffold extends StatelessWidget {
  const _SubpageScaffold({required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: body,
    );
  }
}

class ProfileNotificationsSettingsScreen extends StatefulWidget {
  const ProfileNotificationsSettingsScreen({super.key});

  @override
  State<ProfileNotificationsSettingsScreen> createState() => _ProfileNotificationsSettingsScreenState();
}

class _ProfileNotificationsSettingsScreenState extends State<ProfileNotificationsSettingsScreen> {
  final _notificationsRepo = NotificationsRepository();
  bool _liveStream = true;
  bool _pushConfigured = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = AuthSession.instance.settings;
    try {
      final configured = await _notificationsRepo.isPushConfigured();
      if (!mounted) return;
      setState(() {
        _pushConfigured = configured;
        _liveStream = settings?.notifyFriendsLive ?? true;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveStream = settings?.notifyFriendsLive ?? true;
        _loading = false;
      });
    }
  }

  Future<void> _saveLiveStream(bool value) async {
    setState(() => _liveStream = value);
    final current = AuthSession.instance.settings ?? const AppSettings();
    try {
      await AuthSession.instance.saveSettings(current.copyWith(notifyFriendsLive: value));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SubpageScaffold(
      title: 'Notifications',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        children: [
          if (!_pushConfigured)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Text(
                'Push notifications are not configured on the server yet.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
              ),
            ),
          _NotificationSwitchTile(
            title: 'Live Stream Notification',
            subtitle: 'Get notified when your friends are live',
            value: _liveStream,
            onChanged: _saveLiveStream,
          ),
        ],
      ),
    );
  }
}

class _NotificationSwitchTile extends StatelessWidget {
  const _NotificationSwitchTile({required this.title, required this.value, required this.onChanged, this.subtitle});

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)),
                ],
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.grey.shade400;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return _purple;
              return Colors.grey.shade300;
            }),
          ),
        ],
      ),
    );
  }
}

class GeneralPreferenceScreen extends StatefulWidget {
  const GeneralPreferenceScreen({super.key});

  @override
  State<GeneralPreferenceScreen> createState() => _GeneralPreferenceScreenState();
}

class _GeneralPreferenceScreenState extends State<GeneralPreferenceScreen> {
  bool _discoverability = true;
  bool _showAdult = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = AuthSession.instance.settings;
    if (settings != null) {
      setState(() {
        _discoverability = settings.discoverable;
        _showAdult = settings.showAdultContent;
        _loading = false;
      });
      return;
    }
    try {
      final loaded = await AuthSession.instance.settingsRepository.getSettings();
      if (!mounted) return;
      setState(() {
        _discoverability = loaded.discoverable;
        _showAdult = loaded.showAdultContent;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _patchSettings({bool? discoverable, bool? showAdultContent}) async {
    final current = AuthSession.instance.settings ?? AppSettings();
    final next = current.copyWith(
      discoverable: discoverable ?? _discoverability,
      showAdultContent: showAdultContent ?? _showAdult,
    );
    try {
      await AuthSession.instance.saveSettings(next);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SubpageScaffold(title: 'General Preference', body: Center(child: CircularProgressIndicator()));
    }
    return _SubpageScaffold(
      title: 'General Preference',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _PrefSwitchRow(
            title: 'Discoverability',
            subtitle: 'This allows you to stay invisible to searches, or getting invited.',
            value: _discoverability,
            onChanged: (v) {
              setState(() => _discoverability = v);
              _patchSettings(discoverable: v);
            },
          ),
          const SizedBox(height: 8),
          _PrefSwitchRow(
            title: 'Show 18+ Content',
            subtitle: 'Do not hide media that contains content suitable only for adults',
            value: _showAdult,
            onChanged: (v) {
              setState(() => _showAdult = v);
              _patchSettings(showAdultContent: v);
            },
          ),
          const SizedBox(height: 16),
          _PrefNavRow(
            title: 'Content Preferences',
            subtitle: 'You can Filter out keywords, you dont what to appear on your feed',
            onTap: () => Navigator.pushNamed(context, '/profile/content-preferences'),
          ),
          const SizedBox(height: 8),
          _PrefNavRow(
            title: 'Post',
            subtitle: 'Who can see my feed',
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const PostFeedVisibilityScreen())),
          ),
          const SizedBox(height: 8),
          _PrefNavRow(
            title: 'Blocked Accounts',
            onTap: () => Navigator.pushNamed(context, '/social/blocked'),
          ),
        ],
      ),
    );
  }
}

class _PrefSwitchRow extends StatelessWidget {
  const _PrefSwitchRow({required this.title, required this.subtitle, required this.value, required this.onChanged});

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35)),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Switch.adaptive(
            value: value,
            onChanged: onChanged,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return Colors.white;
              return Colors.grey.shade400;
            }),
            trackColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) return _purple;
              return Colors.grey.shade300;
            }),
          ),
        ),
      ],
    );
  }
}

class _PrefNavRow extends StatelessWidget {
  const _PrefNavRow({required this.title, required this.onTap, this.subtitle});

  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35)),
                    ],
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class ContentPreferencesScreen extends StatefulWidget {
  const ContentPreferencesScreen({super.key});

  @override
  State<ContentPreferencesScreen> createState() => _ContentPreferencesScreenState();
}

class _ContentPreferencesScreenState extends State<ContentPreferencesScreen> {
  final _settingsRepo = SettingsRepository();
  List<FilteredKeywordEntry> _keywords = const [];
  bool _loading = true;
  String? _error;

  static List<String> _scopesToTargets(Set<KeywordFeedScope> scopes) {
    final targets = <String>[];
    if (scopes.contains(KeywordFeedScope.forYou)) targets.add('for_you');
    if (scopes.contains(KeywordFeedScope.following) || scopes.contains(KeywordFeedScope.friends)) {
      targets.add('following');
    }
    return targets.isEmpty ? ['for_you'] : targets;
  }

  static Set<KeywordFeedScope> _targetsToScopes(List<String> targets) {
    final scopes = <KeywordFeedScope>{};
    for (final target in targets) {
      final value = target.toLowerCase();
      if (value.contains('for')) scopes.add(KeywordFeedScope.forYou);
      if (value.contains('follow') || value.contains('friend')) {
        scopes.add(KeywordFeedScope.following);
        scopes.add(KeywordFeedScope.friends);
      }
    }
    if (scopes.isEmpty) scopes.add(KeywordFeedScope.forYou);
    return scopes;
  }

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  Future<void> _loadFilters() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final filters = await _settingsRepo.listContentFilters();
      if (!mounted) return;
      setState(() {
        _keywords = filters
            .map((f) => FilteredKeywordEntry(word: f.keyword, scopes: _targetsToScopes(f.targets)))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _keywords = const [];
        _loading = false;
        _error = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _openAddKeyword() async {
    final result = await Navigator.push<AddKeywordResult?>(
      context,
      MaterialPageRoute<AddKeywordResult?>(builder: (_) => const AddKeywordScreen()),
    );
    if (!mounted || result == null || result.word.trim().isEmpty) return;
    try {
      await _settingsRepo.addContentFilter(
        keyword: result.word.trim(),
        targets: _scopesToTargets(result.scopes),
      );
      if (!mounted) return;
      await _loadFilters();
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _black,
        elevation: 4,
        margin: EdgeInsets.only(left: 48, right: 48, bottom: MediaQuery.paddingOf(context).bottom + 88),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        content: Text(
          'Filtered Keyword ${_quoteKeyword(result.word.trim())}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w400),
        ),
      ),
    );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _confirmRemove(int index) async {
    final ok = await showDeleteKeywordDialog(context);
    if (ok != true || !mounted) return;
    final keyword = _keywords[index].word;
    try {
      await _settingsRepo.removeContentFilter(keyword);
      if (!mounted) return;
      setState(() => _keywords.removeAt(index));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SubpageScaffold(title: 'Content Preferences', body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    if (_error != null && _keywords.isEmpty) {
      return _SubpageScaffold(
        title: 'Content Preferences',
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _loadFilters, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }
    if (_keywords.isEmpty) {
      return _SubpageScaffold(
        title: 'Content Preferences',
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(Icons.add, size: 36, color: Colors.grey.shade800),
              ),
              const SizedBox(height: 24),
              const Text(
                'Add a keyword',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _black),
              ),
              const SizedBox(height: 12),
              Text(
                'Make a group for whatever you’re into, Invite friends and post exclusion content.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade800, height: 1.45),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _openAddKeyword,
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    elevation: 0,
                  ),
                  child: const Text('Add keyword', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const Spacer(flex: 3),
            ],
          ),
        ),
      );
    }

    return _SubpageScaffold(
      title: 'Content Preferences',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'When you filter a keyword. you won’t see posts in your selected feeds that contain that word in any titles, descriptions, or stickers. Certain keywords can’t be filtered.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700, height: 1.45),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 0),
              itemCount: _keywords.length,
              separatorBuilder: (_, index) => Divider(height: 1, thickness: 1, color: Colors.grey.shade200, key: ValueKey('kw-div-$index')),
              itemBuilder: (_, i) {
                final e = _keywords[i];
                    return Material(
                  color: Colors.white,
                  child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _quoteKeyword(e.word),
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Filter from: ${e.filterFromLabel}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => _confirmRemove(i),
                            icon: const Icon(Icons.delete_outline_rounded, color: _black),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          ),
                        ],
                      ),
                    ),
                  );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.paddingOf(context).bottom),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _openAddKeyword,
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: const Text('Add keyword', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class AddKeywordScreen extends StatefulWidget {
  const AddKeywordScreen({super.key});

  @override
  State<AddKeywordScreen> createState() => _AddKeywordScreenState();
}

class _AddKeywordScreenState extends State<AddKeywordScreen> {
  final _controller = TextEditingController();
  final Set<KeywordFeedScope> _scopes = {KeywordFeedScope.forYou};
  static const _maxLen = 70;

  void _toggleScope(KeywordFeedScope s) {
    setState(() {
      if (_scopes.contains(s)) {
        if (_scopes.length > 1) _scopes.remove(s);
      } else {
        _scopes.add(s);
      }
    });
  }

  void _submit() {
    final w = _controller.text.trim();
    if (w.isEmpty) return;
    Navigator.pop(context, AddKeywordResult(word: w, scopes: Set.from(_scopes)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Add Keyword', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _controller,
                    maxLength: _maxLen,
                    buildCounter: (_, {required currentLength, required isFocused, maxLength}) => const SizedBox.shrink(),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Type keyword',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.shade300)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: Colors.grey.shade300)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: const BorderSide(color: _purple, width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Enter a single word or hashtag to filter from selected feeds. Spelling isn\'t case-sensitive.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${_controller.text.length}/$_maxLen',
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Text('Filter word from:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _KeywordScopeChip(
                          label: 'For you',
                          selected: _scopes.contains(KeywordFeedScope.forYou),
                          checkStyle: true,
                          onTap: () => _toggleScope(KeywordFeedScope.forYou),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KeywordScopeChip(
                          label: 'Following',
                          selected: _scopes.contains(KeywordFeedScope.following),
                          onTap: () => _toggleScope(KeywordFeedScope.following),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _KeywordScopeChip(
                          label: 'Friends',
                          selected: _scopes.contains(KeywordFeedScope.friends),
                          onTap: () => _toggleScope(KeywordFeedScope.friends),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
              color: Colors.white,
            ),
            padding: EdgeInsets.fromLTRB(20, 12, 20, 12 + MediaQuery.paddingOf(context).bottom),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _purple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 0,
                    ),
                    child: const Text('Next', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordScopeChip extends StatelessWidget {
  const _KeywordScopeChip({required this.label, required this.selected, required this.onTap, this.checkStyle = false});

  final String label;
  final bool selected;
  final bool checkStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              if (selected && checkStyle)
                Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: _purple),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                )
              else if (selected)
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _purple, width: 2),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: _purple),
                    ),
                  ),
                )
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    color: Colors.white,
                  ),
                ),
              const SizedBox(height: 8),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: _black)),
            ],
          ),
        ),
      ),
    );
  }
}

enum PostVisibilityAudience { everyone, myNetwork }

Future<void> showPostVisibilitySheet(BuildContext context, PostVisibilityAudience current, void Function(PostVisibilityAudience) onSet) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      PostVisibilityAudience temp = current;
      return StatefulBuilder(
        builder: (context, setModalState) {
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
                    const Text(
                      'Who can see my post',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black),
                    ),
                    const SizedBox(height: 20),
                    _PostVisibilityRadioRow(
                      label: 'Everyone',
                      selected: temp == PostVisibilityAudience.everyone,
                      onTap: () => setModalState(() => temp = PostVisibilityAudience.everyone),
                    ),
                    const SizedBox(height: 4),
                    _PostVisibilityRadioRow(
                      label: 'My Network',
                      selected: temp == PostVisibilityAudience.myNetwork,
                      onTap: () => setModalState(() => temp = PostVisibilityAudience.myNetwork),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: () {
                          onSet(temp);
                          Navigator.pop(ctx);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          elevation: 0,
                        ),
                        child: const Text('Set', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

class _PostVisibilityRadioRow extends StatelessWidget {
  const _PostVisibilityRadioRow({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

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
              Expanded(child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _black))),
              if (selected)
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _purple, width: 2),
                    color: _purple,
                  ),
                  child: Center(
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                  ),
                )
              else
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                    color: Colors.white,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostFeedVisibilityScreen extends StatefulWidget {
  const PostFeedVisibilityScreen({super.key});

  @override
  State<PostFeedVisibilityScreen> createState() => _PostFeedVisibilityScreenState();
}

class _PostFeedVisibilityScreenState extends State<PostFeedVisibilityScreen> {
  PostVisibilityAudience _audience = PostVisibilityAudience.everyone;
  bool _loading = true;

  String get _label => _audience == PostVisibilityAudience.everyone ? 'Everyone' : 'My Network';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var settings = AuthSession.instance.settings;
    if (settings == null) {
      try {
        settings = await AuthSession.instance.settingsRepository.getSettings();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      final value = settings?.postVisibilityDefault ?? 'everyone';
      _audience = value == 'my_network' ? PostVisibilityAudience.myNetwork : PostVisibilityAudience.everyone;
      _loading = false;
    });
  }

  Future<void> _save(PostVisibilityAudience value) async {
    setState(() => _audience = value);
    final current = AuthSession.instance.settings ?? const AppSettings();
    try {
      await AuthSession.instance.saveSettings(
        current.copyWith(postVisibilityDefault: value == PostVisibilityAudience.myNetwork ? 'my_network' : 'everyone'),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const _SubpageScaffold(title: 'Post', body: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    }
    return _SubpageScaffold(
      title: 'Post',
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          Text(
            'Who can see my feed',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.white,
            child: InkWell(
              onTap: () => showPostVisibilitySheet(context, _audience, _save),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
