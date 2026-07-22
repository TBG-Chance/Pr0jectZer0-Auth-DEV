import 'dart:convert';

import 'enrollment_models.dart';

class EnrollmentPayloadParser {
  const EnrollmentPayloadParser();

  static const supportedVersion = 1;

  EnrollmentInvitation parse(String payload) {
    final normalized = payload.trim();
    if (normalized.isEmpty) {
      throw const EnrollmentException('Enrollment payload is empty.');
    }

    try {
      final uri = Uri.tryParse(normalized);
      if (uri != null && uri.scheme == 'pr0jectzer0' && uri.host == 'enroll') {
        final invitation = _fromEnrollmentUri(uri);
        _validate(invitation);
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
      productType: 'Pr0jectZer0 management platform',
      serverBaseUrl: Uri.parse(requiredValue('server_url')),
      nonce: requiredValue('secret'),
      issuedAt: DateTime.parse(requiredValue('issued_at')).toUtc(),
      expiresAt: DateTime.parse(requiredValue('expires_at')).toUtc(),
    );
  }

  void _validate(EnrollmentInvitation invitation) {
    if (invitation.version != supportedVersion) {
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

    if (!invitation.serverBaseUrl.hasScheme ||
        invitation.serverBaseUrl.host.isEmpty) {
      throw const EnrollmentException('Server URL is invalid.');
    }
    if (!_isAllowedServerUrl(invitation.serverBaseUrl)) {
      throw const EnrollmentException(
        'Enrollment requires HTTPS, except for loopback or private-network servers.',
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
    if (invitation.expiresAt.difference(invitation.issuedAt) >
        const Duration(hours: 24)) {
      throw const EnrollmentException(
        'Enrollment invitation validity exceeds 24 hours.',
      );
    }
  }

  bool _isAllowedServerUrl(Uri uri) {
    if (uri.scheme == 'https') return true;
    if (uri.scheme != 'http') return false;

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
}
