class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

class BridgeUserNotFoundException extends ApiException {
  BridgeUserNotFoundException()
      : super(
          'This email is registered, but your Xlive profile has not been set up yet. Contact support to activate your account.',
          statusCode: 404,
        );
}

class VerificationRequiredException extends ApiException {
  VerificationRequiredException({
    required this.userId,
    required this.identifier,
    required this.verificationType,
    required this.password,
    this.email,
    this.phone,
    this.username,
  }) : super('Verification required', statusCode: 403);

  final String userId;
  final String identifier;
  final String verificationType;
  final String password;
  final String? email;
  final String? phone;
  final String? username;
}
