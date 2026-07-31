import '../models/trusted_system.dart';

class DashboardLoginChallenge {
  const DashboardLoginChallenge({
    required this.version,
    required this.serverId,
    required this.serverName,
    required this.organization,
    required this.challengeId,
    required this.nonce,
    required this.requestedAt,
    required this.expiresAt,
    required this.browserName,
    required this.operatingSystem,
    required this.networkAddress,
    required this.verificationCode,
    required this.trustedSystem,
  });

  final int version;
  final String serverId;
  final String serverName;
  final String organization;
  final String challengeId;
  final String nonce;
  final DateTime requestedAt;
  final DateTime expiresAt;
  final String browserName;
  final String operatingSystem;
  final String networkAddress;
  final String verificationCode;
  final TrustedSystem trustedSystem;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt);
  bool get hasBrowserContext => version >= 3 && verificationCode.isNotEmpty;
}

class LoginApprovalException implements Exception {
  const LoginApprovalException(this.message);

  final String message;

  @override
  String toString() => message;
}
