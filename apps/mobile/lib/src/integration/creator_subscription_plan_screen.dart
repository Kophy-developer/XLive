import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/session/auth_session.dart';
import '../../features/subscriptions/models/subscription_models.dart';
import '../../features/subscriptions/subscriptions_repository.dart';
import '../social/social_api_screens.dart';
import '../../core/network/api_friendly_messages.dart';

const _purple = Color(0xFF8A2DDC);
const _sky = Color(0xFF35D3FB);
const _black = Color(0xFF0A0A0A);
const _light = Color(0xFFF6F6F6);

class CreatorSubscriptionPlanScreen extends StatefulWidget {
  const CreatorSubscriptionPlanScreen({super.key, required this.creatorId});

  final String creatorId;

  @override
  State<CreatorSubscriptionPlanScreen> createState() => _CreatorSubscriptionPlanScreenState();
}

class _CreatorSubscriptionPlanScreenState extends State<CreatorSubscriptionPlanScreen> {
  final _subscriptionsRepo = SubscriptionsRepository();
  final _priceCtrl = TextEditingController();
  CreatorSubscriptionPlan? _plan;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final plan = await _subscriptionsRepo.getPlan(widget.creatorId);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _priceCtrl.text = plan.monthlyPrice > 0 ? '${plan.monthlyPrice}' : '';
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

  Future<void> _save() async {
    final parsed = int.tryParse(_priceCtrl.text.trim());
    if (parsed == null || parsed < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid monthly price in coins')));
      return;
    }
    setState(() => _saving = true);
    try {
      final plan = await _subscriptionsRepo.updateMonthlyPrice(
        creatorId: widget.creatorId,
        monthlyPrice: parsed,
      );
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subscription plan updated')));
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyApiMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthSession.instance.user;
    final isOwnPlan = me?.id == widget.creatorId;
    return XLiveSubpage(
      title: 'Subscription plan',
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : _error != null
              ? _PlanErrorBody(message: _error!, onRetry: _load)
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _light,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x1A0A0A0A)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Monthly subscription', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: _black)),
                            const SizedBox(height: 8),
                            Text(
                              isOwnPlan
                                  ? 'Set the monthly price in coins that fans pay to subscribe to your content.'
                                  : 'Creator subscription pricing in coins.',
                              style: TextStyle(color: Colors.grey.shade700, height: 1.4),
                            ),
                            if (_plan != null && _plan!.subscriberCount > 0) ...[
                              const SizedBox(height: 12),
                              Text(
                                '${_plan!.subscriberCount} subscribers',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: _purple),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _priceCtrl,
                        enabled: isOwnPlan && !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: InputDecoration(
                          labelText: 'Monthly price (coins)',
                          suffixText: 'coins',
                          filled: true,
                          fillColor: _light,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (isOwnPlan)
                        SizedBox(
                          height: 52,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_purple, _sky]),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                              onPressed: _saving ? null : _save,
                              child: _saving
                                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Text('Save plan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                            ),
                          ),
                        )
                      else
                        Text(
                          'Only the creator can edit this plan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                    ],
                  ),
                ),
    );
  }
}

class _PlanErrorBody extends StatelessWidget {
  const _PlanErrorBody({required this.message, required this.onRetry});

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
