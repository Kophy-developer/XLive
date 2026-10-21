import 'package:flutter/material.dart';

import '../../features/creator/creator_repository.dart';
import '../../features/creator/models/creator_models.dart';
import '../../core/network/api_friendly_messages.dart';

const _earningsPurple = Color(0xFF8E33FF);
const _black = Color(0xFF0A0A0A);

const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _longMonths = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

String _earningsPeriodTitle(DateTime now, int segment) {
  if (segment == 0) {
    return 'Today ${now.day} ${_shortMonths[now.month - 1]}';
  }
  if (segment == 1) {
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return '${monday.day} ${_shortMonths[monday.month - 1]} - ${sunday.day} ${_shortMonths[sunday.month - 1]}';
  }
  return _longMonths[now.month - 1];
}

Widget _earningsPillLabeledField({required String label, required Widget child}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        child,
      ],
    ),
  );
}

Widget _earningsRadioTrailing(bool selected) {
  return Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      border: Border.all(color: selected ? _earningsPurple : Colors.grey.shade400, width: 2),
      color: selected ? _earningsPurple : Colors.white,
    ),
    child: selected ? const Center(child: Icon(Icons.circle, size: 8, color: Colors.white)) : null,
  );
}

class EarningsWithdrawalScreen extends StatefulWidget {
  const EarningsWithdrawalScreen({super.key});

  @override
  State<EarningsWithdrawalScreen> createState() => _EarningsWithdrawalScreenState();
}

class _EarningsWithdrawalScreenState extends State<EarningsWithdrawalScreen> {
  final _creatorRepo = CreatorRepository();
  int _segment = 2;
  bool _hasPayoutMethod = false;
  bool _loading = true;
  CreatorEarnings? _earnings;
  List<WithdrawalMethod> _methods = const [];
  List<WithdrawalRecord> _withdrawals = const [];
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
      final earnings = await _creatorRepo.getEarnings(range: _range);
      final methods = await _creatorRepo.listWithdrawalMethods();
      final withdrawals = await _creatorRepo.listWithdrawals(limit: 20);
      if (!mounted) return;
      setState(() {
        _earnings = earnings;
        _methods = methods;
        _withdrawals = withdrawals;
        _hasPayoutMethod = methods.isNotEmpty;
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

  Future<void> _onWithdrawBalance() async {
    if (!_hasPayoutMethod) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => _NoPaymentMethodSheet(
          onAdd: () {
            Navigator.pop(ctx);
            _openAddWithdrawalMethod();
          },
        ),
      );
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WithdrawalCheckoutSheet(
        balance: _earnings?.balance ?? 0,
        method: _methods.isEmpty ? null : _methods.first,
        onConfirm: (amount) async {
          final method = _methods.firstWhere((m) => m.isDefault, orElse: () => _methods.first);
          await _creatorRepo.createWithdrawalRequest(amount: amount, methodId: method.id);
          if (!ctx.mounted) return;
          Navigator.pop(ctx);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Withdrawal requested')));
          await _load();
        },
      ),
    );
  }

  Future<void> _openAddWithdrawalMethod() async {
    final added = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(builder: (_) => const AddWithdrawalMethodScreen()),
    );
    if (!mounted || added != true) return;
    setState(() => _hasPayoutMethod = true);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final earnings = _earnings;

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
        title: const Text('Earnings & Withdrawal', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null && earnings == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      TextButton(onPressed: _load, child: const Text('Retry')),
                    ],
                  ),
                )
              : ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          Container(
            decoration: BoxDecoration(
              color: _earningsPurple,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Balance', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text('\$${(earnings?.balance ?? 0).toStringAsFixed(2)}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 6),
                      Text(
                        "You've withdrawn \$${(earnings?.totalWithdrawn ?? 0).toStringAsFixed(2)} to date",
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, thickness: 1, color: Colors.white.withValues(alpha: 0.35)),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _onWithdrawBalance,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Row(
                        children: [
                          Text('Withdraw my balance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.98))),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.95)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: _openAddWithdrawalMethod,
              child: Text('Manage withdrawal methods', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _earningsPeriodTitle(now, _segment),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: _black),
          ),
          const SizedBox(height: 16),
          _EarningsSegmentBar(
            segment: _segment,
            onChanged: (i) {
              setState(() => _segment = i);
              _load();
            },
          ),
          const SizedBox(height: 20),
          _EarningsBreakdownList(breakdown: earnings?.breakdown ?? const {}),
          if (_withdrawals.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Withdrawal history', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black)),
            const SizedBox(height: 12),
            for (final w in _withdrawals) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('\$${w.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(w.status ?? 'pending'),
                trailing: Text(
                  w.createdAt == null ? '' : '${w.createdAt!.month}/${w.createdAt!.day}/${w.createdAt!.year}',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
            ],
          ],
          if (_methods.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Withdrawal methods', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black)),
            const SizedBox(height: 8),
            for (final m in _methods)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(m.label),
                subtitle: m.accountNumber == null ? null : Text('•••• ${m.accountNumber!.length > 4 ? m.accountNumber!.substring(m.accountNumber!.length - 4) : m.accountNumber}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    try {
                      await _creatorRepo.deleteWithdrawalMethod(m.id);
                      await _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyApiMessage(e))),
                      );
                    }
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EarningsSegmentBar extends StatelessWidget {
  const _EarningsSegmentBar({required this.segment, required this.onChanged});

  final int segment;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final labels = ['Today', 'Week', 'Month'];
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(999),
      ),
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
                    boxShadow: sel
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sel ? _black : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _EarningsBreakdownList extends StatelessWidget {
  const _EarningsBreakdownList({required this.breakdown});

  final Map<String, double> breakdown;

  static const _rows = <({String label, IconData icon, List<String> keys})>[
    (label: 'Gifts', icon: Icons.card_giftcard_rounded, keys: ['streamgifts', 'gifts', 'gift']),
    (label: 'Live streams', icon: Icons.videocam_rounded, keys: ['streams', 'livestream', 'live', 'privatestreams']),
    (label: 'Clips', icon: Icons.play_circle_outline_rounded, keys: ['clips', 'clip']),
    (label: 'Posts', icon: Icons.image_outlined, keys: ['posts', 'post', 'videos', 'video']),
    (label: 'Subscriptions', icon: Icons.people_outline_rounded, keys: ['subscriptions', 'subscription']),
  ];

  double _amountFor(List<String> keys) {
    var total = 0.0;
    final matched = <String>{};
    for (final entry in breakdown.entries) {
      final normalized = entry.key.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
      for (final key in keys) {
        if (normalized == key || normalized.contains(key)) {
          if (matched.add(entry.key)) total += entry.value;
          break;
        }
      }
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      for (final row in _rows) (row.label, row.icon, _amountFor(row.keys)),
    ];
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) Divider(height: 1, thickness: 1, color: Colors.grey.shade100),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(items[i].$2, size: 20, color: _earningsPurple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      items[i].$1,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _black),
                    ),
                  ),
                  Text(
                    '\$${items[i].$3.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _black),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoPaymentMethodSheet extends StatelessWidget {
  const _NoPaymentMethodSheet({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 32),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.account_balance_wallet_outlined, size: 40, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 24),
          const Text('No Payment Method', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 10),
          Text(
            'Please add a payment method to withdraw seamlessly',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
          ),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: _earningsPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              child: const Text('Add Payment method', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WithdrawalCheckoutSheet extends StatelessWidget {
  const _WithdrawalCheckoutSheet({
    required this.balance,
    required this.method,
    required this.onConfirm,
  });

  final double balance;
  final WithdrawalMethod? method;
  final Future<void> Function(double amount) onConfirm;

  @override
  Widget build(BuildContext context) {
    final fee = balance * 0.1;
    final receive = balance - fee;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          const Text('Withdrawal Checkout', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 28),
          _checkoutRow('Withdrawal Amount', '\$${balance.toStringAsFixed(2)}'),
          const SizedBox(height: 18),
          _checkoutRow('Service Fee (10%)', '\$${fee.toStringAsFixed(2)}'),
          const SizedBox(height: 18),
          _checkoutRow('Amount you will receive', '\$${receive.toStringAsFixed(2)}'),
          if (method != null) ...[
            const SizedBox(height: 18),
            _checkoutRow('Method', method!.label),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: balance <= 0
                  ? null
                  : () async {
                      try {
                        await onConfirm(balance);
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(friendlyApiMessage(e))),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: _earningsPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              child: const Text('Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _checkoutRow(String label, String value) {
    return Row(
      children: [
        Expanded(child: Text(label, style: TextStyle(fontSize: 15, color: Colors.grey.shade600, fontWeight: FontWeight.w400))),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
      ],
    );
  }
}

class AddWithdrawalMethodScreen extends StatelessWidget {
  const AddWithdrawalMethodScreen({super.key});

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
        title: const Text('Add Withdrawal Method', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: _black)),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              children: [
                _MethodCard(
                  bgCard: const Color(0xFFF5F5F5),
                  icon: Icons.account_balance_outlined,
                  title: 'Online Banking',
                  subtitle: 'Transfer direct to your bank',
                  trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  onTap: () => _showAddBankSheet(context, updateStyle: false),
                ),
                const SizedBox(height: 12),
                _MethodCard(
                  bgCard: const Color(0xFFF5F5F5),
                  iconWidget: const Text('₿', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: _black)),
                  title: 'Crypto',
                  subtitle: 'Withdraw easily to your crypto wallet',
                  trailing: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                  onTap: () => _showCryptoSheet(context),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => _showAddBankSheet(context, updateStyle: true),
                    child: Text('Update bank transfer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(28, 0, 28, 24 + MediaQuery.paddingOf(context).bottom),
            child: Text(
              'For any withdrawal transaction you will be charged 15% service fee.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _showAddBankSheet(BuildContext context, {required bool updateStyle}) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddBankTransferSheet(updateStyle: updateStyle),
    );
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }

  static Future<void> _showCryptoSheet(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _CryptoWithdrawSheet(),
    );
    if (ok == true && context.mounted) Navigator.pop(context, true);
  }
}

class _MethodCard extends StatelessWidget {
  const _MethodCard({
    required this.bgCard,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
    this.icon,
    this.iconWidget,
  });

  final Color bgCard;
  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bgCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: iconWidget ??
                    Icon(icon, color: _black, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _black)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.3)),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _AddBankTransferSheet extends StatefulWidget {
  const _AddBankTransferSheet({required this.updateStyle});

  final bool updateStyle;

  @override
  State<_AddBankTransferSheet> createState() => _AddBankTransferSheetState();
}

class _AddBankTransferSheetState extends State<_AddBankTransferSheet> {
  final _creatorRepo = CreatorRepository();
  final _nameCtrl = TextEditingController();
  final _acctCtrl = TextEditingController();
  String _bank = 'Opay';
  bool _busy = false;

  static const _banks = ['Opay', 'Access Bank', 'Zenith Bank', 'GTBank'];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _acctCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBank() async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Select Bank', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey.shade800)),
            const SizedBox(height: 8),
            for (final b in _banks)
              ListTile(
                title: Text(b),
                onTap: () => Navigator.pop(ctx, b),
              ),
          ],
        ),
      ),
    );
    if (v != null) setState(() => _bank = v);
  }

  Future<void> _submit() async {
    setState(() => _busy = true);
    try {
      await _creatorRepo.createBankWithdrawalMethod(
        accountName: _nameCtrl.text.trim(),
        bankName: _bank,
        accountNumber: _acctCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + padBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Text('Add a Bank Transfer', style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: _black)),
              const SizedBox(height: 12),
              Text(
                'Get access to your funds in 3-5 business days with no fees. Incorrect information can mean a delay in receiving funds or fees.',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.45),
              ),
              const SizedBox(height: 24),
              _earningsPillLabeledField(
                label: 'Full Name',
                child: TextField(
                  controller: _nameCtrl,
                  style: const TextStyle(fontSize: 16, color: _black),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ),
              const SizedBox(height: 14),
              _earningsPillLabeledField(
                label: 'Account Number',
                child: TextField(
                  controller: _acctCtrl,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 16, color: _black),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _pickBank,
                  borderRadius: BorderRadius.circular(24),
                  child: _earningsPillLabeledField(
                    label: 'Bank Name',
                    child: Row(
                      children: [
                        Expanded(child: Text(_bank, style: const TextStyle(fontSize: 16, color: _black))),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              if (widget.updateStyle)
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _submit,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _black,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Update Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: _busy ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: _earningsPurple,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      elevation: 0,
                    ),
                    child: const Text('Submit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CryptoWithdrawSheet extends StatefulWidget {
  const _CryptoWithdrawSheet();

  @override
  State<_CryptoWithdrawSheet> createState() => _CryptoWithdrawSheetState();
}

class _CryptoWithdrawSheetState extends State<_CryptoWithdrawSheet> {
  final _walletCtrl = TextEditingController(text: '0x742d35Cc6634C0532925a3b844Bc45e1Bad6C889');
  String _coin = 'USDT Tether';
  String _network = 'BNB Smart Chain (BEP20)';

  @override
  void dispose() {
    _walletCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectCoin() async {
    final coins = ['USDT Tether', 'USDC USD Cion', 'ETH Ethereum'];
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SelectRadioSheet(
        title: 'Select Coin',
        options: coins,
        selected: _coin,
        onProceed: (s) => Navigator.pop(ctx, s),
      ),
    );
    if (v != null) setState(() => _coin = v);
  }

  Future<void> _selectNetwork() async {
    final nets = ['BNB Smart Chain (BEP20)', 'Ethereum (ERC20)', 'Tron (TRC20)'];
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SelectRadioSheet(
        title: 'Select Network',
        options: nets,
        selected: _network,
        onProceed: (s) => Navigator.pop(ctx, s),
      ),
    );
    if (v != null) setState(() => _network = v);
  }

  @override
  Widget build(BuildContext context) {
    final padBottom = MediaQuery.viewInsetsOf(context).bottom + MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + padBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
              const Text('Crypto', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: _black)),
              const SizedBox(height: 8),
              Text(
                'Select wallet address, coin and network you want to use',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 22),
              _earningsPillLabeledField(
                label: 'Wallet Address',
                child: TextField(
                  controller: _walletCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14, color: _black),
                  decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectCoin,
                  borderRadius: BorderRadius.circular(24),
                  child: _earningsPillLabeledField(
                    label: 'Coin',
                    child: Row(
                      children: [
                        Expanded(child: Text(_coin, style: const TextStyle(fontSize: 16, color: _black))),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _selectNetwork,
                  borderRadius: BorderRadius.circular(24),
                  child: _earningsPillLabeledField(
                    label: 'Network',
                    child: Row(
                      children: [
                        Expanded(child: Text(_network, style: const TextStyle(fontSize: 15, color: _black))),
                        Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey.shade600),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _black,
                    side: const BorderSide(color: _black, width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  ),
                  child: const Text('Disconnect & Update', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'The Fee and how quickly you receive fund is depending on the Network selected.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectRadioSheet extends StatefulWidget {
  const _SelectRadioSheet({required this.title, required this.options, required this.selected, required this.onProceed});

  final String title;
  final List<String> options;
  final String selected;
  final void Function(String) onProceed;

  @override
  State<_SelectRadioSheet> createState() => _SelectRadioSheetState();
}

class _SelectRadioSheetState extends State<_SelectRadioSheet> {
  late String _sel;

  @override
  void initState() {
    super.initState();
    _sel = widget.selected;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 24 + MediaQuery.paddingOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Text(widget.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _black)),
          const SizedBox(height: 16),
          for (final o in widget.options)
            InkWell(
              onTap: () => setState(() => _sel = o),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Expanded(child: Text(o, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: _black))),
                    _earningsRadioTrailing(_sel == o),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton(
              onPressed: () => widget.onProceed(_sel),
              style: FilledButton.styleFrom(
                backgroundColor: _earningsPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                elevation: 0,
              ),
              child: const Text('Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

}
