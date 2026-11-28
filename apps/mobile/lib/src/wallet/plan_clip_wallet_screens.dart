import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_exception.dart';
import '../../core/widgets/user_avatar.dart';
import '../../core/session/auth_session.dart';
import '../../features/clips/clips_repository.dart';
import '../../features/clips/models/clip_models.dart';
import '../../features/feed/models/feed_models.dart';
import '../../features/social/social_repository.dart';
import '../../features/subscriptions/models/subscription_models.dart';
import '../../features/subscriptions/subscriptions_repository.dart';
import '../../core/subscriptions/subscription_store.dart';
import '../../features/wallet/models/wallet_models.dart';
import '../../features/wallet/wallet_currency.dart';
import '../../features/wallet/wallet_repository.dart';
import '../app_bottom_nav.dart';
import '../../core/network/api_friendly_messages.dart';

const _black = Color(0xFF0A0A0A);
const _payPurple = Color(0xFF8A30E5);
const _radioPurple = Color(0xFF8A2BE2);

const _kClipPreview = 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=700&q=85';

Widget goldCoinIcon(double size) {
  return Container(
    width: size,
    height: size,
    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD700)),
    child: Icon(Icons.star_rounded, color: Colors.white, size: size * 0.55),
  );
}

void showXlivePaymentMethodSheet(
  BuildContext context, {
  required int coins,
  required double amountUsd,
  required String fiatPrice,
  required bool appleStoreSelected,
}) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _PaymentMethodSheet(
      coins: coins,
      amountUsd: amountUsd,
      fiatPrice: fiatPrice,
      appleStoreSelected: appleStoreSelected,
    ),
  );
}

void showClipPreviewSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ClipPreviewSheet(),
  );
}

class CreatorStoreComboSheet extends StatefulWidget {
  const CreatorStoreComboSheet({super.key, this.creatorId, this.initialNftMode = true});

  final String? creatorId;
  final bool initialNftMode;

  @override
  State<CreatorStoreComboSheet> createState() => _CreatorStoreComboSheetState();
}

class _CreatorStoreComboSheetState extends State<CreatorStoreComboSheet> {
  final _clipsRepo = ClipsRepository();
  final _socialRepo = SocialRepository();
  final _subscriptionsRepo = SubscriptionsRepository();

  late bool _nftMode;
  List<ClipSummary> _collectibles = const [];
  CreatorSubscriptionPlan? _plan;
  bool _loading = true;
  String? _error;
  String? _purchasingClipId;
  bool _subscribing = false;

  @override
  void initState() {
    super.initState();
    _nftMode = widget.initialNftMode;
    _load();
  }

  String? get _creatorId {
    final id = widget.creatorId;
    if (id != null && id.isNotEmpty) return id;
    return AuthSession.instance.user?.id;
  }

  Future<void> _load() async {
    final creatorId = _creatorId;
    if (creatorId == null || creatorId.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Creator not found';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final content = await _socialRepo.getUserContent(creatorId, tab: 'clips', limit: 20);
      final clipIds = content.where((item) => item.type == FeedContentType.clip).map((item) => item.id).toList();
      final clips = await Future.wait(clipIds.map(_clipsRepo.getClip));
      final collectibles = clips.where((clip) => clip.isCollectible && clip.price > 0).toList();
      CreatorSubscriptionPlan? plan;
      try {
        plan = await _subscriptionsRepo.getPlan(creatorId);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _collectibles = collectibles;
        _plan = plan;
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

  Future<void> _purchaseClip(ClipSummary clip) async {
    if (_purchasingClipId != null) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to purchase clips.')));
      return;
    }
    setState(() => _purchasingClipId = clip.id);
    try {
      await _clipsRepo.purchaseCollectible(clip.id);
      await AuthSession.instance.refreshWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Clip added to My clips')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _purchasingClipId = null);
    }
  }

  Future<void> _subscribe() async {
    final creatorId = _creatorId;
    if (creatorId == null || creatorId.isEmpty) return;
    if (!AuthSession.instance.isSignedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sign in to subscribe.')));
      return;
    }
    setState(() => _subscribing = true);
    try {
      await _subscriptionsRepo.subscribe(creatorId);
      SubscriptionStore.instance.addSubscribedCreator(creatorId);
      await AuthSession.instance.refreshWallet();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscribed successfully')));
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      maxChildSize: 0.95,
      minChildSize: 0.45,
      builder: (ctx, scroll) {
        return Container(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
            gradient: _nftMode
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF3D000C),
                      Color(0xFF8B1538),
                      Color(0xFFFF6B35),
                      Color(0xFF4A148C),
                    ],
                    stops: [0.0, 0.35, 0.65, 1.0],
                  )
                : const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF0D5C52),
                      Color(0xFF1E3A5F),
                      Color(0xFF3D0F6B),
                    ],
                  ),
          ),
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _nftMode = false),
                            customBorder: const CircleBorder(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _nftMode ? Colors.transparent : const Color(0xFF8A2DDC),
                                shape: BoxShape.circle,
                                border: _nftMode ? Border.all(color: Colors.white70, width: 1.5) : null,
                              ),
                              child: Icon(
                                _nftMode ? Icons.star_border_rounded : Icons.star_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => setState(() => _nftMode = true),
                            customBorder: const CircleBorder(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: _nftMode ? const Color(0xFFFF6B35) : Colors.white.withValues(alpha: 0.22),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                )
              else if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Column(
                    children: [
                      Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
                      TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: Colors.white))),
                    ],
                  ),
                )
              else if (_nftMode) ...[
                const Text(
                  'Own a Clip as an NFT Collection to your Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25),
                ),
                const SizedBox(height: 20),
                if (_collectibles.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('No collectible clips available yet.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  )
                else
                  for (final clip in _collectibles) ...[
                    _nftClipRow(clip),
                    const SizedBox(height: 12),
                  ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: () => Navigator.pushNamed(context, '/integration/clip-marketplace'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: _black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('View marketplace', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  ),
                ),
              ] else ...[
                const Text(
                  'Subscribe to Unlock Exclusive access',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, height: 1.25),
                ),
                const SizedBox(height: 20),
                if (_plan == null || !_plan!.hasSubscribablePlan)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('This creator has not set a subscription plan yet.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                  )
                else ...[
                  _subCard('Monthly', '${_plan!.monthlyPrice} coins', 'Billed monthly in coins', true),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton(
                      onPressed: _subscribing ? null : _subscribe,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _black,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: _subscribing
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Subscribe', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    ),
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _nftClipRow(ClipSummary clip) {
    final thumb = clip.thumbnailUrl ?? '';
    final busy = _purchasingClipId == clip.id;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white, width: 1.2),
        borderRadius: BorderRadius.circular(22),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 108,
            height: 118,
            child: ColoredBox(
              color: Colors.white,
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  if (thumb.isNotEmpty)
                    Image.network(thumb, fit: BoxFit.cover, errorBuilder: (_, _, _) => const ColoredBox(color: Color(0xFFE8E8E8)))
                  else
                    const ColoredBox(color: Color(0xFFE8E8E8), child: Icon(Icons.movie_filter_outlined, color: _black)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: _black, size: 28),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      clip.title ?? 'Collectible clip',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.35, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: FilledButton(
                      onPressed: busy ? null : () => _purchaseClip(clip),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _black,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(busy ? 'Buying…' : 'Own for', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          if (!busy) ...[
                            const SizedBox(width: 6),
                            goldCoinIcon(18),
                            const SizedBox(width: 4),
                            Text('${clip.price} coins', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _subCard(String label, String coins, String sub, bool selected) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.2),
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.15),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (selected)
            Positioned(
              top: -10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                child: const Text('Selected', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _black)),
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 76,
                child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        goldCoinIcon(26),
                        const SizedBox(width: 8),
                        Text(coins, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodSheet extends StatefulWidget {
  const _PaymentMethodSheet({
    required this.coins,
    required this.amountUsd,
    required this.fiatPrice,
    required this.appleStoreSelected,
  });

  final int coins;
  final double amountUsd;
  final String fiatPrice;
  final bool appleStoreSelected;

  @override
  State<_PaymentMethodSheet> createState() => _PaymentMethodSheetState();
}

class _PaymentMethodSheetState extends State<_PaymentMethodSheet> with WidgetsBindingObserver {
  final _walletRepo = WalletRepository();
  late int _method;
  bool _loadingProviders = true;
  bool _paying = false;
  bool _verifying = false;
  bool _autoPolling = false;
  String? _pendingPaymentId;
  String? _pendingReference;
  String? _pendingOrderId;
  String? _pollStatus;
  Timer? _pollTimer;
  int _pollAttempts = 0;
  List<({String id, String label})> _providers = const [];

  static const _maxPollAttempts = 40;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _method = widget.appleStoreSelected ? 1 : 0;
    _loadProviders();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _pendingPaymentId != null) {
      _verifying = false;
      _pollPaymentOnce();
    }
  }

  void _startAutoPoll() {
    _pollTimer?.cancel();
    _pollAttempts = 0;
    setState(() {
      _autoPolling = true;
      _pollStatus = 'Waiting for payment confirmation…';
    });
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollPaymentOnce());
    _pollPaymentOnce();
  }

  void _stopAutoPoll() {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (mounted) setState(() => _autoPolling = false);
  }

  Future<void> _completePaymentIfNeeded(String paymentId) async {
    await _walletRepo.verifyFund(
      paymentId: paymentId,
      reference: _pendingReference,
      orderId: _pendingOrderId,
    );
    await AuthSession.instance.refreshWallet();
    _stopAutoPoll();
    if (!mounted) return;
    setState(() {
      _pendingPaymentId = null;
      _pendingReference = null;
      _pendingOrderId = null;
      _pollStatus = null;
      _verifying = false;
    });
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment verified. Balance updated.')));
  }

  Future<void> _pollPaymentOnce() async {
    final paymentId = _pendingPaymentId;
    if (paymentId == null || paymentId.isEmpty || _verifying) return;
    if (_pollAttempts >= _maxPollAttempts) {
      _stopAutoPoll();
      if (!mounted) return;
      setState(() => _pollStatus = 'Still pending — tap Verify payment when done');
      return;
    }
    _pollAttempts += 1;
    setState(() => _verifying = true);
    try {
      final status = await _walletRepo.paymentStatus(paymentId);
      final state = (status['status'] ?? status['paymentStatus'] ?? status['state'])?.toString().toLowerCase();
      if (state == 'completed' || state == 'success' || state == 'paid' || state == 'successful') {
        await _completePaymentIfNeeded(paymentId);
        return;
      }
      if (state == 'failed' || state == 'cancelled' || state == 'canceled') {
        _stopAutoPoll();
        if (!mounted) return;
        setState(() {
          _pollStatus = 'Payment failed or cancelled';
          _verifying = false;
        });
        return;
      }
      if (!mounted) return;
      setState(() {
        _pollStatus = 'Checking payment… ($_pollAttempts)';
        _verifying = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _verifying = false);
    }
  }

  Future<void> _loadProviders() async {
    try {
      final data = await _walletRepo.paymentMethods();
      final raw = data['providers'] ?? data['paymentProviders'] ?? data['items'];
      final providers = <({String id, String label})>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final map = Map<String, dynamic>.from(item);
          final id = (map['id'] ?? map['provider'] ?? map['code'])?.toString().toLowerCase();
          if (id == null || id.isEmpty) continue;
          if (id == 'stripe' || id == 'apple' || id == 'google') continue;
          final label = _prettyProviderName(id, (map['name'] ?? map['label'] ?? map['provider'] ?? id).toString());
          providers.add((id: id, label: label));
        }
      }
      if (!mounted) return;
      setState(() {
        _providers = providers;
        _loadingProviders = false;
        if (_method >= providers.length) _method = 0;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingProviders = false);
    }
  }

  String _prettyProviderName(String id, String fallback) {
    switch (id) {
      case 'paystack':
        return 'Paystack';
      case 'paypal':
        return 'PayPal';
      default:
        if (fallback.isEmpty) return id;
        return fallback[0].toUpperCase() + fallback.substring(1);
    }
  }

  Future<void> _pay() async {
    if (_providers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No payment providers available')));
      return;
    }
    final provider = _providers[_method.clamp(0, _providers.length - 1)];
    setState(() => _paying = true);
    try {
      final result = await _walletRepo.initiateFund(
        amount: widget.amountUsd < 1 ? 1 : widget.amountUsd.round().clamp(1, 100000),
        provider: provider.id,
        flow: 'redirect',
        packageId: '${widget.coins}',
        coins: widget.coins,
      );
      final url = result.checkoutUrl;
      if (url == null || url.isEmpty) {
        throw ApiException('Checkout URL missing from payment provider.');
      }
      final uri = Uri.tryParse(url);
      if (uri == null) {
        throw ApiException('Invalid checkout URL.');
      }
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw ApiException('Could not open checkout. Install a browser and try again.');
      }
      if (!mounted) return;
      setState(() {
        _pendingPaymentId = result.paymentId;
        _pendingReference = result.reference;
        _pendingOrderId = result.orderId;
        _pollStatus = 'Complete checkout in your browser…';
      });
      _startAutoPoll();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Complete ${provider.label} checkout, then return here.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _verifyPayment() async {
    final paymentId = _pendingPaymentId;
    if (paymentId == null || paymentId.isEmpty) return;
    setState(() {
      _verifying = true;
      _pollStatus = 'Verifying payment…';
    });
    try {
      await _completePaymentIfNeeded(paymentId);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _pollStatus = friendlyApiMessage(e);
      });
      await _pollPaymentOnce();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, color: Colors.grey.shade800)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    goldCoinIcon(28),
                    const SizedBox(width: 10),
                    Text('${widget.coins} coins', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black)),
                    const Spacer(),
                    Text(widget.fiatPrice, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Select Payment Method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingProviders)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(strokeWidth: 2)))
            else if (_providers.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text('Payment providers unavailable', style: TextStyle(color: Colors.grey.shade700)),
              )
            else
              for (var i = 0; i < _providers.length; i++)
                _payRow(
                  index: i,
                  provider: _providers[i],
                ),
            if (_pollStatus != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Row(
                  children: [
                    if (_autoPolling) const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    if (_autoPolling) const SizedBox(width: 10),
                    Expanded(child: Text(_pollStatus!, style: TextStyle(fontSize: 13, color: Colors.grey.shade700))),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _verifying || _pendingPaymentId == null ? null : _verifyPayment,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _payPurple,
                    side: BorderSide(color: _pendingPaymentId == null ? Colors.grey.shade300 : _payPurple),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: _verifying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Verify payment', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton(
                  onPressed: _paying || _providers.isEmpty ? null : _pay,
                  style: FilledButton.styleFrom(
                    backgroundColor: _payPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: _paying
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Pay', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _payRow({required int index, required ({String id, String label}) provider}) {
    final sel = _method == index;
    final brand = _providerBrand(provider.id, provider.label);
    return InkWell(
      onTap: () => setState(() => _method = index),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: brand.color.withValues(alpha: 0.12),
                border: Border.all(color: sel ? brand.color : Colors.grey.shade200, width: 1.4),
              ),
              child: Icon(brand.icon, color: brand.color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(brand.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                  if (brand.subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(brand.subtitle!, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
                    ),
                ],
              ),
            ),
            _radioDot(sel),
          ],
        ),
      ),
    );
  }

  ({IconData icon, Color color, String name, String? subtitle}) _providerBrand(String id, String label) {
    final key = '$id $label'.toLowerCase();
    if (key.contains('paypal')) {
      return (icon: Icons.account_balance_wallet_rounded, color: const Color(0xFF0070BA), name: 'PayPal', subtitle: 'Pay with your PayPal balance or card');
    }
    if (key.contains('paystack')) {
      return (icon: Icons.bolt_rounded, color: const Color(0xFF00C3F7), name: 'Paystack', subtitle: 'Card, bank transfer & USSD');
    }
    if (key.contains('stripe') || key.contains('card')) {
      return (icon: Icons.credit_card_rounded, color: const Color(0xFF635BFF), name: label, subtitle: 'Debit or credit card');
    }
    if (key.contains('apple')) {
      return (icon: Icons.apple_rounded, color: _black, name: 'Apple Pay', subtitle: null);
    }
    if (key.contains('google')) {
      return (icon: Icons.account_balance_wallet_outlined, color: const Color(0xFF4285F4), name: 'Google Pay', subtitle: null);
    }
    if (key.contains('crypto') || key.contains('coin') || key.contains('usdt')) {
      return (icon: Icons.currency_bitcoin_rounded, color: const Color(0xFFF7931A), name: label, subtitle: 'Cryptocurrency');
    }
    return (icon: Icons.account_balance_wallet_outlined, color: _payPurple, name: label, subtitle: null);
  }

  Widget _radioDot(bool selected) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: selected ? _radioPurple : Colors.grey.shade400, width: 2),
      ),
      child: selected ? Center(child: Container(width: 10, height: 10, decoration: const BoxDecoration(shape: BoxShape.circle, color: _radioPurple))) : null,
    );
  }
}

class _ClipPreviewSheet extends StatelessWidget {
  const _ClipPreviewSheet();

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (ctx, scroll) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: scroll,
            padding: EdgeInsets.fromLTRB(0, 0, 0, 16 + bottom),
            children: [
              const SizedBox(height: 8),
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Material(
                    color: const Color(0xFFF2F2F2),
                    shape: const CircleBorder(),
                    child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded, color: _black, size: 22)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  height: 280,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.white, Colors.grey.shade900],
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(_kClipPreview, fit: BoxFit.cover),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 16,
                        right: 16,
                        bottom: 12,
                        child: Row(
                          children: [
                            const Icon(Icons.pause_rounded, color: Colors.white, size: 28),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    trackHeight: 4,
                                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                    activeTrackColor: Colors.white,
                                    inactiveTrackColor: Colors.white30,
                                    thumbColor: Colors.white,
                                  ),
                                  child: Slider(value: 0.35, onChanged: (_) {}),
                                ),
                              ),
                            ),
                            const Text('0:07', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(width: 8),
                            const Icon(Icons.volume_up_rounded, color: Colors.white, size: 24),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Text(
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black, height: 1.35),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(6)),
                      child: Text('Created by', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
                    ),
                    const SizedBox(width: 10),
                    const Text('Sammie', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFA020F0))),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class XliveWalletScreen extends StatefulWidget {
  const XliveWalletScreen({super.key});

  @override
  State<XliveWalletScreen> createState() => _XliveWalletScreenState();
}

class _XliveWalletScreenState extends State<XliveWalletScreen> with WidgetsBindingObserver {
  final _walletRepo = WalletRepository();
  final _currencyStore = WalletCurrencyStore.instance;
  List<WalletTransaction> _transactions = const [];
  bool _loadingTransactions = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthSession.instance.refreshWallet();
    _currencyStore.ensureLoaded();
    _loadTransactions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      AuthSession.instance.refreshWallet();
      _currencyStore.refreshRateIfStale();
      _loadTransactions();
    }
  }

  Future<void> _loadTransactions() async {
    setState(() => _loadingTransactions = true);
    try {
      final items = await _walletRepo.listTransactions(limit: 10);
      if (!mounted) return;
      setState(() {
        _transactions = items;
        _loadingTransactions = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTransactions = false);
    }
  }

  static const _packs = <({int coins, double usd})>[
    (coins: 100, usd: 1),
    (coins: 300, usd: 3),
    (coins: 500, usd: 5),
    (coins: 1000, usd: 10),
    (coins: 2500, usd: 25),
    (coins: 5000, usd: 50),
  ];

  String _packPrice(double usd) {
    return formatWalletMoney(usd, _currencyStore.currency, _currencyStore.usdToNgn);
  }

  void _openTopUp({
    required int coins,
    required double amountUsd,
    bool appleStoreSelected = false,
  }) {
    showXlivePaymentMethodSheet(
      context,
      coins: coins,
      amountUsd: amountUsd,
      fiatPrice: _packPrice(amountUsd),
      appleStoreSelected: appleStoreSelected,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AuthSession.instance, _currencyStore]),
      builder: (context, _) {
        final session = AuthSession.instance;
        final balance = session.walletBalance;
        final avatarUrl = session.user?.avatarUrl;
        final isNgn = _currencyStore.isNgn;
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
                  child: Row(
                    children: [
                      if (Navigator.canPop(context))
                        IconButton(onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: _black))
                      else
                        const SizedBox(width: 8),
                      const Expanded(
                        child: Text('XLive Wallet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _black)),
                      ),
                      _WalletCurrencyChip(
                        isNgn: isNgn,
                        onTap: () => _currencyStore.toggleCurrency(),
                      ),
                      const SizedBox(width: 10),
                      UserAvatar(radius: 20, imageUrl: avatarUrl),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: const Color(0xFF8A2DDC),
                    onRefresh: () async {
                      await Future.wait([
                        AuthSession.instance.refreshWallet(),
                        _currencyStore.refreshRateIfStale(force: true),
                        _loadTransactions(),
                      ]);
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _WalletBalanceCard(
                          balance: balance,
                          onTopUp: () => _openTopUp(
                            coins: _packs.first.coins,
                            amountUsd: _packs.first.usd,
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text('Top up your wallet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _black)),
                        const SizedBox(height: 4),
                        Text(
                          isNgn
                              ? 'Prices in Naira. Switch to USD anytime. Live rate ≈ ₦${_currencyStore.usdToNgn.round()}/USD.'
                              : 'Prices in US Dollars. Switch to Naira anytime. Live rate ≈ ₦${_currencyStore.usdToNgn.round()}/USD.',
                          style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600, height: 1.35),
                        ),
                        const SizedBox(height: 14),
                        for (var i = 0; i < _packs.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          _WalletPackCard(
                            coins: _packs[i].coins,
                            price: _packPrice(_packs[i].usd),
                            onTap: () => _openTopUp(
                              coins: _packs[i].coins,
                              amountUsd: _packs[i].usd,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            const Text('Recent activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black)),
                            const Spacer(),
                            if (_loadingTransactions && _transactions.isNotEmpty)
                              const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_loadingTransactions && _transactions.isEmpty) ...[
                          const _WalletTxSkeleton(),
                          const _WalletTxSkeleton(),
                          const _WalletTxSkeleton(),
                        ] else if (_transactions.isEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF9F9FB),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFEDEDED)),
                            ),
                            child: Column(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEFE6FD),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF8A2DDC), size: 22),
                                ),
                                const SizedBox(height: 10),
                                const Text('No transactions yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _black)),
                                const SizedBox(height: 4),
                                Text(
                                  'Coin top-ups, tips, and earnings will appear here.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        else
                          for (final tx in _transactions) _WalletTxRow(tx: tx),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: const MainBottomNav(selected: MainNavItem.home),
        );
      },
    );
  }
}

class _WalletTxSkeleton extends StatelessWidget {
  const _WalletTxSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEDED)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEBEBEB)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 120,
                  height: 14,
                  decoration: BoxDecoration(color: const Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(6)),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 70,
                  height: 10,
                  decoration: BoxDecoration(color: const Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(4)),
                ),
              ],
            ),
          ),
          Container(
            width: 45,
            height: 14,
            decoration: BoxDecoration(color: const Color(0xFFEBEBEB), borderRadius: BorderRadius.circular(6)),
          ),
        ],
      ),
    );
  }
}

class _WalletCurrencyChip extends StatelessWidget {
  const _WalletCurrencyChip({
    required this.isNgn,
    required this.onTap,
  });

  final bool isNgn;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3EDFA),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.currency_exchange_rounded, size: 16, color: Colors.grey.shade800),
              const SizedBox(width: 6),
              Text(
                isNgn ? '₦ NGN' : '\$ USD',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _black),
              ),
              const SizedBox(width: 4),
              Icon(Icons.swap_horiz_rounded, size: 15, color: Colors.grey.shade700),
            ],
          ),
        ),
      ),
    );
  }
}

class _WalletBalanceCard extends StatelessWidget {
  const _WalletBalanceCard({required this.balance, required this.onTopUp});

  final int? balance;
  final VoidCallback onTopUp;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8A2DDC), Color(0xFFE8487E)],
        ),
        boxShadow: const [BoxShadow(color: Color(0x338A2DDC), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Available balance', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFFD54F)),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                balance == null ? '—' : '$balance',
                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w900, height: 1),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 6),
                child: Text('coins', style: TextStyle(color: Colors.white70, fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: onTopUp,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF8A2DDC),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: const Text('Top up', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletTxRow extends StatelessWidget {
  const _WalletTxRow({required this.tx});

  final WalletTransaction tx;

  @override
  Widget build(BuildContext context) {
    final positive = tx.isCredit;
    final absolute = tx.amount.abs();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (positive ? const Color(0xFF2EAD5B) : const Color(0xFFE53935)).withValues(alpha: 0.12),
            ),
            child: Icon(
              positive ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: positive ? const Color(0xFF2EAD5B) : const Color(0xFFE53935),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tx.displayLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: _black),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${positive ? '+' : '-'}$absolute',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: positive ? const Color(0xFF2EAD5B) : const Color(0xFFE53935)),
          ),
        ],
      ),
    );
  }
}

class _WalletPackCard extends StatelessWidget {
  const _WalletPackCard({
    required this.coins,
    required this.price,
    required this.onTap,
  });

  final int coins;
  final String price;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFAFF),
            border: Border.all(color: const Color(0xFFEDE7F6)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFFFE082), Color(0xFFFFB300)],
                  ),
                ),
                child: const Icon(Icons.star_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$coins coins',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black),
                ),
              ),
              Text(
                price,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
