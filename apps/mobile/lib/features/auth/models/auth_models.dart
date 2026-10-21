import '../../users/models/user_models.dart';

class RegisterDraft {
  RegisterDraft({
    this.phoneDigits,
    this.phoneCountryCode,
    this.password,
    this.firstName,
    this.lastName,
    this.username,
    this.email,
    this.userId,
  });

  final String? phoneDigits;
  final String? phoneCountryCode;
  final String? password;
  final String? firstName;
  final String? lastName;
  final String? username;
  final String? email;
  final String? userId;

  String get phoneE164 {
    final code = phoneCountryCode ?? '';
    final digits = (phoneDigits ?? '').replaceAll(RegExp(r'\D'), '');
    return '$code$digits';
  }

  RegisterDraft copyWith({
    String? phoneDigits,
    String? phoneCountryCode,
    String? password,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? userId,
  }) {
    return RegisterDraft(
      phoneDigits: phoneDigits ?? this.phoneDigits,
      phoneCountryCode: phoneCountryCode ?? this.phoneCountryCode,
      password: password ?? this.password,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      userId: userId ?? this.userId,
    );
  }
}

class AuthLoginResult {
  const AuthLoginResult({
    required this.userId,
    required this.identifier,
    required this.needsVerification,
    required this.emailVerified,
    required this.phoneVerified,
  });

  final String userId;
  final String identifier;
  final bool needsVerification;
  final bool emailVerified;
  final bool phoneVerified;
}

class BridgeTokenResult {
  const BridgeTokenResult({
    required this.token,
    required this.userId,
    this.user,
  });

  final String token;
  final String userId;
  final XLiveUser? user;
}
