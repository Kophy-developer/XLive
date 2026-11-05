import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

enum WalletDisplayCurrency { ngn, usd }

const _storageKey = 'xlive_wallet_display_currency';
const _fallbackUsdToNgn = 1500.0;

class WalletCurrencyStore extends ChangeNotifier {
  WalletCurrencyStore._();
  static final WalletCurrencyStore instance = WalletCurrencyStore._();

  final _storage = const FlutterSecureStorage();
  WalletDisplayCurrency _currency = WalletDisplayCurrency.ngn;
  double _usdToNgn = _fallbackUsdToNgn;
  DateTime? _fetchedAt;
  bool _loaded = false;

  WalletDisplayCurrency get currency => _currency;
  double get usdToNgn => _usdToNgn;
  bool get isNgn => _currency == WalletDisplayCurrency.ngn;

  Future<void> ensureLoaded() async {
    if (_loaded) {
      await refreshRateIfStale();
      return;
    }
    _loaded = true;
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw == 'USD') {
        _currency = WalletDisplayCurrency.usd;
      } else {
        _currency = WalletDisplayCurrency.ngn;
      }
    } catch (_) {
      _currency = WalletDisplayCurrency.ngn;
    }
    notifyListeners();
    await refreshRateIfStale(force: true);
  }

  Future<void> setCurrency(WalletDisplayCurrency next) async {
    if (_currency == next) return;
    _currency = next;
    notifyListeners();
    try {
      await _storage.write(key: _storageKey, value: next == WalletDisplayCurrency.usd ? 'USD' : 'NGN');
    } catch (_) {}
  }

  Future<void> toggleCurrency() async {
    await setCurrency(isNgn ? WalletDisplayCurrency.usd : WalletDisplayCurrency.ngn);
  }

  Future<void> refreshRateIfStale({bool force = false}) async {
    final stale = _fetchedAt == null || DateTime.now().difference(_fetchedAt!).inMinutes >= 30;
    if (!force && !stale) return;
    final rate = await fetchUsdToNgnRate();
    if (rate > 100) {
      _usdToNgn = rate;
      _fetchedAt = DateTime.now();
      notifyListeners();
    }
  }
}

Future<double> fetchUsdToNgnRate() async {
  final endpoints = <Uri>[
    Uri.parse('https://open.er-api.com/v6/latest/USD'),
    Uri.parse('https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json'),
  ];
  for (final uri in endpoints) {
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) continue;
      final json = jsonDecode(res.body);
      if (json is! Map) continue;
      var rate = 0.0;
      final rates = json['rates'];
      if (rates is Map && rates['NGN'] != null) {
        rate = (rates['NGN'] as num).toDouble();
      } else {
        final usd = json['usd'];
        if (usd is Map && usd['ngn'] != null) {
          rate = (usd['ngn'] as num).toDouble();
        }
      }
      if (rate > 100) return rate;
    } catch (_) {}
  }
  return _fallbackUsdToNgn;
}

String formatWalletMoney(double amountUsd, WalletDisplayCurrency currency, double usdToNgn) {
  if (currency == WalletDisplayCurrency.usd) {
    final whole = amountUsd == amountUsd.roundToDouble();
    return '\$${whole ? amountUsd.toStringAsFixed(0) : amountUsd.toStringAsFixed(2)}';
  }
  final naira = (amountUsd * usdToNgn).round();
  return '₦${_withCommas(naira)}';
}

double ngnToUsd(double amountNgn, double usdToNgn) {
  if (usdToNgn <= 0) return 0;
  return amountNgn / usdToNgn;
}

String _withCommas(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    final fromEnd = s.length - i;
    buf.write(s[i]);
    if (fromEnd > 1 && fromEnd % 3 == 1) buf.write(',');
  }
  return buf.toString();
}
