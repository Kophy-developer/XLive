import '../../../core/network/api_json.dart';

class GiftCatalogItem {
  const GiftCatalogItem({
    required this.id,
    required this.name,
    this.iconUrl,
    this.price = 0,
    this.cashValue = 0,
    this.animationUrl,
    this.active = true,
  });

  final String id;
  final String name;
  final String? iconUrl;
  final int price;
  final int cashValue;
  final String? animationUrl;
  final bool active;

  factory GiftCatalogItem.fromJson(Map<String, dynamic> json) {
    return GiftCatalogItem(
      id: ApiJson.pickString(json, ['id', '_id', 'giftId']) ?? '',
      name: ApiJson.pickString(json, ['name', 'title']) ?? 'Gift',
      iconUrl: ApiJson.pickString(json, ['iconUrl', 'icon', 'imageUrl']),
      price: ApiJson.pickInt(json, ['price', 'cost', 'coinPrice']),
      cashValue: ApiJson.pickInt(json, ['cashValue', 'payout', 'hostValue']),
      animationUrl: ApiJson.pickString(json, ['animationUrl', 'animation']),
      active: !ApiJson.boolValue(json['inactive']) && (json['active'] == null || ApiJson.boolValue(json['active'])),
    );
  }
}

class ReceivedGift {
  const ReceivedGift({
    required this.id,
    this.giftId,
    required this.name,
    this.iconUrl,
    this.quantity = 1,
    this.value = 0,
    this.cashValue = 0,
    this.senderId,
    this.senderName,
    this.senderAvatarUrl,
    this.context,
    this.createdAt,
  });

  final String id;
  final String? giftId;
  final String name;
  final String? iconUrl;
  final int quantity;
  final int value;
  final double cashValue;
  final String? senderId;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? context;
  final DateTime? createdAt;

  ReceivedGift copyWith({
    String? name,
    String? iconUrl,
    String? senderName,
    String? senderAvatarUrl,
  }) {
    return ReceivedGift(
      id: id,
      giftId: giftId,
      name: name ?? this.name,
      iconUrl: iconUrl ?? this.iconUrl,
      quantity: quantity,
      value: value,
      cashValue: cashValue,
      senderId: senderId,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      context: context,
      createdAt: createdAt,
    );
  }

  factory ReceivedGift.fromJson(Map<String, dynamic> json, {bool sent = false}) {
    final gift = ApiJson.map(json['gift']);
    final sender = sent
        ? (ApiJson.map(json['recipient']) ?? ApiJson.map(json['to']) ?? ApiJson.map(json['receiver']))
        : (ApiJson.map(json['sender']) ?? ApiJson.map(json['from']));
    return ReceivedGift(
      id: ApiJson.pickString(json, ['id', '_id', 'transactionId']) ?? '',
      giftId: ApiJson.pickString(json, ['giftId']) ??
          (gift == null ? null : ApiJson.pickString(gift, ['id', '_id', 'giftId'])),
      name: gift == null
          ? (ApiJson.pickString(json, ['giftName', 'name', 'title']) ?? 'Gift')
          : (ApiJson.pickString(gift, ['name', 'giftName', 'title']) ?? 'Gift'),
      iconUrl: gift == null
          ? ApiJson.pickString(json, ['iconUrl', 'icon', 'imageUrl'])
          : ApiJson.pickString(gift, ['iconUrl', 'icon', 'imageUrl']),
      quantity: ApiJson.pickInt(json, ['quantity', 'count'], fallback: 1),
      value: ApiJson.pickInt(json, ['value', 'points', 'coins', 'amount', 'amountPaid', 'amountCredited', 'cashValue']),
      cashValue: _toDouble(json, ['cashValue', 'usdValue', 'cash', 'payout', 'value']),
      senderId: ApiJson.pickString(json, sent ? ['recipientId', 'toUserId', 'receiverId'] : ['senderId', 'fromUserId']) ??
          (sender == null ? null : ApiJson.pickString(sender, ['id', '_id', 'userId'])),
      senderName: sender == null
          ? ApiJson.pickString(json, ['senderName', 'recipientName', 'username'])
          : ApiJson.pickString(sender, ['name', 'displayName', 'username', 'senderName', 'recipientName']),
      senderAvatarUrl: sender == null ? null : ApiJson.pickString(sender, ['avatarUrl', 'avatar']),
      context: ApiJson.pickString(json, ['streamTitle', 'context', 'source']),
      createdAt: DateTime.tryParse(ApiJson.pickString(json, ['createdAt', 'timestamp', 'date']) ?? ''),
    );
  }

  static double _toDouble(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final v = json[key];
      if (v is num) return v.toDouble();
      if (v is String) {
        final parsed = double.tryParse(v);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }
}

class ReceivedGiftsPage {
  const ReceivedGiftsPage({
    this.gifts = const [],
    this.totalValue = 0,
    this.totalCash = 0,
    this.totalCount = 0,
    this.currency = 'USD',
  });

  final List<ReceivedGift> gifts;
  final int totalValue;
  final double totalCash;
  final int totalCount;
  final String currency;

  factory ReceivedGiftsPage.fromJson(Map<String, dynamic> json, {bool sent = false}) {
    final data = ApiJson.dataMap(json);
    final gifts = ApiJson.listItems(json).map((j) => ReceivedGift.fromJson(j, sent: sent)).where((g) => g.id.isNotEmpty).toList();
    final summary = ApiJson.map(data['summary']) ?? data;
    var totalValue = ApiJson.pickInt(summary, ['totalValue', 'totalPoints', 'totalCoins', 'total']);
    var totalCash = ReceivedGift._toDouble(summary, ['totalCash', 'totalCashValue', 'totalUsd', 'totalEarnings']);
    final totalCount = ApiJson.pickInt(summary, ['totalDocs', 'totalCount', 'count', 'totalGifts'], fallback: gifts.length);
    if (totalValue == 0 && gifts.isNotEmpty) {
      totalValue = gifts.fold<int>(0, (sum, g) => sum + g.value);
    }
    if (totalCash == 0 && gifts.isNotEmpty) {
      totalCash = gifts.fold<double>(0, (sum, g) => sum + g.cashValue);
    }
    return ReceivedGiftsPage(
      gifts: gifts,
      totalValue: totalValue,
      totalCash: totalCash,
      totalCount: totalCount,
      currency: ApiJson.pickString(summary, ['currency']) ?? 'USD',
    );
  }
}

class GiftSendResult {
  const GiftSendResult({
    this.giftId,
    this.streamId,
    this.quantity = 1,
    this.senderBalance,
  });

  final String? giftId;
  final String? streamId;
  final int quantity;
  final int? senderBalance;

  factory GiftSendResult.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    return GiftSendResult(
      giftId: ApiJson.pickString(data, ['giftId', 'id']),
      streamId: ApiJson.pickString(data, ['streamId']),
      quantity: ApiJson.pickInt(data, ['quantity'], fallback: 1),
      senderBalance: ApiJson.pickInt(data, ['senderBalance', 'balance', 'walletBalance']),
    );
  }
}
