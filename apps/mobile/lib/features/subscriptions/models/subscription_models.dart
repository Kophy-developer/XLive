import '../../../core/network/api_json.dart';

class CreatorSubscriptionPlan {
  const CreatorSubscriptionPlan({
    required this.creatorId,
    this.monthlyPrice = 0,
    this.currency,
    this.isActive = false,
    this.subscriberCount = 0,
  });

  final String creatorId;
  final int monthlyPrice;
  final String? currency;
  final bool isActive;
  final int subscriberCount;

  bool get hasSubscribablePlan => monthlyPrice > 0 && isActive;

  factory CreatorSubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return CreatorSubscriptionPlan(
      creatorId: ApiJson.pickString(json, ['creatorId', 'userId', 'id', '_id']) ?? '',
      monthlyPrice: ApiJson.pickInt(json, ['monthlyPrice', 'price', 'amount']),
      currency: ApiJson.pickString(json, ['currency']),
      isActive: ApiJson.boolValue(json['isActive']) || ApiJson.boolValue(json['active']),
      subscriberCount: ApiJson.pickInt(json, ['subscriberCount', 'subscribers', 'totalSubscribers']),
    );
  }
}

class MySubscription {
  const MySubscription({
    required this.id,
    required this.creatorId,
    this.creatorName,
    this.monthlyPrice = 0,
    this.status,
    this.renewsAt,
  });

  final String id;
  final String creatorId;
  final String? creatorName;
  final int monthlyPrice;
  final String? status;
  final DateTime? renewsAt;

  factory MySubscription.fromJson(Map<String, dynamic> json) {
    final creator = ApiJson.map(json['creator']) ?? ApiJson.map(json['user']);
    return MySubscription(
      id: ApiJson.pickString(json, ['id', '_id', 'subscriptionId']) ?? '',
      creatorId: creator == null
          ? ApiJson.pickString(json, ['creatorId', 'userId']) ?? ''
          : ApiJson.pickString(creator, ['id', '_id']) ?? '',
      creatorName: creator == null ? null : ApiJson.pickString(creator, ['displayName', 'username', 'name']),
      monthlyPrice: ApiJson.pickInt(json, ['monthlyPrice', 'price', 'amount']),
      status: ApiJson.pickString(json, ['status', 'state']),
      renewsAt: DateTime.tryParse(ApiJson.pickString(json, ['renewsAt', 'renewalDate', 'expiresAt']) ?? ''),
    );
  }
}
