import 'package:flutter/material.dart';

import '../../core/session/auth_session.dart';
import '../../features/clips/clips_repository.dart';
import '../../features/clips/models/clip_models.dart';
import '../../features/creator/creator_repository.dart';
import '../../features/creator/models/creator_models.dart';
import '../../features/subscriptions/subscriptions_repository.dart';
import '../../features/subscriptions/models/subscription_models.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _purpleLive = Color(0xFF9333EA);
const _black = Color(0xFF0A0A0A);

class CreatorGate extends StatelessWidget {
  const CreatorGate({super.key, required this.child, this.embedded = false});

  final Widget child;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthSession.instance,
      builder: (context, _) {
        final session = AuthSession.instance;
        if (session.isCreator || session.creatorMode) return child;
        final card = Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.workspace_premium_rounded, size: 56, color: _purple),
                const SizedBox(height: 16),
                const Text(
                  'Turn on Creator mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enable Creator mode to access creator tools and mint collectible clips.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B6B72), height: 1.4),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _purple,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  ),
                  onPressed: () => AuthSession.instance.setCreatorMode(true),
                  child: const Text('Enable Creator mode'),
                ),
              ],
            ),
          ),
        );
        if (embedded) return card;
        return Scaffold(
          appBar: AppBar(),
          body: card,
        );
      },
    );
  }
}

Widget _coinChip(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
    child: const Icon(Icons.star_rounded, color: Colors.white, size: 14),
  );
}

class CreatorToolsMenuScreen extends StatelessWidget {
  const CreatorToolsMenuScreen({super.key});

  static const _bg = Color(0xFF09090C);
  static const _card = Color(0xFF15151B);
  static const _muted = Color(0xFF8E8E99);

  @override
  Widget build(BuildContext context) {
    final entries = <(IconData, String, String, String)>[
      (Icons.account_balance_wallet_rounded, 'Earnings & Withdrawals', 'Balance, payouts, history', '/profile/creator/earnings'),
      (Icons.insights_rounded, 'Performance Analytics', 'Views, engagement, revenue', '/profile/creator/analytics'),
      (Icons.auto_awesome_mosaic_rounded, 'My Created Clips', 'Owners, earnings, editions', '/profile/creator/created-clips'),
      (Icons.lock_clock_rounded, 'Private Livestream', 'Per-minute pricing, talk-back', '/profile/creator/private-live'),
      (Icons.video_library_rounded, 'Clip Archive', 'Archived collectibles', '/profile/creator/clip-archive'),
    ];
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    onPressed: () => Navigator.maybePop(context),
                  ),
                  const Text('Creator tools', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: entries.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return Material(
                    color: _card,
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.pushNamed(context, e.$4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(colors: [Color(0xFF8A2DDC), Color(0xFFE8487E)]),
                              ),
                              child: Icon(e.$1, color: Colors.white, size: 20),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(e.$2, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 3),
                                  Text(e.$3, style: const TextStyle(color: _muted, fontSize: 13)),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded, color: _muted),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PerformanceAnalyticsScreen extends StatefulWidget {
  const PerformanceAnalyticsScreen({super.key});

  @override
  State<PerformanceAnalyticsScreen> createState() => _PerformanceAnalyticsScreenState();
}

class _PerformanceAnalyticsScreenState extends State<PerformanceAnalyticsScreen> {
  final _creatorRepo = CreatorRepository();
  int _segment = 0;
  CreatorAnalytics? _analytics;
  bool _loading = true;
  String? _error;

  String get _range => switch (_segment) {
        0 => 'today',
        1 => 'week',
        _ => 'month',
      };

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
      final data = await _creatorRepo.getAnalytics(range: _range);
      if (!mounted) return;
      setState(() {
        _analytics = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  String _metric(String key) {
    final value = _analytics?.getMetric(key) ?? 0;
    return _formatMetric(value);
  }

  String _formatMetric(num value) {
    if (value is double && value % 1 != 0) return value.toStringAsFixed(1);
    return '$value';
  }

  String _periodTitle(DateTime now) {
    const short = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    if (_segment == 0) return 'Today ${now.day} ${short[now.month - 1]}';
    if (_segment == 1) {
      final mon = now.subtract(Duration(days: now.weekday - 1));
      final sun = mon.add(const Duration(days: 6));
      return '${mon.day} ${short[mon.month - 1]} - ${sun.day} ${short[sun.month - 1]}';
    }
    const long = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return long[now.month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
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
        title: const Text('Performance Analytics', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(_error!), TextButton(onPressed: _load, child: const Text('Retry'))]))
              : ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Text(_periodTitle(now), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 16),
          _AnalyticsSegmentBar(segment: _segment, onChanged: (i) {
            setState(() => _segment = i);
            _load();
          }),
          const SizedBox(height: 20),
          _analyticsGridRow(
            _metricCell('Profile Views', Icons.person_outline_rounded, _metric('profile')),
            _metricCell('Likes', Icons.favorite_border_rounded, _metric('like')),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _analyticsGridRow(
            _metricCell('Comments', Icons.chat_bubble_outline_rounded, _metric('comment')),
            _metricCell('Shares', Icons.redo_rounded, _metric('share')),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          _analyticsGridRow(
            _metricCell('Subscribers', Icons.people_outline_rounded, _metric('subscriber')),
            _metricCell('Clips', Icons.videocam_outlined, _formatMetric(_analytics?.clipsMetric ?? 0)),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text('Live Streams', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
          const SizedBox(height: 12),
          _analyticsGridRow(
            _metricCell('Time Spent', Icons.schedule_outlined, '${_metric('time')} hrs'),
            _metricCell('Views', Icons.remove_red_eye_outlined, _metric('view')),
          ),
          Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
        ],
      ),
    );
  }

  Widget _analyticsGridRow(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        Expanded(child: right),
      ],
    );
  }

  Widget _metricCell(String label, IconData icon, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(icon, size: 22, color: Colors.grey.shade600),
              const SizedBox(width: 10),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AnalyticsSegmentBar extends StatelessWidget {
  const _AnalyticsSegmentBar({required this.segment, required this.onChanged});

  final int segment;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const labels = ['Today', 'Week', 'Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFFE8E8E8), borderRadius: BorderRadius.circular(999)),
      child: Row(
        children: List.generate(3, (i) {
          final sel = segment == i;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onChanged(i),
                borderRadius: BorderRadius.circular(999),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(labels[i], style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: sel ? _black : Colors.grey.shade600)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class PrivateLiveStreamScreen extends StatefulWidget {
  const PrivateLiveStreamScreen({super.key});

  @override
  State<PrivateLiveStreamScreen> createState() => _PrivateLiveStreamScreenState();
}

class _PrivateLiveStreamScreenState extends State<PrivateLiveStreamScreen> {
  final _creatorRepo = CreatorRepository();
  int _price = 0;
  bool _audioOn = true;
  bool _loading = true;
  bool _saving = false;
  static const _prices = [50, 100, 200, 300, 500, 1000];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final settings = await _creatorRepo.getCreatorSettings();
      if (!mounted) return;
      final price = settings.privateStreamPricePerMinute.toInt();
      setState(() {
        _price = _prices.contains(price) ? price : 0;
        _audioOn = settings.allowViewerTalkBack;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await _creatorRepo.updateCreatorSettings(
        CreatorSettings(privateStreamPricePerMinute: _price.toDouble(), allowViewerTalkBack: _audioOn),
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Private Live Stream', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const Text('Private Live Stream Preferences', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 28),
          const Text('Video price per minute (coins)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 8),
          Text(
            'Set an invite price in coins for your private stream sessions and earn when viewers join',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          Column(
            children: [
              Row(
                children: [
                  Expanded(child: _pricePill(0, _price == 0, () => setState(() => _price = 0))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final p in _prices.take(3)) Expanded(child: _pricePill(p, _price == p, () => setState(() => _price = p))),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final p in _prices.skip(3)) Expanded(child: _pricePill(p, _price == p, () => setState(() => _price = p))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Allow viewers to talk back in the stream', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 8),
          Text(
            'This allow viewers to communicate through audio during the live stream',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _audioPill('Enable audio', _audioOn, () => setState(() => _audioOn = true))),
              const SizedBox(width: 12),
              Expanded(child: _audioPill('Disable Audio', !_audioOn, () => setState(() => _audioOn = false))),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: _purpleLive,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _saving
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Done', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _pricePill(int value, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: selected ? _black : const Color(0xFFE5E7EB), width: selected ? 2.5 : 1),
              borderRadius: BorderRadius.circular(999),
              color: Colors.white,
            ),
            child: value == 0
                ? const Text('Free (no charge)', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _coinChip(22),
                      const SizedBox(width: 6),
                      Text('$value coins', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _audioPill(String label, bool selected, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(color: selected ? _black : const Color(0xFFE5E7EB), width: selected ? 2.5 : 1),
            borderRadius: BorderRadius.circular(999),
            color: Colors.white,
          ),
          child: Text(
            label,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: selected ? _black : Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

class ClipArchiveScreen extends StatefulWidget {
  const ClipArchiveScreen({super.key});

  @override
  State<ClipArchiveScreen> createState() => _ClipArchiveScreenState();
}

class _ClipArchiveScreenState extends State<ClipArchiveScreen> {
  final _creatorRepo = CreatorRepository();
  final _clipsRepo = ClipsRepository();
  int? _selected;
  List<ClipSummary> _clips = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _creatorRepo.listArchivedClips();
      if (!mounted) return;
      setState(() {
        _clips = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _changePrice(int index) async {
    final clip = _clips[index];
    final v = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ChangePriceSheet(initial: clip.price),
    );
    if (v == null) return;
    try {
      await _clipsRepo.updateClip(clip.id, price: v);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  Future<void> _confirmDelete() async {
    if (_selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a clip first')));
      return;
    }
    final clip = _clips[_selected!];
    if (!clip.canDelete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sold clips cannot be deleted.')),
      );
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _DeleteClipSheet(),
    );
    if (ok != true || !mounted) return;
    try {
      await _clipsRepo.deleteClip(clip.id);
      setState(() => _selected = null);
      await _load();
    } catch (e) {
      if (!mounted) return;
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
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('Clip Archive', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: _black),
            onPressed: () => Navigator.pushNamed(context, '/profile/creator/edit-clip'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: _black),
            onPressed: _confirmDelete,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _clips.isEmpty
          ? Center(child: Text('No clips', style: TextStyle(color: Colors.grey.shade600)))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _clips.length,
              separatorBuilder: (_, index) => SizedBox(height: 12, key: ValueKey('sep-$index')),
              itemBuilder: (_, i) {
                final clip = _clips[i];
                final sel = _selected == i;
                return _ClipArchiveRow(
                  selected: sel,
                  thumbUrl: clip.thumbnailUrl ?? '',
                  title: clip.title ?? 'Clip',
                  price: clip.price,
                  onSelect: () => setState(() => _selected = sel ? null : i),
                  onOwnFor: () => _changePrice(i),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: _purple,
        onPressed: () => Navigator.pushNamed(context, '/profile/creator/create-clip'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
    );
  }
}

class _ClipArchiveRow extends StatelessWidget {
  const _ClipArchiveRow({
    required this.selected,
    required this.thumbUrl,
    required this.title,
    required this.price,
    required this.onSelect,
    required this.onOwnFor,
  });

  final bool selected;
  final String thumbUrl;
  final String title;
  final int price;
  final VoidCallback onSelect;
  final VoidCallback onOwnFor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: const Color(0xFFF0F0F0),
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onSelect,
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _clipRadio(selected),
                        ),
                      ),
                    ),
                    Expanded(
                        child: AspectRatio(
                        aspectRatio: 9 / 16,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (thumbUrl.isNotEmpty)
                                Image.network(thumbUrl, fit: BoxFit.cover)
                              else
                                ColoredBox(color: Colors.grey.shade300),
                              Container(color: Colors.black26),
                              const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 36)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, height: 1.35, color: _black),
                    ),
                    const Spacer(),
                    Material(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(999),
                      child: InkWell(
                        onTap: onOwnFor,
                        borderRadius: BorderRadius.circular(999),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('Own for', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _black)),
                              const SizedBox(width: 6),
                              _coinChip(20),
                              const SizedBox(width: 4),
                              Text('$price coins', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _black)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _clipRadio(bool on) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: on ? _purple : Colors.grey.shade400, width: 2),
        color: on ? _purple : Colors.transparent,
      ),
      child: on ? const Center(child: Icon(Icons.circle, size: 10, color: Colors.white)) : null,
    );
  }
}

class _ChangePriceSheet extends StatefulWidget {
  const _ChangePriceSheet({required this.initial});

  final int initial;

  @override
  State<_ChangePriceSheet> createState() => _ChangePriceSheetState();
}

class _ChangePriceSheetState extends State<_ChangePriceSheet> {
  static const _options = [50, 100, 200, 300, 500, 1000];
  late int _sel;

  @override
  void initState() {
    super.initState();
    _sel = _options.contains(widget.initial) ? widget.initial : 100;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 10, 20, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Spacer(),
              Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: _black)),
                ),
              ),
            ],
          ),
          const Text('Change Price (coins)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 16),
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) Divider(height: 1, color: Colors.grey.shade200),
            InkWell(
              onTap: () => setState(() => _sel = _options[i]),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  children: [
                    _coinChip(24),
                    const SizedBox(width: 12),
                    Text('${_options[i]} coins', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500, color: _black)),
                    const Spacer(),
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: _sel == _options[i] ? _purple : Colors.grey.shade400, width: 2),
                        color: _sel == _options[i] ? _purple : Colors.white,
                      ),
                      child: _sel == _options[i] ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.white)) : null,
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context, _sel),
              style: OutlinedButton.styleFrom(
                foregroundColor: _black,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              child: const Text('Save', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteClipSheet extends StatelessWidget {
  const _DeleteClipSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 28 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(14)),
            child: const Icon(Icons.delete_outline_rounded, color: _black, size: 30),
          ),
          const SizedBox(height: 20),
          const Text('Delete clip', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 12),
          Text(
            'Are you sure you want to delete the clip? Once you delete it, it cannot be recovered.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.45),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE84D6F),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              child: const Text('Delete Clip', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
          ),
        ],
      ),
    );
  }
}

class MySubscriptionScreen extends StatefulWidget {
  const MySubscriptionScreen({super.key});

  @override
  State<MySubscriptionScreen> createState() => _MySubscriptionScreenState();
}

class _MySubscriptionScreenState extends State<MySubscriptionScreen> {
  final _subscriptionsRepo = SubscriptionsRepository();
  List<MySubscription> _subs = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _subscriptionsRepo.listMine();
      if (!mounted) return;
      setState(() {
        _subs = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _cancel(MySubscription sub) async {
    try {
      await _subscriptionsRepo.cancel(sub.creatorId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription cancelled')));
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF9F9F9),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text('My Subscription', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _subs.isEmpty
              ? Center(child: Text('No active subscriptions', style: TextStyle(color: Colors.grey.shade600)))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                  children: [
                    const Text('My Plans', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _black)),
                    const SizedBox(height: 16),
                    for (final sub in _subs) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(sub.creatorName ?? 'Creator', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _black)),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _coinChip(28),
                                      const SizedBox(width: 8),
                                      Text('${sub.monthlyPrice} coins', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _black)),
                                    ],
                                  ),
                                  if (sub.status != null) Text(sub.status!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                                ],
                              ),
                            ),
                            TextButton(onPressed: () => _cancel(sub), child: const Text('Cancel')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
    );
  }
}
