import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'enrollment_models.dart';

class EnrollmentPayloadParser {
  const EnrollmentPayloadParser({this.allowLegacyInsecure = false});

  static const supportedVersion = 3;
  final bool allowLegacyInsecure;

  Future<EnrollmentInvitation> parse(String payload) async {
    final normalized = payload.trim();
    if (normalized.isEmpty) {
      throw const EnrollmentException('Enrollment payload is empty.');
    }

    try {
      final uri = Uri.tryParse(normalized);
      if (uri != null && uri.scheme == 'pr0jectzer0' && uri.host == 'enroll') {
        final invitation = _fromEnrollmentUri(uri);
        _validate(invitation);
        if (!allowLegacyInsecure || invitation.version != 1) {
          await _verifySignature(invitation);
        }
        if (invitation.version == 3) await _verifyTlsCA(invitation);
        return invitation;
      }
      if (uri != null &&
          uri.scheme == 'pr0jectzer0' &&
          uri.host == 'activate') {
        final invitation = _fromActivationUri(uri);
        _validateActivation(invitation);
        if (!allowLegacyInsecure) {
          await _verifyActivationSignature(invitation);
        }
        if (invitation.version == 2) await _verifyTlsCA(invitation);
        return invitation;
      }
      if (uri != null && uri.scheme == 'pr0jectzer0' && uri.host == 'login') {
        throw const EnrollmentException(
          'This is a login code. Use the login approval scanner instead.',
        );
      }
      final decoded = jsonDecode(normalized);
      if (decoded is! Map<String, dynamic>) {
        throw const EnrollmentException(
          'Enrollment payload must be a JSON object.',
        );
      }
      final invitation = EnrollmentInvitation.fromJson(decoded);
      _validate(invitation);
      if (!allowLegacyInsecure || invitation.version != 1) {
        await _verifySignature(invitation);
      }
      if (invitation.version == 3) await _verifyTlsCA(invitation);
      return invitation;
    } on EnrollmentException {
      rethrow;
    } on FormatException catch (error) {
      throw EnrollmentException('Enrollment payload is malformed: $error');
    } on TypeError catch (error) {
      throw EnrollmentException('Enrollment payload is incomplete: $error');
    }
  }

  EnrollmentInvitation _fromEnrollmentUri(Uri uri) {
    final values = uri.queryParameters;
    String requiredValue(String name) {
      final value = values[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw EnrollmentException('Enrollment payload is missing $name.');
      }
      return value;
    }

    final version = int.tryParse(requiredValue('v'));
    if (version == null) {
      throw const EnrollmentException('Enrollment payload version is invalid.');
    }
    return EnrollmentInvitation(
      version: version,
      enrollmentId: requiredValue('challenge_id'),
      systemId: requiredValue('server_id'),
      displayName: requiredValue('server_name'),
      organization: requiredValue('organization'),
      productType:
          values['device_type']?.trim() ?? 'Pr0jectZer0 management platform',
      serverBaseUrl: Uri.parse(requiredValue('server_url')),
      nonce: requiredValue('secret'),
      issuedAt: DateTime.parse(requiredValue('issued_at')).toUtc(),
      expiresAt: DateTime.parse(requiredValue('expires_at')).toUtc(),
      serverPublicKey: values['server_public_key']?.trim(),
      serverFingerprint: values['server_fingerprint']?.trim(),
      serverSignature: values['signature']?.trim(),
      tlsCaCertificate: values['tls_ca']?.trim(),
      tlsCaFingerprint: values['tls_ca_fingerprint']?.trim(),
    );
  }

  EnrollmentInvitation _fromActivationUri(Uri uri) {
    final values = uri.queryParameters;
    String requiredValue(String name) {
      final value = values[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw EnrollmentException('Activation payload is missing $name.');
      }
      return value;
    }

    final version = int.tryParse(requiredValue('v'));
    if (version == null) {
      throw const EnrollmentException('Activation payload version is invalid.');
    }
    final purpose = EnrollmentPurpose.fromWireValue(requiredValue('purpose'));
    if (purpose == EnrollmentPurpose.deviceEnrollment) {
      throw const EnrollmentException('Activation purpose is invalid.');
    }
    return EnrollmentInvitation(
      version: version,
      enrollmentId: requiredValue('challenge_id'),
      systemId: requiredValue('server_id'),
      displayName: requiredValue('server_name'),
      organization: requiredValue('organization'),
      productType: requiredValue('device_type'),
      serverBaseUrl: Uri.parse(requiredValue('server_url')),
      nonce: requiredValue('secret'),
      issuedAt: DateTime.parse(requiredValue('issued_at')).toUtc(),
      expiresAt: DateTime.parse(requiredValue('expires_at')).toUtc(),
      serverPublicKey: values['server_public_key']?.trim(),
      serverFingerprint: values['server_fingerprint']?.trim(),
      serverSignature: values['signature']?.trim(),
      tlsCaCertificate: values['tls_ca']?.trim(),
      tlsCaFingerprint: values['tls_ca_fingerprint']?.trim(),
      purpose: purpose,
      administratorId: requiredValue('administrator_id'),
      administratorFirstName: requiredValue('first_name'),
      administratorLastName: requiredValue('last_name'),
      administratorPosition: values['position']?.trim() ?? '',
      administratorRole: requiredValue('role'),
    );
  }

  void _validate(EnrollmentInvitation invitation) {
    final supported =
        invitation.version == supportedVersion ||
        invitation.version == 2 ||
        (allowLegacyInsecure && invitation.version == 1);
    if (!supported) {
      throw EnrollmentException(
        'Unsupported enrollment payload version ${invitation.version}.',
      );
    }

    final requiredValues = <String, String>{
      'enrollmentId': invitation.enrollmentId,
      'systemId': invitation.systemId,
      'displayName': invitation.displayName,
      'organization': invitation.organization,
      'productType': invitation.productType,
      'nonce': invitation.nonce,
    };
    for (final entry in requiredValues.entries) {
      if (entry.value.trim().isEmpty) {
        throw EnrollmentException('${entry.key} cannot be empty.');
      }
    }
    if (invitation.version >= 2 && invitation.productType != 'pz_auth') {
      throw const EnrollmentException(
        'This invitation is not intended for Pr0jectZer0 Auth.',
      );
    }
    final origin = invitation.serverBaseUrl;
    if (!origin.hasScheme ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/')) {
      throw const EnrollmentException(
        'Server URL must contain only a valid origin.',
      );
    }
    if (!_isAllowedServerUrl(origin)) {
      throw const EnrollmentException(
        'Open-beta enrollment requires an HTTPS server.',
      );
    }
    if (!invitation.expiresAt.isAfter(invitation.issuedAt)) {
      throw const EnrollmentException(
        'Enrollment expiration must be after its issue time.',
      );
    }
    if (invitation.isExpired) {
      throw const EnrollmentException('Enrollment invitation has expired.');
    }
    if (invitation.version == 3 &&
        ((invitation.tlsCaCertificate?.trim().isEmpty ?? true) ||
            (invitation.tlsCaFingerprint?.trim().isEmpty ?? true))) {
      throw const EnrollmentException(
        'Local HTTPS enrollment is missing its installation trust anchor.',
      );
    }
    final maximumLifetime = invitation.version >= 2
        ? const Duration(minutes: 10)
        : const Duration(hours: 24);
    if (invitation.expiresAt.difference(invitation.issuedAt) >
        maximumLifetime) {
      throw const EnrollmentException(
        'Enrollment invitation validity exceeds 10 minutes.',
      );
    }
  }

  void _validateActivation(EnrollmentInvitation invitation) {
    final supportedActivation =
        invitation.version == 1 || invitation.version == 2;
    if (!supportedActivation ||
        invitation.purpose == EnrollmentPurpose.deviceEnrollment) {
      throw const EnrollmentException('Unsupported activation payload.');
    }
    if (invitation.productType != 'pz_auth') {
      throw const EnrollmentException(
        'This activation is not intended for Pr0jectZer0 Auth.',
      );
    }
    if (invitation.version == 2 &&
        ((invitation.tlsCaCertificate?.trim().isEmpty ?? true) ||
            (invitation.tlsCaFingerprint?.trim().isEmpty ?? true))) {
      throw const EnrollmentException(
        'Local HTTPS activation is missing its installation trust anchor.',
      );
    }
    final origin = invitation.serverBaseUrl;
    if (!origin.hasScheme ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        origin.hasQuery ||
        origin.hasFragment ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        !_isAllowedServerUrl(origin)) {
      throw const EnrollmentException(
        'Open-beta activation requires a valid HTTPS server origin.',
      );
    }
    final requiredValues = <String?>[
      invitation.enrollmentId,
      invitation.systemId,
      invitation.displayName,
      invitation.organization,
      invitation.nonce,
      invitation.administratorId,
      invitation.administratorFirstName,
      invitation.administratorLastName,
      invitation.administratorRole,
    ];
    if (requiredValues.any((value) => value == null || value.trim().isEmpty)) {
      throw const EnrollmentException('Activation payload is incomplete.');
    }
    const roles = <String>{
      'owner',
      'security_administrator',
      'security_analyst',
    };
    if (!roles.contains(invitation.administratorRole)) {
      throw const EnrollmentException('Administrator role is invalid.');
    }
    if (!invitation.expiresAt.isAfter(invitation.issuedAt) ||
        invitation.isExpired ||
        invitation.expiresAt.difference(invitation.issuedAt) >
            const Duration(minutes: 10)) {
      throw const EnrollmentException(
        'Activation code is expired or has an invalid lifetime.',
      );
    }
  }

  Future<void> _verifySignature(EnrollmentInvitation invitation) async {
    final encodedPublicKey = invitation.serverPublicKey?.trim() ?? '';
    final fingerprint =
        invitation.serverFingerprint?.trim().toLowerCase() ?? '';
    final encodedSignature = invitation.serverSignature?.trim() ?? '';
    if (encodedPublicKey.isEmpty ||
        fingerprint.isEmpty ||
        encodedSignature.isEmpty) {
      throw const EnrollmentException(
        'Enrollment invitation is missing its server identity signature.',
      );
    }
    late List<int> publicKeyBytes;
    late List<int> signatureBytes;
    try {
      publicKeyBytes = base64Url.decode(base64Url.normalize(encodedPublicKey));
      signatureBytes = base64Url.decode(base64Url.normalize(encodedSignature));
    } on FormatException {
      throw const EnrollmentException('Server identity encoding is invalid.');
    }
    if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
      throw const EnrollmentException(
        'Server identity key or signature is invalid.',
      );
    }
    final digest = await Sha256().hash(publicKeyBytes);
    final calculated =
        'sha256:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    if (calculated != fingerprint) {
      throw const EnrollmentException(
        'Server identity fingerprint does not match its public key.',
      );
    }
    final fields = <String>[
      invitation.version == 3
          ? 'pr0jectzer0-enrollment-v3'
          : 'pr0jectzer0-enrollment-v2',
      invitation.version.toString(),
      invitation.systemId,
      invitation.displayName,
      invitation.serverBaseUrl.toString().replaceFirst(RegExp(r'/$'), ''),
      invitation.organization,
      invitation.productType,
      invitation.enrollmentId,
      invitation.nonce,
      (invitation.issuedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      (invitation.expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      encodedPublicKey,
      fingerprint,
    ];
    if (invitation.version == 3) {
      fields.addAll(<String>[
        invitation.tlsCaCertificate!.trim(),
        invitation.tlsCaFingerprint!.trim().toLowerCase(),
      ]);
    }
    final signature = Signature(
      signatureBytes,
      publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
    );
    final valid = await Ed25519().verify(
      utf8.encode(fields.join('\n')),
      signature: signature,
    );
    if (!valid) {
      throw const EnrollmentException(
        'Enrollment invitation signature is invalid.',
      );
    }
  }

  Future<void> _verifyActivationSignature(
    EnrollmentInvitation invitation,
  ) async {
    final encodedPublicKey = invitation.serverPublicKey?.trim() ?? '';
    final fingerprint =
        invitation.serverFingerprint?.trim().toLowerCase() ?? '';
    final encodedSignature = invitation.serverSignature?.trim() ?? '';
    if (encodedPublicKey.isEmpty ||
        fingerprint.isEmpty ||
        encodedSignature.isEmpty) {
      throw const EnrollmentException(
        'Activation code is missing its server identity signature.',
      );
    }
    late List<int> publicKeyBytes;
    late List<int> signatureBytes;
    try {
      publicKeyBytes = base64Url.decode(base64Url.normalize(encodedPublicKey));
      signatureBytes = base64Url.decode(base64Url.normalize(encodedSignature));
    } on FormatException {
      throw const EnrollmentException('Server identity encoding is invalid.');
    }
    if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
      throw const EnrollmentException(
        'Server identity key or signature is invalid.',
      );
    }
    final digest = await Sha256().hash(publicKeyBytes);
    final calculated =
        'sha256:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    if (calculated != fingerprint) {
      throw const EnrollmentException(
        'Server identity fingerprint does not match its public key.',
      );
    }
    final fields = <String>[
      invitation.version == 2
          ? 'pr0jectzer0-administrator-activation-v2'
          : 'pr0jectzer0-administrator-activation-v1',
      invitation.version.toString(),
      invitation.purpose.wireValue,
      invitation.systemId,
      invitation.displayName,
      invitation.serverBaseUrl.toString().replaceFirst(RegExp(r'/$'), ''),
      invitation.organization,
      invitation.productType,
      invitation.enrollmentId,
      invitation.administratorId!,
      invitation.administratorFirstName!,
      invitation.administratorLastName!,
      invitation.administratorPosition ?? '',
      invitation.administratorRole!,
      invitation.nonce,
      (invitation.issuedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      (invitation.expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      encodedPublicKey,
      fingerprint,
    ];
    if (invitation.version == 2) {
      fields.addAll(<String>[
        invitation.tlsCaCertificate!.trim(),
        invitation.tlsCaFingerprint!.trim().toLowerCase(),
      ]);
    }
    final valid = await Ed25519().verify(
      utf8.encode(fields.join('\n')),
      signature: Signature(
        signatureBytes,
        publicKey: SimplePublicKey(publicKeyBytes, type: KeyPairType.ed25519),
      ),
    );
    if (!valid) {
      throw const EnrollmentException(
        'Activation code server signature is invalid.',
      );
    }
  }

  bool _isAllowedServerUrl(Uri uri) {
    if (uri.scheme == 'https') return true;
    if (!allowLegacyInsecure || uri.scheme != 'http') return false;
    final host = uri.host.toLowerCase();
    if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
      return true;
    }
    final parts = host.split('.').map(int.tryParse).toList();
    if (parts.length != 4 || parts.any((part) => part == null)) return false;
    final a = parts[0]!;
    final b = parts[1]!;
    return a == 10 ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 192 && b == 168);
  }

  Future<void> _verifyTlsCA(EnrollmentInvitation invitation) async {
    final encoded = invitation.tlsCaCertificate?.trim() ?? '';
    final expected = invitation.tlsCaFingerprint?.trim().toLowerCase() ?? '';
    if (!RegExp(r'^sha256:[0-9a-f]{64}$').hasMatch(expected)) {
      throw const EnrollmentException(
        'Installation HTTPS trust anchor fingerprint is invalid.',
      );
    }
    late List<int> certificate;
    try {
      certificate = base64Url.decode(base64Url.normalize(encoded));
    } on FormatException {
      throw const EnrollmentException(
        'Installation HTTPS trust anchor encoding is invalid.',
      );
    }
    if (certificate.isEmpty || certificate.length > 16 * 1024) {
      throw const EnrollmentException(
        'Installation HTTPS trust anchor size is invalid.',
      );
    }
    final digest = await Sha256().hash(certificate);
    final actual =
        'sha256:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    if (actual != expected) {
      throw const EnrollmentException(
        'Installation HTTPS trust anchor fingerprint does not match.',
      );
    }
  }
}
