import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/user_avatar.dart';
import '../../features/clips/clips_repository.dart';
import '../../features/clips/models/clip_models.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _purpleBright = Color(0xFF8A3FFC);
const _pink = Color(0xFFEC4899);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _muted = Color(0xFF8E8E99);
const _field = Color(0xFFF4F4F6);
const _cardBorder = Color(0xFFE8E8EE);

LinearGradient get _brandGradient => const LinearGradient(
      colors: [_purpleBright, _pink],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

class MyCreatedClipsScreen extends StatefulWidget {
  const MyCreatedClipsScreen({super.key});

  @override
  State<MyCreatedClipsScreen> createState() => _MyCreatedClipsScreenState();
}

class _MyCreatedClipsScreenState extends State<MyCreatedClipsScreen> {
  final _clipsRepo = ClipsRepository();
  List<ClipSummary> _clips = const [];
  ClipEarnings? _earnings;
  bool _loading = true;
  String? _error;

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
      final results = await Future.wait([
        _clipsRepo.listCreated(limit: 50),
        _clipsRepo.getMyClipEarnings(),
      ]);
      if (!mounted) return;
      setState(() {
        _clips = results[0] as List<ClipSummary>;
        _earnings = results[1] as ClipEarnings;
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

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: 'My created clips',
      actions: [
        IconButton(
          tooltip: 'New collectible',
          icon: const Icon(Icons.add_rounded, color: _black),
          onPressed: () async {
            await Navigator.pushNamed(context, '/profile/creator/create-clip', arguments: 1);
            if (mounted) _load();
          },
        ),
      ],
      body: RefreshIndicator(
        color: _purple,
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 140),
          Center(child: CircularProgressIndicator(strokeWidth: 2, color: _purple)),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.18),
          Icon(Icons.cloud_off_rounded, size: 44, color: Colors.grey.shade400),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade700, height: 1.35),
          ),
          const SizedBox(height: 18),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _purple),
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ),
        ],
      );
    }

    final earnings = _earnings;
    final total = earnings?.total ?? 0;
    final sales = earnings?.salesCount ?? 0;
    final active = _clips.where((c) => !c.isArchived).length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _EarningsHero(
          totalCoins: total,
          salesCount: sales,
          clipCount: _clips.length,
          activeCount: active,
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            const Text(
              'Your collectibles',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pushNamed(context, '/profile/creator/clip-archive'),
              child: const Text('Archive', style: TextStyle(fontWeight: FontWeight.w600, color: _purple)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_clips.isEmpty)
          const _EmptyCreatedState()
        else
          ..._clips.map((clip) {
            final clipEarn = earnings?.breakdown[clip.id];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CreatedClipCard(
                clip: clip,
                earnings: clipEarn,
                onTap: () async {
                  await Navigator.pushNamed(
                    context,
                    '/profile/creator/created-clips/detail',
                    arguments: clip.id,
                  );
                  if (mounted) _load();
                },
              ),
            );
          }),
      ],
    );
  }
}

class CreatedClipDetailScreen extends StatefulWidget {
  const CreatedClipDetailScreen({super.key, required this.clipId});

  final String clipId;

  @override
  State<CreatedClipDetailScreen> createState() => _CreatedClipDetailScreenState();
}

class _CreatedClipDetailScreenState extends State<CreatedClipDetailScreen> {
  final _clipsRepo = ClipsRepository();
  ClipSummary? _clip;
  ClipEarnings? _earnings;
  List<ClipOwner> _owners = const [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

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
      final results = await Future.wait([
        _clipsRepo.getClip(widget.clipId),
        _clipsRepo.getEarnings(widget.clipId),
        _clipsRepo.listOwners(widget.clipId),
      ]);
      if (!mounted) return;
      setState(() {
        _clip = results[0] as ClipSummary;
        _earnings = results[1] as ClipEarnings;
        _owners = results[2] as List<ClipOwner>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      try {
        final created = await _clipsRepo.listCreated(limit: 50);
        final match = created.where((c) => c.id == widget.clipId).toList();
        final earnings = await _clipsRepo.getEarnings(widget.clipId);
        final owners = await _clipsRepo.listOwners(widget.clipId);
        if (!mounted) return;
        if (match.isEmpty) {
          setState(() {
            _loading = false;
            _error = friendlyApiMessage(e);
          });
          return;
        }
        setState(() {
          _clip = match.first;
          _earnings = earnings;
          _owners = owners;
          _loading = false;
        });
      } catch (e2) {
        if (!mounted) return;
        setState(() {
          _loading = false;
          _error = e2 is ApiException ? e2.message : e2.toString();
        });
      }
    }
  }

  Future<void> _editPrice() async {
    final clip = _clip;
    if (clip == null || !clip.canEdit) return;
    final controller = TextEditingController(text: '${clip.price}');
    final price = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.viewInsetsOf(ctx).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 18),
              const Text('Update price', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
              const SizedBox(height: 6),
              Text('Mint price in coins for remaining editions.', style: TextStyle(color: Colors.grey.shade600, fontSize: 13.5)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  suffixText: 'coins',
                  filled: true,
                  fillColor: _field,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _purple,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  final v = int.tryParse(controller.text.trim());
                  if (v == null || v < 1) return;
                  Navigator.pop(ctx, v);
                },
                child: const Text('Save price', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (price == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _clipsRepo.updateClip(clip.id, price: price);
      if (!mounted) return;
      setState(() => _clip = updated);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Price updated to $price coins')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _archive() async {
    final clip = _clip;
    if (clip == null || !clip.canArchive) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive collectible?'),
        content: const Text('New editions stop selling. Existing owners keep their clips.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _purple),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final updated = await _clipsRepo.archiveClip(clip.id);
      if (!mounted) return;
      setState(() => _clip = updated);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collectible archived')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final clip = _clip;
    if (clip == null || !clip.canDelete) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete collectible?'),
        content: const Text('This removes the clip permanently. Only unsold collectibles can be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _clipsRepo.deleteClip(clip.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Collectible deleted')));
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
      setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clip = _clip;
    return XLiveSubpage(
      title: clip?.title ?? 'Collectible',
      actions: [
        if (clip != null && clip.canEdit)
          IconButton(
            tooltip: 'Edit price',
            onPressed: _busy ? null : _editPrice,
            icon: const Icon(Icons.edit_outlined, color: _black),
          ),
        if (clip != null && (clip.canArchive || clip.canDelete))
          PopupMenuButton<String>(
            enabled: !_busy,
            onSelected: (v) {
              if (v == 'archive') _archive();
              if (v == 'delete') _delete();
            },
            itemBuilder: (_) => [
              if (clip.canArchive)
                const PopupMenuItem(value: 'archive', child: Text('Archive')),
              if (clip.canDelete)
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Color(0xFFDC2626))),
                ),
            ],
          ),
      ],
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _purple))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700)),
                        const SizedBox(height: 14),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: _purple),
                          onPressed: _load,
                          child: const Text('Try again'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  color: _purple,
                  onRefresh: _load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _DetailHero(clip: clip!),
                      const SizedBox(height: 16),
                      _DetailEarningsCard(earnings: _earnings, sold: clip.soldCount, supply: clip.maxSupply),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          const Text(
                            'Owners',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black),
                          ),
                          const Spacer(),
                          Text(
                            '${_owners.length}',
                            style: const TextStyle(fontWeight: FontWeight.w700, color: _muted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_owners.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 18),
                          decoration: BoxDecoration(
                            color: _field,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.people_outline_rounded, size: 36, color: Colors.grey.shade400),
                              const SizedBox(height: 10),
                              Text(
                                'No owners yet',
                                style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'When collectors buy editions, they appear here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.35),
                              ),
                            ],
                          ),
                        )
                      else
                        ..._owners.map((o) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _OwnerRow(owner: o),
                            )),
                      if (_busy) ...[
                        const SizedBox(height: 16),
                        const Center(child: CircularProgressIndicator(strokeWidth: 2, color: _purple)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _EarningsHero extends StatelessWidget {
  const _EarningsHero({
    required this.totalCoins,
    required this.salesCount,
    required this.clipCount,
    required this.activeCount,
  });

  final double totalCoins;
  final int salesCount;
  final int clipCount;
  final int activeCount;

  @override
  Widget build(BuildContext context) {
    final totalLabel = totalCoins == totalCoins.roundToDouble()
        ? '${totalCoins.toInt()}'
        : totalCoins.toStringAsFixed(1);
    return Container(
      decoration: BoxDecoration(
        gradient: _brandGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.28),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -24,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -40,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _sky.withValues(alpha: 0.18),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clip earnings',
                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      totalLabel,
                      style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1),
                    ),
                    const SizedBox(width: 8),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Text('coins', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(child: _HeroStat(label: 'Sales', value: '$salesCount')),
                    Expanded(child: _HeroStat(label: 'Created', value: '$clipCount')),
                    Expanded(child: _HeroStat(label: 'Active', value: '$activeCount')),
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

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.72), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _CreatedClipCard extends StatelessWidget {
  const _CreatedClipCard({
    required this.clip,
    required this.onTap,
    this.earnings,
  });

  final ClipSummary clip;
  final VoidCallback onTap;
  final double? earnings;

  @override
  Widget build(BuildContext context) {
    final supplyLabel = clip.maxSupply > 0 ? '${clip.soldCount}/${clip.maxSupply}' : '${clip.soldCount} sold';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 72,
                    height: 96,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (clip.thumbnailUrl != null && clip.thumbnailUrl!.isNotEmpty)
                          Image.network(clip.thumbnailUrl!, fit: BoxFit.cover)
                        else
                          Container(
                            decoration: BoxDecoration(gradient: _brandGradient),
                            child: const Icon(Icons.movie_filter_rounded, color: Colors.white70),
                          ),
                        if (clip.isArchived)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: const Text(
                              'Archived',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        clip.title ?? 'Collectible',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        clip.isCollectible ? 'Collectible clip' : 'Clip',
                        style: const TextStyle(fontSize: 12.5, color: _muted, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MetaChip(icon: Icons.monetization_on_outlined, label: '${clip.price}'),
                          _MetaChip(icon: Icons.layers_outlined, label: supplyLabel),
                          if (earnings != null && earnings! > 0)
                            _MetaChip(icon: Icons.trending_up_rounded, label: '${earnings!.toInt()} earned'),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: _purple),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _black)),
        ],
      ),
    );
  }
}

class _EmptyCreatedState extends StatelessWidget {
  const _EmptyCreatedState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 36, 20, 32),
      decoration: BoxDecoration(
        color: _field,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _brandGradient,
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 16),
          const Text(
            'Create your first collectible',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black),
          ),
          const SizedBox(height: 6),
          Text(
            'Publish a limited edition clip, track owners, and see earnings here.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 18),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _purple,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () => Navigator.pushNamed(context, '/profile/creator/create-clip', arguments: 1),
            child: const Text('New collectible'),
          ),
        ],
      ),
    );
  }
}

class _DetailHero extends StatelessWidget {
  const _DetailHero({required this.clip});

  final ClipSummary clip;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (clip.thumbnailUrl != null && clip.thumbnailUrl!.isNotEmpty)
                  Image.network(clip.thumbnailUrl!, fit: BoxFit.cover)
                else
                  DecoratedBox(
                    decoration: BoxDecoration(gradient: _brandGradient),
                    child: const Center(child: Icon(Icons.movie_filter_rounded, color: Colors.white70, size: 48)),
                  ),
                Positioned(
                  left: 12,
                  bottom: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      clip.isArchived ? 'Archived' : (clip.isCollectible ? 'Collectible' : 'Clip'),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clip.title ?? 'Collectible',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black),
                ),
                if (clip.description != null && clip.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    clip.description!,
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.4),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    _DetailStat(label: 'Price', value: '${clip.price}'),
                    _DetailStat(
                      label: 'Supply',
                      value: clip.maxSupply > 0 ? '${clip.soldCount}/${clip.maxSupply}' : '${clip.soldCount}',
                    ),
                    _DetailStat(label: 'Left', value: '${clip.remainingSupply}'),
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

class _DetailStat extends StatelessWidget {
  const _DetailStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: _muted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black)),
        ],
      ),
    );
  }
}

class _DetailEarningsCard extends StatelessWidget {
  const _DetailEarningsCard({
    required this.earnings,
    required this.sold,
    required this.supply,
  });

  final ClipEarnings? earnings;
  final int sold;
  final int supply;

  @override
  Widget build(BuildContext context) {
    final total = earnings?.total ?? 0;
    final sales = earnings?.salesCount ?? sold;
    final totalLabel = total == total.roundToDouble() ? '${total.toInt()}' : total.toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _brandGradient,
            ),
            child: const Icon(Icons.insights_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Earnings', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '$totalLabel coins',
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$sales sales', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              if (supply > 0)
                Text(
                  '$sold of $supply editions',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.55), fontSize: 12),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OwnerRow extends StatelessWidget {
  const _OwnerRow({required this.owner});

  final ClipOwner owner;

  static String _ownerSubtitle(ClipOwner owner) {
    final parts = [
      if (owner.editionNumber > 0) 'Edition #${owner.editionNumber}',
      if (owner.purchasePrice > 0) '${owner.purchasePrice} coins',
      if (owner.listedForResale) 'Listed',
    ];
    return parts.isEmpty ? 'Collector' : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorder),
      ),
      child: Row(
        children: [
          UserAvatar(imageUrl: owner.avatarUrl, radius: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(owner.name, style: const TextStyle(fontWeight: FontWeight.w700, color: _black)),
                const SizedBox(height: 2),
                Text(
                  _ownerSubtitle(owner),
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
            ),
          ),
          if (owner.listedForResale)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _sky.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text('Resale', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF0891B2))),
            ),
        ],
      ),
    );
  }
}
