class XLiveUser {
  const XLiveUser({
    required this.id,
    this.username,
    this.displayName,
    this.firstName,
    this.lastName,
    this.bio,
    this.avatarUrl,
    this.language,
    this.gender,
    this.isCreator = false,
    this.isFollowing = false,
  });

  final String id;
  final String? username;
  final String? displayName;
  final String? firstName;
  final String? lastName;
  final String? bio;
  final String? avatarUrl;
  final String? language;
  final String? gender;
  final bool isCreator;
  final bool isFollowing;

  String get effectiveDisplayName {
    final direct = displayName?.trim();
    if (direct != null && direct.isNotEmpty) return direct;
    final combined = [firstName, lastName].where((s) => s != null && s.trim().isNotEmpty).map((s) => s!.trim()).join(' ').trim();
    if (combined.isNotEmpty) return combined;
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return handle;
    return 'User';
  }

  factory XLiveUser.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    Map<String, dynamic> src = data;
    for (final key in ['user', 'profile', 'followed', 'following', 'followee', 'target']) {
      final nested = data[key];
      if (nested is Map<String, dynamic>) {
        src = nested;
        break;
      }
    }
    return XLiveUser(
      id: _string(src['id']) ??
          _string(src['_id']) ??
          _string(data['followingId']) ??
          _string(data['followedId']) ??
          _string(data['userId']) ??
          _string(data['id']) ??
          _string(data['_id']) ??
          '',
      username: _string(src['username']) ?? _string(src['handle']) ?? _string(data['username']),
      displayName: _string(src['displayName']) ?? _string(src['name']) ?? _string(data['displayName']) ?? _string(data['name']),
      firstName: _string(src['firstName']) ?? _string(src['first_name']),
      lastName: _string(src['lastName']) ?? _string(src['last_name']),
      bio: _string(src['bio']) ?? _string(data['bio']),
      avatarUrl: _string(src['avatarUrl']) ?? _string(src['avatar']) ?? _string(data['avatarUrl']) ?? _string(data['avatar']),
      language: _string(src['language']),
      gender: _string(src['gender']),
      isCreator: src['isCreator'] == true || src['role'] == 'creator' || data['isCreator'] == true,
      isFollowing: src['isFollowing'] == true || data['isFollowing'] == true,
    );
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

class AppSettings {
  const AppSettings({
    this.notifyFriendsLive = true,
    this.discoverable = true,
    this.showAdultContent = false,
    this.appTheme = 'system',
    this.postVisibilityDefault = 'everyone',
  });

  final bool notifyFriendsLive;
  final bool discoverable;
  final bool showAdultContent;
  final String appTheme;
  final String postVisibilityDefault;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map<String, dynamic> ? json['data'] as Map<String, dynamic> : json;
    return AppSettings(
      notifyFriendsLive: data['notifyFriendsLive'] != false,
      discoverable: data['discoverable'] != false,
      showAdultContent: data['showAdultContent'] == true,
      appTheme: _string(data['appTheme']) ?? 'system',
      postVisibilityDefault: _string(data['postVisibilityDefault']) ?? 'everyone',
    );
  }

  Map<String, dynamic> toPatchJson() {
    return {
      'notifyFriendsLive': notifyFriendsLive,
      'discoverable': discoverable,
      'showAdultContent': showAdultContent,
      'appTheme': appTheme,
      'postVisibilityDefault': postVisibilityDefault,
    };
  }

  AppSettings copyWith({
    bool? notifyFriendsLive,
    bool? discoverable,
    bool? showAdultContent,
    String? appTheme,
    String? postVisibilityDefault,
  }) {
    return AppSettings(
      notifyFriendsLive: notifyFriendsLive ?? this.notifyFriendsLive,
      discoverable: discoverable ?? this.discoverable,
      showAdultContent: showAdultContent ?? this.showAdultContent,
      appTheme: appTheme ?? this.appTheme,
      postVisibilityDefault: postVisibilityDefault ?? this.postVisibilityDefault,
    );
  }

  static String? _string(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
