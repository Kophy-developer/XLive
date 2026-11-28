import '../../../core/network/api_json.dart';

class CreatorEarnings {
  const CreatorEarnings({
    this.balance = 0,
    this.totalWithdrawn = 0,
    this.totalEarnedInRange = 0,
    this.breakdown = const {},
  });

  final double balance;
  final double totalWithdrawn;
  final double totalEarnedInRange;
  final Map<String, double> breakdown;

  factory CreatorEarnings.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final breakdownRaw = data['breakdown'] ?? data['bySource'] ?? data['sources'];
    final breakdown = <String, double>{};
    if (breakdownRaw is Map) {
      breakdownRaw.forEach((key, value) {
        if (value is num) breakdown[key.toString()] = value.toDouble();
      });
    } else if (breakdownRaw is List) {
      for (final item in breakdownRaw) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final label = ApiJson.pickString(map, ['label', 'name', 'source', 'type']) ?? 'other';
        breakdown[label] = _doubleValue(map['amount'] ?? map['value'] ?? map['total']);
      }
    }
    return CreatorEarnings(
      balance: _doubleValue(data['balance'] ?? data['availableBalance'] ?? data['totalBalance']),
      totalWithdrawn: _doubleValue(data['totalWithdrawn'] ?? data['withdrawnToDate'] ?? data['lifetimeWithdrawn']),
      totalEarnedInRange: _doubleValue(data['totalEarnedInRange'] ?? data['earnedInRange'] ?? data['periodEarnings']),
      breakdown: breakdown,
    );
  }

  static double _doubleValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }
}

class WithdrawalMethod {
  const WithdrawalMethod({
    required this.id,
    this.type,
    this.accountName,
    this.bankName,
    this.accountNumber,
    this.isDefault = false,
  });

  final String id;
  final String? type;
  final String? accountName;
  final String? bankName;
  final String? accountNumber;
  final bool isDefault;

  String get label {
    if (bankName != null && bankName!.isNotEmpty) return bankName!;
    if (type != null && type!.isNotEmpty) return type!;
    return 'Withdrawal method';
  }

  factory WithdrawalMethod.fromJson(Map<String, dynamic> json) {
    return WithdrawalMethod(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      type: ApiJson.pickString(json, ['type']),
      accountName: ApiJson.pickString(json, ['accountName', 'name']),
      bankName: ApiJson.pickString(json, ['bankName', 'provider']),
      accountNumber: ApiJson.pickString(json, ['accountNumber', 'accountLast4', 'last4']),
      isDefault: ApiJson.boolValue(json['isDefault']) || ApiJson.boolValue(json['default']),
    );
  }
}

class CreatorAnalytics {
  const CreatorAnalytics({this.metrics = const {}});

  final Map<String, num> metrics;

  num exact(String key) {
    final direct = metrics[key];
    if (direct != null) return direct;
    final lower = key.toLowerCase();
    for (final entry in metrics.entries) {
      if (entry.key.toLowerCase() == lower) return entry.value;
    }
    return 0;
  }

  num getMetric(String key) => exact(key);

  num get likes => exact('likes');
  num get comments => exact('comments');
  num get shares => exact('shares');
  num get profileViews => exact('profileViews');
  num get postViews => exact('postViews');
  num get clipViews => exact('clipViews');
  num get liveStreams => exact('liveStreams');
  num get streamJoins => exact('streamJoins');
  num get watchTimeSeconds => exact('watchTimeSeconds');
  num get giftRevenue => exact('giftRevenue');
  num get clipsMetric => clipViews != 0 ? clipViews : exact('clips');

  factory CreatorAnalytics.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    final metrics = <String, num>{};
    void absorb(Map<String, dynamic> map) {
      map.forEach((key, value) {
        if (value is num) metrics[key] = value;
        if (value is Map) absorb(Map<String, dynamic>.from(value));
      });
    }
    absorb(data);
    final breakdown = data['breakdown'] ?? data['metrics'] ?? data['stats'];
    if (breakdown is Map) absorb(Map<String, dynamic>.from(breakdown));
    return CreatorAnalytics(metrics: metrics);
  }
}

class CreatorSettings {
  const CreatorSettings({
    this.userId,
    this.privateStreamPricePerMinute = 0,
    this.allowViewerTalkBack = false,
  });

  final String? userId;
  final double privateStreamPricePerMinute;
  final bool allowViewerTalkBack;

  Map<String, dynamic> toPatchJson() {
    return {
      'privateStreamPricePerMinute': privateStreamPricePerMinute,
      'allowViewerTalkBack': allowViewerTalkBack,
    };
  }

  factory CreatorSettings.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    return CreatorSettings(
      userId: ApiJson.pickString(data, ['userId', 'id', '_id']),
      privateStreamPricePerMinute: CreatorEarnings._doubleValue(data['privateStreamPricePerMinute']),
      allowViewerTalkBack: ApiJson.boolValue(data['allowViewerTalkBack']),
    );
  }
}

class WithdrawalRecord {
  const WithdrawalRecord({
    required this.id,
    this.amount = 0,
    this.status,
    this.createdAt,
    this.methodId,
  });

  final String id;
  final double amount;
  final String? status;
  final DateTime? createdAt;
  final String? methodId;

  factory WithdrawalRecord.fromJson(Map<String, dynamic> json) {
    return WithdrawalRecord(
      id: ApiJson.pickString(json, ['id', '_id']) ?? '',
      amount: CreatorEarnings._doubleValue(json['amount']),
      status: ApiJson.pickString(json, ['status', 'state']),
      createdAt: DateTime.tryParse(ApiJson.pickString(json, ['createdAt', 'timestamp']) ?? ''),
      methodId: ApiJson.pickString(json, ['methodId', 'withdrawalMethodId']),
    );
  }
}
