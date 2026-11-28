class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.details});

  final String message;
  final int? statusCode;
  final Object? details;

  @override
  String toString() => message;
}

/// Thrown by `POST /auth/login` when the account exists but its email has not
/// been verified yet (backend responds 403, `error.code: EMAIL_NOT_VERIFIED`).
class EmailNotVerifiedException extends ApiException {
  EmailNotVerifiedException({required String message, required this.email})
      : super(message, statusCode: 403);

  /// The account's email from the 403 body, for any login identifier.
  final String email;
}
