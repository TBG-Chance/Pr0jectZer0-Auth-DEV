import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/crypto/secure_ed25519_crypto_service.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_models.dart';
import 'package:pr0jectzer0_auth/core/enrollment/local_enrollment_service.dart';
import 'package:pr0jectzer0_auth/core/enrollment/trusted_system_store.dart';
import 'package:pr0jectzer0_auth/core/network/auth_api_client.dart';
import 'package:pr0jectzer0_auth/core/storage/in_memory_secure_storage_service.dart';

void main() {
  late InMemorySecureStorageService storage;
  late SecureEd25519CryptoService crypto;
  late LocalEnrollmentService enrollment;
  late _FakeAuthApiClient api;

  setUp(() async {
    storage = InMemorySecureStorageService();
    await storage.initialize();
    crypto = SecureEd25519CryptoService(storage);
    await crypto.initialize();
    api = _FakeAuthApiClient();
    enrollment = LocalEnrollmentService(
      crypto: crypto,
      trustedSystems: TrustedSystemStore(storage),
      api: api,
    );
    await enrollment.initialize();
  });

  tearDown(() async {
    await enrollment.dispose();
    await crypto.dispose();
    await storage.dispose();
  });

  test('parses a valid private-network enrollment invitation', () {
    final invitation = enrollment.parseInvitation(_payload());

    expect(invitation.systemId, 'system-1');
    expect(invitation.serverBaseUrl.host, '192.168.1.20');
  });

  test('parses the platform enrollment URI contract', () {
    final now = DateTime.now().toUtc();
    final payload = Uri(
      scheme: 'pr0jectzer0',
      host: 'enroll',
      queryParameters: <String, String>{
        'v': '1',
        'server_id': 'server-1',
        'server_name': 'Pr0jectZer0 Lab',
        'server_url': 'http://192.168.1.20:8080',
        'organization': 'The Bostrom Group',
        'challenge_id': 'enroll-1',
        'secret': 'one-time-secret',
        'issued_at': now.toIso8601String(),
        'expires_at': now.add(const Duration(minutes: 2)).toIso8601String(),
      },
    ).toString();

    final invitation = enrollment.parseInvitation(payload);

    expect(invitation.enrollmentId, 'enroll-1');
    expect(invitation.systemId, 'server-1');
    expect(invitation.nonce, 'one-time-secret');
  });

  test('explains when a login QR is scanned as an enrollment QR', () {
    expect(
      () => enrollment.parseInvitation(
        'pr0jectzer0://login?v=1&challenge_id=login-1',
      ),
      throwsA(
        isA<EnrollmentException>().having(
          (error) => error.message,
          'message',
          contains('login approval scanner'),
        ),
      ),
    );
  });

  test('rejects expired enrollment invitations', () {
    final now = DateTime.now().toUtc();
    expect(
      () => enrollment.parseInvitation(
        _payload(
          issuedAt: now.subtract(const Duration(hours: 2)),
          expiresAt: now.subtract(const Duration(hours: 1)),
        ),
      ),
      throwsA(isA<EnrollmentException>()),
    );
  });

  test('prepares a signed device registration request', () async {
    final invitation = enrollment.parseInvitation(_payload());
    final request = await enrollment.prepareEnrollment(
      invitation: invitation,
      deviceName: 'Test Phone',
      platform: 'android',
    );

    expect(request.systemId, invitation.systemId);
    expect(request.signature.keyId, request.publicKey.keyId);
    expect(enrollment.snapshot.status, EnrollmentStatus.awaitingConfirmation);

    final unsigned = utf8.encode(jsonEncode(request.unsignedJson()));
    expect(
      await crypto.verify(payload: unsigned, signature: request.signature),
      isTrue,
    );
  });

  test('persists a confirmed trusted system', () async {
    final invitation = enrollment.parseInvitation(_payload());
    await enrollment.prepareEnrollment(
      invitation: invitation,
      deviceName: 'Test Phone',
      platform: 'android',
    );
    await enrollment.completeEnrollment(
      invitation: invitation,
      confirmation: EnrollmentConfirmation(
        enrollmentId: invitation.enrollmentId,
        systemId: invitation.systemId,
        trustedSystemId: 'trusted-1',
        confirmedAt: DateTime.now().toUtc(),
        serverPublicKey: 'server-public-key',
      ),
    );

    final second = LocalEnrollmentService(
      crypto: crypto,
      trustedSystems: TrustedSystemStore(storage),
      api: api,
    );
    await second.initialize();

    expect(second.snapshot.isEnrolled, isTrue);
    expect(second.snapshot.trustedSystems.single.id, 'trusted-1');
    await second.dispose();
  });

  test(
    'submits the backend contract and stores the server device ID',
    () async {
      final invitation = enrollment.parseInvitation(_payload());
      final request = await enrollment.prepareEnrollment(
        invitation: invitation,
        deviceName: 'Test Phone',
        platform: 'android',
      );

      await enrollment.submitEnrollment(
        invitation: invitation,
        request: request,
      );

      expect(api.lastEnrollment?['challenge_id'], invitation.enrollmentId);
      expect(api.lastEnrollment?['enrollment_secret'], invitation.nonce);
      expect(api.lastEnrollment?['key_algorithm'], 'ed25519');
      expect(
        enrollment.snapshot.trustedSystems.single.id,
        'authdev-server-assigned',
      );
    },
  );
}

class _FakeAuthApiClient implements AuthApiClient {
  Map<String, Object>? lastEnrollment;

  @override
  Future<EnrolledDevice> completeEnrollment({
    required Uri serverBaseUrl,
    required Map<String, Object> payload,
  }) async {
    lastEnrollment = payload;
    return EnrolledDevice(
      id: 'authdev-server-assigned',
      administratorId: 'admin-1',
      name: payload['device_name']! as String,
      enrolledAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> approveLogin({
    required Uri serverBaseUrl,
    required String challengeId,
    required String nonce,
    required String deviceId,
    required String signature,
  }) async {}
}

String _payload({DateTime? issuedAt, DateTime? expiresAt}) {
  final issued = issuedAt ?? DateTime.now().toUtc();
  final expires = expiresAt ?? issued.add(const Duration(minutes: 15));
  return jsonEncode(<String, Object>{
    'version': 1,
    'enrollmentId': 'enrollment-1',
    'systemId': 'system-1',
    'displayName': 'Pr0jectZer0 Local',
    'organization': 'The Bostrom Group',
    'productType': 'exposure-management',
    'serverBaseUrl': 'http://192.168.1.20:8080',
    'nonce': 'nonce-1234567890',
    'issuedAt': issued.toIso8601String(),
    'expiresAt': expires.toIso8601String(),
    'serverPublicKey': 'server-public-key',
  });
}
