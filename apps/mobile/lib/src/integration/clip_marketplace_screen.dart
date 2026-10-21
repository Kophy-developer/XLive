import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/auth_session.dart';
import '../../features/clips/clips_repository.dart';
import '../../features/clips/models/clip_models.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _light = Color(0xFFF6F6F6);

class ClipMarketplaceScreen extends StatefulWidget {
  const ClipMarketplaceScreen({super.key});

  @override
  State<ClipMarketplaceScreen> createState() => _ClipMarketplaceScreenState();
}

class _ClipMarketplaceScreenState extends State<ClipMarketplaceScreen> with SingleTickerProviderStateMixin {
  final _clipsRepo = ClipsRepository();
  late final TabController _tabs;

  List<ClipMarketplaceListing> _listings = const [];
  List<OwnedClip> _owned = const [];
  bool _loadingMarket = true;
  bool _loadingOwned = true;
  String? _marketError;
  String? _ownedError;
  String? _busyOwnershipId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _loadMarket();
    _loadOwned();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadMarket() async {
    setState(() {
      _loadingMarket = true;
      _marketError = null;
    });
    try {
      final items = await _clipsRepo.marketplaceResale();
      if (!mounted) return;
      setState(() {
        _listings = items;
        _loadingMarket = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMarket = false;
        _marketError = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _loadOwned() async {
    if (!AuthSession.instance.isSignedIn) {
      setState(() {
        _owned = const [];
        _loadingOwned = false;
        _ownedError = null;
      });
      return;
    }
    setState(() {
      _loadingOwned = true;
      _ownedError = null;
    });
    try {
      final items = await _clipsRepo.listOwned();
      if (!mounted) return;
      setState(() {
        _owned = items;
        _loadingOwned = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOwned = false;
        _ownedError = friendlyApiMessage(e);
      });
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadMarket(), _loadOwned()]);
  }

  Future<void> _purchase(ClipMarketplaceListing listing) async {
    if (_busyOwnershipId != null) return;
    final me = AuthSession.instance.user?.id;
    if (me != null && me == listing.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This is your listing. Switch to My clips to manage it.')),
      );
      _tabs.animateTo(1);
      return;
    }
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to buy collectibles.')));
      return;
    }
    setState(() => _busyOwnershipId = listing.ownershipId);
    try {
      await _clipsRepo.purchaseResale(listing.ownershipId);
      await AuthSession.instance.refreshWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchase complete')));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busyOwnershipId = null);
    }
  }

  Future<void> _listForResale(OwnedClip clip) async {
    final price = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ResalePriceSheet(
        title: clip.title ?? 'Clip',
        suggestedPrice: clip.purchasePrice > 0 ? clip.purchasePrice : (clip.originalMintPrice > 0 ? clip.originalMintPrice : 5),
      ),
    );
    if (price == null || !mounted) return;
    setState(() => _busyOwnershipId = clip.ownershipId);
    try {
      await _clipsRepo.listForResale(ownershipId: clip.ownershipId, price: price);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Listed for $price coins')),
      );
      await _refreshAll();
      if (mounted) _tabs.animateTo(0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busyOwnershipId = null);
    }
  }

  Future<void> _cancelListing(OwnedClip clip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel listing?'),
        content: Text(
          clip.title == null
              ? 'Remove this clip from the marketplace?'
              : 'Remove “${clip.title}” from the marketplace?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep listed')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: _purple),
            child: const Text('Cancel listing'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyOwnershipId = clip.ownershipId);
    try {
      await _clipsRepo.cancelResaleListing(clip.ownershipId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing cancelled')));
      await _refreshAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busyOwnershipId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return XLiveSubpage(
      title: 'Clip marketplace',
      actions: [
        TextButton(
          onPressed: () => Navigator.pushNamed(context, '/profile/creator/created-clips'),
          child: const Text('Created', style: TextStyle(fontWeight: FontWeight.w700, color: _purple)),
        ),
      ],
      body: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tabs,
              labelColor: _purple,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: _purple,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              tabs: const [
                Tab(text: 'For sale'),
                Tab(text: 'My clips'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                RefreshIndicator(
                  onRefresh: _loadMarket,
                  color: _purple,
                  child: _MarketTab(
                    loading: _loadingMarket,
                    error: _marketError,
                    listings: _listings,
                    busyOwnershipId: _busyOwnershipId,
                    myUserId: AuthSession.instance.user?.id,
                    onRetry: _loadMarket,
                    onPurchase: _purchase,
                  ),
                ),
                RefreshIndicator(
                  onRefresh: _loadOwned,
                  color: _purple,
                  child: _OwnedTab(
                    signedIn: AuthSession.instance.isSignedIn,
                    loading: _loadingOwned,
                    error: _ownedError,
                    owned: _owned,
                    busyOwnershipId: _busyOwnershipId,
                    onRetry: _loadOwned,
                    onList: _listForResale,
                    onCancel: _cancelListing,
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

class _MarketTab extends StatelessWidget {
  const _MarketTab({
    required this.loading,
    required this.error,
    required this.listings,
    required this.busyOwnershipId,
    required this.myUserId,
    required this.onRetry,
    required this.onPurchase,
  });

  final bool loading;
  final String? error;
  final List<ClipMarketplaceListing> listings;
  final String? busyOwnershipId;
  final String? myUserId;
  final VoidCallback onRetry;
  final Future<void> Function(ClipMarketplaceListing) onPurchase;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    }
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          _MarketplaceErrorBody(message: error!, onRetry: onRetry),
        ],
      );
    }
    if (listings.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          const _MarketplaceEmptyBody(
            icon: Icons.storefront_outlined,
            title: 'No resale listings yet',
            subtitle: 'When collectors list clips, they show up here.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: listings.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final listing = listings[i];
        final busy = busyOwnershipId == listing.ownershipId;
        final isMine = myUserId != null && myUserId == listing.sellerId;
        return _ListingCard(
          thumbnailUrl: listing.thumbnailUrl,
          title: listing.title ?? 'Clip',
          subtitle: listing.editionNumber > 0
              ? (listing.sellerName == null ? 'Edition #${listing.editionNumber}' : '${listing.sellerName} · #${listing.editionNumber}')
              : (listing.sellerName == null ? 'Resale listing' : 'By ${listing.sellerName}'),
          priceLabel: '${listing.price} coins',
          actionLabel: isMine ? 'Yours' : 'Buy',
          actionEnabled: !isMine && !busy,
          busy: busy,
          onAction: () => onPurchase(listing),
        );
      },
    );
  }
}

class _OwnedTab extends StatelessWidget {
  const _OwnedTab({
    required this.signedIn,
    required this.loading,
    required this.error,
    required this.owned,
    required this.busyOwnershipId,
    required this.onRetry,
    required this.onList,
    required this.onCancel,
  });

  final bool signedIn;
  final bool loading;
  final String? error;
  final List<OwnedClip> owned;
  final String? busyOwnershipId;
  final VoidCallback onRetry;
  final Future<void> Function(OwnedClip) onList;
  final Future<void> Function(OwnedClip) onCancel;

  @override
  Widget build(BuildContext context) {
    if (!signedIn) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          const _MarketplaceEmptyBody(
            icon: Icons.lock_outline_rounded,
            title: 'Sign in to manage clips',
            subtitle: 'Your owned collectibles and listings appear here.',
          ),
        ],
      );
    }
    if (loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ],
      );
    }
    if (error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
          _MarketplaceErrorBody(message: error!, onRetry: onRetry),
        ],
      );
    }
    if (owned.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.sizeOf(context).height * 0.22),
          const _MarketplaceEmptyBody(
            icon: Icons.collections_bookmark_outlined,
            title: 'No owned clips yet',
            subtitle: 'Buy a collectible, then list it here for resale.',
          ),
        ],
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: owned.length,
      separatorBuilder: (_, index) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final clip = owned[i];
        final busy = busyOwnershipId == clip.ownershipId;
        final listed = clip.listedForResale;
        return _ListingCard(
          thumbnailUrl: clip.thumbnailUrl,
          title: clip.title ?? 'Clip',
          subtitle: listed
              ? 'Listed · ${clip.resalePrice ?? 0} coins'
              : (clip.editionNumber > 0 ? 'Edition #${clip.editionNumber} · Owned' : 'Owned'),
          priceLabel: listed ? '${clip.resalePrice ?? 0} coins' : 'You paid ${clip.purchasePrice} coins',
          actionLabel: listed ? 'Cancel' : 'List',
          actionEnabled: !busy,
          busy: busy,
          outlined: listed,
          onAction: () => listed ? onCancel(clip) : onList(clip),
        );
      },
    );
  }
}

class _ListingCard extends StatelessWidget {
  const _ListingCard({
    required this.thumbnailUrl,
    required this.title,
    required this.subtitle,
    required this.priceLabel,
    required this.actionLabel,
    required this.actionEnabled,
    required this.busy,
    required this.onAction,
    this.outlined = false,
  });

  final String? thumbnailUrl;
  final String title;
  final String subtitle;
  final String priceLabel;
  final String actionLabel;
  final bool actionEnabled;
  final bool busy;
  final VoidCallback onAction;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _light,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x1A0A0A0A)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 72,
              height: 72,
              child: thumbnailUrl != null
                  ? Image.network(thumbnailUrl!, fit: BoxFit.cover)
                  : ColoredBox(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.play_circle_outline_rounded, color: _purple),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, color: _black),
                ),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                const SizedBox(height: 6),
                Text(priceLabel, style: const TextStyle(fontWeight: FontWeight.w800, color: _purple)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (outlined)
            OutlinedButton(
              onPressed: actionEnabled ? onAction : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _purple,
                side: const BorderSide(color: _purple),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                shape: const StadiumBorder(),
              ),
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: _purple),
                    )
                  : Text(actionLabel),
            )
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: actionEnabled ? const LinearGradient(colors: [_purple, _sky]) : null,
                color: actionEnabled ? null : Colors.grey.shade400,
                borderRadius: BorderRadius.circular(999),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  disabledBackgroundColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onPressed: actionEnabled ? onAction : null,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(actionLabel, style: const TextStyle(color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResalePriceSheet extends StatefulWidget {
  const _ResalePriceSheet({required this.title, required this.suggestedPrice});

  final String title;
  final int suggestedPrice;

  @override
  State<_ResalePriceSheet> createState() => _ResalePriceSheetState();
}

class _ResalePriceSheetState extends State<_ResalePriceSheet> {
  late final TextEditingController _price;

  @override
  void initState() {
    super.initState();
    _price = TextEditingController(text: '${widget.suggestedPrice}');
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_price.text.trim());
    if (value == null || value < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a price of at least 1 coin')),
      );
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const SizedBox(height: 16),
          const Text('List for resale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _black)),
          const SizedBox(height: 6),
          Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _price,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              labelText: 'Price (coins)',
              hintText: 'e.g. ${widget.suggestedPrice}',
              filled: true,
              fillColor: _light,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _sky]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _submit,
                  borderRadius: BorderRadius.circular(14),
                  child: const Center(
                    child: Text('List on marketplace', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceEmptyBody extends StatelessWidget {
  const _MarketplaceEmptyBody({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            Text(subtitle, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.35)),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceErrorBody extends StatelessWidget {
  const _MarketplaceErrorBody({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
