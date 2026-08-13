enum AuthenticationMethod { pin, biometric, systemApproval }

enum AuthenticationStatus { locked, authenticating, authenticated, failed }

class AuthenticationSession {
  final String id;
  final AuthenticationMethod method;
  final DateTime authenticatedAt;
  final DateTime expiresAt;

  const AuthenticationSession({
    required this.id,
    required this.method,
    required this.authenticatedAt,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Duration get remainingTime {
    final remaining = expiresAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }
}

class AuthenticationResult {
  final bool success;
  final AuthenticationSession? session;
  final String? errorCode;
  final String? message;

  const AuthenticationResult._({
    required this.success,
    this.session,
    this.errorCode,
    this.message,
  });

  const AuthenticationResult.success(AuthenticationSession session)
    : this._(success: true, session: session);

  const AuthenticationResult.failure({
    required String errorCode,
    required String message,
  }) : this._(success: false, errorCode: errorCode, message: message);
}
