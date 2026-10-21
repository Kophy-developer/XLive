import '../../../core/network/api_json.dart';

class ClipSummary {
  const ClipSummary({
    required this.id,
    this.title,
    this.description,
    this.thumbnailUrl,
    this.price = 0,
    this.isCollectible = false,
    this.isArchived = false,
    this.soldCount = 0,
    this.maxSupply = 0,
    this.creatorId,
    this.creatorName,
    this.viewCount = 0,
    this.likeCount = 0,
    this.canDelete = true,
    this.canArchive = false,
    this.canEdit = true,
  });

  final String id;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final int price;
  final bool isCollectible;
  final bool isArchived;
  final int soldCount;
  final int maxSupply;
  final String? creatorId;
  final String? creatorName;
  final int viewCount;
  final int likeCount;
  final bool canDelete;
  final bool canArchive;
  final bool canEdit;

  int get remainingSupply {
    if (maxSupply <= 0) return 0;
    final left = maxSupply - soldCount;
    return left < 0 ? 0 : left;
  }

  factory ClipSummary.fromJson(Map<String, dynamic> json) {
    final creator = ApiJson.map(json['creator']) ?? ApiJson.map(json['user']);
    final supply = ApiJson.map(json['supply']);
    final management = ApiJson.map(json['management']);
    final kind = ApiJson.pickString(json, ['kind', 'type'])?.toLowerCase();
    final status = ApiJson.pickString(json, ['status', 'state'])?.toLowerCase();
    final sold = supply == null
        ? ApiJson.pickInt(json, ['soldCount', 'sold', 'editionsSold'])
        : ApiJson.pickInt(supply, ['soldCount', 'sold'], fallback: ApiJson.pickInt(json, ['soldCount', 'sold']));
    final max = supply == null
        ? ApiJson.pickInt(json, ['maxSupply', 'supply', 'editionLimit'])
        : ApiJson.pickInt(supply, ['maxSupply'], fallback: ApiJson.pickInt(json, ['maxSupply']));
    final archived = ApiJson.boolValue(json['isArchived']) ||
        ApiJson.boolValue(json['archived']) ||
        status == 'archived' ||
        (supply != null && ApiJson.boolValue(supply['archived']));
    return ClipSummary(
      id: ApiJson.pickString(json, ['id', '_id', 'clipId']) ?? '',
      title: ApiJson.pickString(json, ['title', 'caption', 'name']),
      description: ApiJson.pickString(json, ['description', 'caption']),
      thumbnailUrl: ApiJson.pickString(json, ['thumbnailUrl', 'thumbnail', 'coverUrl', 'previewUrl', 'mediaUrl']),
      price: ApiJson.pickInt(json, ['price', 'amount', 'unlockPrice']),
      isCollectible: ApiJson.boolValue(json['isCollectible']) ||
          ApiJson.boolValue(json['collectible']) ||
          kind == 'collectible',
      isArchived: archived,
      soldCount: sold,
      maxSupply: max,
      creatorId: creator == null ? ApiJson.pickString(json, ['creatorId', 'userId']) : ApiJson.pickString(creator, ['id', '_id']),
      creatorName: creator == null ? null : ApiJson.pickString(creator, ['displayName', 'username', 'name']),
      viewCount: ApiJson.pickInt(json, ['viewCount', 'views']),
      likeCount: ApiJson.pickInt(json, ['likeCount', 'likes']),
      canDelete: management == null ? sold <= 0 : ApiJson.boolValue(management['canDelete'], fallback: sold <= 0),
      canArchive: management == null ? !archived && sold > 0 : ApiJson.boolValue(management['canArchive']),
      canEdit: management == null ? !archived : ApiJson.boolValue(management['canEdit'], fallback: true),
    );
  }
}

class ClipOwner {
  const ClipOwner({
    required this.userId,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.ownershipId,
    this.editionNumber = 0,
    this.listedForResale = false,
    this.purchasePrice = 0,
  });

  final String userId;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? ownershipId;
  final int editionNumber;
  final bool listedForResale;
  final int purchasePrice;

  String get name => displayName ?? username ?? 'Collector';

  factory ClipOwner.fromJson(Map<String, dynamic> json) {
    final user = ApiJson.map(json['user']) ?? ApiJson.map(json['owner']);
    return ClipOwner(
      userId: user == null
          ? ApiJson.pickString(json, ['userId', 'ownerId', 'id', '_id']) ?? ''
          : ApiJson.pickString(user, ['id', '_id', 'userId']) ?? '',
      displayName: user == null
          ? ApiJson.pickString(json, ['displayName', 'name'])
          : ApiJson.pickString(user, ['displayName', 'name']),
      username: user == null ? ApiJson.pickString(json, ['username']) : ApiJson.pickString(user, ['username']),
      avatarUrl: user == null
          ? ApiJson.pickString(json, ['avatarUrl', 'avatar'])
          : ApiJson.pickString(user, ['avatarUrl', 'avatar']),
      ownershipId: ApiJson.pickString(json, ['ownershipId', 'id', '_id']),
      editionNumber: ApiJson.pickInt(json, ['editionNumber', 'edition']),
      listedForResale: ApiJson.boolValue(json['listedForResale']),
      purchasePrice: ApiJson.pickInt(json, ['purchasePrice', 'presentValue', 'originalMintPrice']),
    );
  }
}

class OwnedClip {
  const OwnedClip({
    required this.ownershipId,
    required this.clipId,
    this.title,
    this.thumbnailUrl,
    this.purchasePrice = 0,
    this.originalMintPrice = 0,
    this.resalePrice,
    this.listedForResale = false,
    this.editionNumber = 0,
  });

  final String ownershipId;
  final String clipId;
  final String? title;
  final String? thumbnailUrl;
  final int purchasePrice;
  final int originalMintPrice;
  final int? resalePrice;
  final bool listedForResale;
  final int editionNumber;

  factory OwnedClip.fromJson(Map<String, dynamic> json) {
    final ownership = ApiJson.map(json['ownership']) ?? json;
    final clip = ApiJson.map(json['clip']) ?? json;
    final listed = ApiJson.boolValue(ownership['listedForResale']);
    final resale = listed ? ApiJson.pickInt(ownership, ['resalePrice', 'price', 'amount']) : null;
    return OwnedClip(
      ownershipId: ApiJson.pickString(ownership, ['ownershipId', 'id', '_id']) ?? '',
      clipId: ApiJson.pickString(clip, ['clipId', 'id', '_id']) ??
          ApiJson.pickString(ownership, ['clipId']) ??
          '',
      title: ApiJson.pickString(clip, ['title', 'caption', 'name']),
      thumbnailUrl: ApiJson.pickString(clip, ['thumbnailUrl', 'thumbnail', 'coverUrl', 'previewUrl']),
      purchasePrice: ApiJson.pickInt(ownership, ['purchasePrice', 'presentValue']),
      originalMintPrice: ApiJson.pickInt(ownership, ['originalMintPrice']),
      resalePrice: resale == 0 ? null : resale,
      listedForResale: listed,
      editionNumber: ApiJson.pickInt(ownership, ['editionNumber', 'edition']),
    );
  }
}

class ClipMarketplaceListing {
  const ClipMarketplaceListing({
    required this.ownershipId,
    required this.clipId,
    this.title,
    this.thumbnailUrl,
    this.price = 0,
    this.sellerName,
    this.sellerId,
    this.editionNumber = 0,
  });

  final String ownershipId;
  final String clipId;
  final String? title;
  final String? thumbnailUrl;
  final int price;
  final String? sellerName;
  final String? sellerId;
  final int editionNumber;

  factory ClipMarketplaceListing.fromJson(Map<String, dynamic> json) {
    final listing = ApiJson.map(json['listing']) ?? json;
    final clip = ApiJson.map(json['clip']) ?? listing;
    final seller = ApiJson.map(json['seller']) ?? ApiJson.map(json['owner']) ?? ApiJson.map(listing['owner']);
    return ClipMarketplaceListing(
      ownershipId: ApiJson.pickString(listing, ['ownershipId', 'id', '_id']) ?? '',
      clipId: ApiJson.pickString(clip, ['clipId', 'id', '_id']) ??
          ApiJson.pickString(listing, ['clipId']) ??
          '',
      title: ApiJson.pickString(clip, ['title', 'caption', 'name']),
      thumbnailUrl: ApiJson.pickString(clip, ['thumbnailUrl', 'thumbnail', 'coverUrl', 'previewUrl']),
      price: ApiJson.pickInt(listing, ['resalePrice', 'price', 'amount']),
      sellerName: seller == null
          ? ApiJson.pickString(json, ['sellerName', 'ownerName'])
          : ApiJson.pickString(seller, ['displayName', 'username', 'name']),
      sellerId: seller == null
          ? ApiJson.pickString(listing, ['sellerId', 'ownerId', 'userId'])
          : ApiJson.pickString(seller, ['id', '_id']),
      editionNumber: ApiJson.pickInt(listing, ['editionNumber', 'edition']),
    );
  }
}

class ClipEarnings {
  const ClipEarnings({
    this.total = 0,
    this.salesCount = 0,
    this.breakdown = const {},
  });

  final double total;
  final int salesCount;
  final Map<String, double> breakdown;

  factory ClipEarnings.fromJson(Map<String, dynamic> json, {String? clipId}) {
    final data = ApiJson.dataMap(json);
    final breakdown = <String, double>{};
    final raw = data['breakdown'] ?? data['sources'];
    if (raw is Map) {
      raw.forEach((key, value) {
        if (value is num) breakdown[key.toString()] = value.toDouble();
      });
    }
    final byClip = ApiJson.map(data['byClip']);
    var total = _doubleValue(data['total'] ?? data['earnings'] ?? data['amount']);
    var salesCount = ApiJson.pickInt(data, ['salesCount', 'count', 'soldCount']);
    if (clipId != null && byClip != null) {
      final entry = ApiJson.map(byClip[clipId]);
      if (entry != null) {
        total = _doubleValue(entry['revenue'] ?? entry['total'] ?? entry['amount'] ?? total);
        salesCount = ApiJson.pickInt(entry, ['count', 'salesCount', 'soldCount'], fallback: salesCount);
        breakdown['Primary sales'] = total;
      }
    } else if (byClip != null) {
      byClip.forEach((key, value) {
        final entry = ApiJson.map(value);
        if (entry != null) {
          breakdown[key.toString()] = _doubleValue(entry['revenue'] ?? entry['total'] ?? entry['amount']);
        } else if (value is num) {
          breakdown[key.toString()] = value.toDouble();
        }
      });
    }
    return ClipEarnings(total: total, salesCount: salesCount, breakdown: breakdown);
  }

  static double _doubleValue(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse('$raw') ?? 0;
  }
}

class ClipMediaUrl {
  const ClipMediaUrl({this.url, this.expiresAt});

  final String? url;
  final DateTime? expiresAt;

  factory ClipMediaUrl.fromJson(Map<String, dynamic> json) {
    final data = ApiJson.dataMap(json);
    return ClipMediaUrl(
      url: ApiJson.pickString(data, ['url', 'mediaUrl', 'playbackUrl', 'streamUrl']),
      expiresAt: DateTime.tryParse(ApiJson.pickString(data, ['expiresAt', 'expiry']) ?? ''),
    );
  }
}
