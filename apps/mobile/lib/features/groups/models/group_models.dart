import '../../../core/network/api_json.dart';

class GroupMember {
  const GroupMember({
    required this.id,
    this.displayName,
    this.username,
    this.avatarUrl,
    this.role,
    this.activityStatus,
    this.joinedAt,
  });

  final String id;
  final String? displayName;
  final String? username;
  final String? avatarUrl;
  final String? role;
  final String? activityStatus;
  final DateTime? joinedAt;

  String get name => displayName ?? username ?? 'Member';

  bool get isOnline => activityStatus?.toLowerCase() == 'online';

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final user = ApiJson.map(json['user']) ?? ApiJson.map(json['member']);
    final source = user ?? json;
    final joinedRaw = ApiJson.pickString(json, [
          'joinedAt',
          'joined_at',
          'memberSince',
          'membershipCreatedAt',
        ]) ??
        ApiJson.pickString(source, ['joinedAt', 'joined_at', 'memberSince']);
    return GroupMember(
      id: ApiJson.pickString(json, ['userId', 'id', '_id']) ??
          ApiJson.pickString(source, ['id', '_id', 'userId']) ??
          '',
      displayName: ApiJson.pickString(source, ['displayName', 'name']),
      username: ApiJson.pickString(source, ['username']),
      avatarUrl: ApiJson.pickString(source, ['avatarUrl', 'avatar', 'profileImage', 'photoUrl', 'imageUrl', 'profilePicture']),
      role: ApiJson.pickString(json, ['role', 'memberRole']),
      activityStatus: ApiJson.pickString(json, ['activityStatus', 'onlineStatus', 'presence']),
      joinedAt: DateTime.tryParse(joinedRaw ?? ''),
    );
  }
}
