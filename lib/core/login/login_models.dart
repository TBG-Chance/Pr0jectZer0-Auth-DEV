import '../models/trusted_system.dart';

class DashboardLoginChallenge {
  const DashboardLoginChallenge({
    required this.version,
    required this.serverId,
    required this.challengeId,
    required this.nonce,
    required this.expiresAt,
    required this.trustedSystem,
  });

  final int version;
  final String serverId;
  final String challengeId;
  final String nonce;
  final DateTime expiresAt;
  final TrustedSystem trustedSystem;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);
}

class LoginApprovalException implements Exception {
  const LoginApprovalException(this.message);

  final String message;

  @override
  String toString() => message;
}
