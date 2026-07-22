import 'dart:convert';

import '../crypto/crypto_models.dart';
import '../models/trusted_system.dart';

enum EnrollmentStatus {
  notEnrolled,
  preparing,
  awaitingConfirmation,
  enrolled,
  failed,
}

class EnrollmentInvitation {
  const EnrollmentInvitation({
    required this.version,
    required this.enrollmentId,
    required this.systemId,
    required this.displayName,
    required this.organization,
    required this.productType,
    required this.serverBaseUrl,
    required this.nonce,
    required this.issuedAt,
    required this.expiresAt,
    this.serverPublicKey,
  });

  final int version;
  final String enrollmentId;
  final String systemId;
  final String displayName;
  final String organization;
  final String productType;
  final Uri serverBaseUrl;
  final String nonce;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final String? serverPublicKey;

  bool get isExpired => DateTime.now().toUtc().isAfter(expiresAt);

  factory EnrollmentInvitation.fromJson(Map<String, dynamic> json) {
    return EnrollmentInvitation(
      version: json['version'] as int,
      enrollmentId: json['enrollmentId'] as String,
      systemId: json['systemId'] as String,
      displayName: json['displayName'] as String,
      organization: json['organization'] as String,
      productType: json['productType'] as String,
      serverBaseUrl: Uri.parse(json['serverBaseUrl'] as String),
      nonce: json['nonce'] as String,
      issuedAt: DateTime.parse(json['issuedAt'] as String).toUtc(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      serverPublicKey: json['serverPublicKey'] as String?,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'enrollmentId': enrollmentId,
    'systemId': systemId,
    'displayName': displayName,
    'organization': organization,
    'productType': productType,
    'serverBaseUrl': serverBaseUrl.toString(),
    'nonce': nonce,
    'issuedAt': issuedAt.toUtc().toIso8601String(),
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    if (serverPublicKey != null) 'serverPublicKey': serverPublicKey,
  };
}

class DeviceEnrollmentRequest {
  const DeviceEnrollmentRequest({
    required this.version,
    required this.enrollmentId,
    required this.systemId,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.publicKey,
    required this.nonce,
    required this.createdAt,
    required this.signature,
  });

  final int version;
  final String enrollmentId;
  final String systemId;
  final String deviceId;
  final String deviceName;
  final String platform;
  final DevicePublicKey publicKey;
  final String nonce;
  final DateTime createdAt;
  final SignatureEnvelope signature;

  Map<String, Object> unsignedJson() => <String, Object>{
    'version': version,
    'enrollmentId': enrollmentId,
    'systemId': systemId,
    'deviceId': deviceId,
    'deviceName': deviceName,
    'platform': platform,
    'publicKey': publicKey.toJson(),
    'nonce': nonce,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  Map<String, Object> toJson() => <String, Object>{
    ...unsignedJson(),
    'signature': signature.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());

  Map<String, Object> toApiJson(EnrollmentInvitation invitation) =>
      <String, Object>{
        'challenge_id': invitation.enrollmentId,
        'enrollment_secret': invitation.nonce,
        'device_name': deviceName,
        'key_algorithm': publicKey.algorithm.toLowerCase(),
        'public_key': publicKey.publicKeyBase64Url,
      };
}

class EnrollmentConfirmation {
  const EnrollmentConfirmation({
    required this.enrollmentId,
    required this.systemId,
    required this.trustedSystemId,
    required this.confirmedAt,
    required this.serverPublicKey,
  });

  final String enrollmentId;
  final String systemId;
  final String trustedSystemId;
  final DateTime confirmedAt;
  final String serverPublicKey;

  factory EnrollmentConfirmation.fromJson(Map<String, dynamic> json) {
    return EnrollmentConfirmation(
      enrollmentId: json['enrollmentId'] as String,
      systemId: json['systemId'] as String,
      trustedSystemId: json['trustedSystemId'] as String,
      confirmedAt: DateTime.parse(json['confirmedAt'] as String).toUtc(),
      serverPublicKey: json['serverPublicKey'] as String,
    );
  }
}

class EnrollmentSnapshot {
  const EnrollmentSnapshot({
    required this.status,
    required this.trustedSystems,
    this.pendingInvitation,
    this.lastError,
  });

  final EnrollmentStatus status;
  final List<TrustedSystem> trustedSystems;
  final EnrollmentInvitation? pendingInvitation;
  final String? lastError;

  bool get isEnrolled => trustedSystems.isNotEmpty;
}

class EnrollmentException implements Exception {
  const EnrollmentException(this.message);

  final String message;

  @override
  String toString() => 'EnrollmentException: $message';
}
