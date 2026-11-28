import '../../../core/network/api_json.dart';

class WalletInfo {
  const WalletInfo({
    this.balance = 0,
    this.currency = 'USD',
    this.pendingBalance = 0,
  });

  final int balance;
  final String currency;
  final int pendingBalance;

  factory WalletInfo.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    return WalletInfo(
      balance: ApiJson.pickInt(data, ['balance', 'coinBalance', 'coins', 'availableBalance']),
      currency: ApiJson.pickString(data, ['currency']) ?? 'USD',
      pendingBalance: ApiJson.pickInt(data, ['pendingBalance', 'pending']),
    );
  }
}

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    this.type,
    this.amount = 0,
    this.description,
    this.createdAt,
  });

  final String id;
  final String? type;
  final int amount;
  final String? description;
  final DateTime? createdAt;

  bool get isCredit {
    final raw = (type ?? '').toLowerCase();
    return raw.contains('credit') || raw.contains('fund') || raw.contains('deposit') || raw.contains('topup') || raw.contains('top_up');
  }

  String get displayLabel {
    final desc = description?.trim();
    if (desc != null && desc.isNotEmpty) return desc;
    return isCredit ? 'Wallet Top up' : 'Payment';
  }

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      type: ApiJson.pickString(json, ['type', 'kind', 'action']),
      amount: ApiJson.pickInt(json, ['amount', 'coins', 'value']),
      description: ApiJson.pickString(json, ['description', 'label', 'note', 'reason']),
      createdAt: DateTime.tryParse(ApiJson.pickString(json, ['createdAt', 'timestamp']) ?? ''),
    );
  }
}

class FundPaymentResult {
  const FundPaymentResult({
    this.paymentId,
    this.status,
    this.provider,
    this.authorizationUrl,
    this.approveUrl,
    this.clientSecret,
    this.reference,
    this.orderId,
    this.amountUsd = 0,
  });

  final String? paymentId;
  final String? status;
  final String? provider;
  final String? authorizationUrl;
  final String? approveUrl;
  final String? clientSecret;
  final String? reference;
  final String? orderId;
  final int amountUsd;

  String? get checkoutUrl {
    final auth = authorizationUrl?.trim();
    if (auth != null && auth.isNotEmpty) return auth;
    final approve = approveUrl?.trim();
    if (approve != null && approve.isNotEmpty) return approve;
    return null;
  }

  factory FundPaymentResult.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final client = ApiJson.map(data['clientPayload']) ?? const <String, dynamic>{};
    return FundPaymentResult(
      paymentId: ApiJson.pickString(data, ['paymentId', 'id']),
      status: ApiJson.pickString(data, ['status']),
      provider: ApiJson.pickString(data, ['provider']),
      authorizationUrl: ApiJson.pickString(data, ['authorizationUrl', 'checkoutUrl', 'redirectUrl']) ??
          ApiJson.pickString(client, ['authorizationUrl', 'checkoutUrl', 'redirectUrl']),
      approveUrl: ApiJson.pickString(data, ['approveUrl']) ?? ApiJson.pickString(client, ['approveUrl']),
      clientSecret: ApiJson.pickString(data, ['clientSecret', 'paymentIntentClientSecret']),
      reference: ApiJson.pickString(data, ['reference', 'gatewayReference']) ??
          ApiJson.pickString(client, ['reference']),
      orderId: ApiJson.pickString(data, ['orderId']) ?? ApiJson.pickString(client, ['orderId']),
      amountUsd: ApiJson.pickInt(data, ['amountUsd', 'amount']),
    );
  }
}
