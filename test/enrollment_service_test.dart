import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/crypto/secure_ed25519_crypto_service.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_models.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_payload_parser.dart';
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
      parser: const EnrollmentPayloadParser(allowLegacyInsecure: true),
    );
    await enrollment.initialize();
  });

  tearDown(() async {
    await enrollment.dispose();
    await crypto.dispose();
    await storage.dispose();
  });

  test('parses a valid private-network enrollment invitation', () async {
    final invitation = await enrollment.parseInvitation(_payload());

    expect(invitation.systemId, 'system-1');
    expect(invitation.serverBaseUrl.host, '192.168.1.20');
  });

  test('parses the platform enrollment URI contract', () async {
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

    final invitation = await enrollment.parseInvitation(payload);

    expect(invitation.enrollmentId, 'enroll-1');
    expect(invitation.systemId, 'server-1');
    expect(invitation.nonce, 'one-time-secret');
  });

  test('verifies a signed HTTPS version 2 enrollment invitation', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final encodedPublicKey = base64Url
        .encode(publicKey.bytes)
        .replaceAll('=', '');
    final digest = await Sha256().hash(publicKey.bytes);
    final fingerprint =
        'sha256:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final now = DateTime.now().toUtc();
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(
      (now.millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final expiresAt = issuedAt.add(const Duration(minutes: 5));
    final fields = <String>[
      'pr0jectzer0-enrollment-v2',
      '2',
      'server-2',
      'Pr0jectZer0 Secure Lab',
      'https://security.example.com:8443',
      'The Bostrom Group, LLC',
      'pz_auth',
      'enroll-v2',
      'single-use-secret',
      (issuedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      encodedPublicKey,
      fingerprint,
    ];
    final signature = await algorithm.sign(
      utf8.encode(fields.join('\n')),
      keyPair: keyPair,
    );
    final payload = Uri(
      scheme: 'pr0jectzer0',
      host: 'enroll',
      queryParameters: <String, String>{
        'v': '2',
        'server_id': 'server-2',
        'server_name': 'Pr0jectZer0 Secure Lab',
        'server_url': 'https://security.example.com:8443',
        'organization': 'The Bostrom Group, LLC',
        'device_type': 'pz_auth',
        'challenge_id': 'enroll-v2',
        'secret': 'single-use-secret',
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'server_public_key': encodedPublicKey,
        'server_fingerprint': fingerprint,
        'signature': base64Url.encode(signature.bytes).replaceAll('=', ''),
      },
    ).toString();

    final invitation = await const EnrollmentPayloadParser().parse(payload);

    expect(invitation.version, 2);
    expect(invitation.serverFingerprint, fingerprint);
    expect(invitation.productType, 'pz_auth');
  });

  test('verifies a signed version 3 invitation with a scoped local CA', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final encodedPublicKey = base64Url
        .encode(publicKey.bytes)
        .replaceAll('=', '');
    final identityDigest = await Sha256().hash(publicKey.bytes);
    final identityFingerprint =
        'sha256:${identityDigest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final certificateBytes = utf8.encode('test-installation-ca-der');
    final encodedCertificate = base64Url
        .encode(certificateBytes)
        .replaceAll('=', '');
    final certificateDigest = await Sha256().hash(certificateBytes);
    final certificateFingerprint =
        'sha256:${certificateDigest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(
      (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final expiresAt = issuedAt.add(const Duration(minutes: 5));
    final fields = <String>[
      'pr0jectzer0-enrollment-v3',
      '3',
      'server-local',
      'Pr0jectZer0 Local',
      'https://192.168.1.20:8443',
      'The Bostrom Group, LLC',
      'pz_auth',
      'enroll-v3',
      'single-use-secret',
      (issuedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      encodedPublicKey,
      identityFingerprint,
      encodedCertificate,
      certificateFingerprint,
    ];
    final signature = await algorithm.sign(
      utf8.encode(fields.join('\n')),
      keyPair: keyPair,
    );
    final payload = Uri(
      scheme: 'pr0jectzer0',
      host: 'enroll',
      queryParameters: <String, String>{
        'v': '3',
        'server_id': 'server-local',
        'server_name': 'Pr0jectZer0 Local',
        'server_url': 'https://192.168.1.20:8443',
        'organization': 'The Bostrom Group, LLC',
        'device_type': 'pz_auth',
        'challenge_id': 'enroll-v3',
        'secret': 'single-use-secret',
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'server_public_key': encodedPublicKey,
        'server_fingerprint': identityFingerprint,
        'tls_ca': encodedCertificate,
        'tls_ca_fingerprint': certificateFingerprint,
        'signature': base64Url.encode(signature.bytes).replaceAll('=', ''),
      },
    ).toString();

    final invitation = await const EnrollmentPayloadParser().parse(payload);

    expect(invitation.version, 3);
    expect(invitation.tlsCaCertificate, encodedCertificate);
    expect(invitation.tlsCaFingerprint, certificateFingerprint);

    final request = await enrollment.prepareEnrollment(
      invitation: invitation,
      deviceName: 'Test Phone',
      platform: 'android',
    );
    await enrollment.submitEnrollment(invitation: invitation, request: request);
    expect(api.lastTrustedCaCertificate, encodedCertificate);
    expect(
      enrollment.snapshot.trustedSystems.single.tlsCaFingerprint,
      certificateFingerprint,
    );
  });

  test('verifies a signed administrator activation code', () async {
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final encodedPublicKey = base64Url
        .encode(publicKey.bytes)
        .replaceAll('=', '');
    final digest = await Sha256().hash(publicKey.bytes);
    final fingerprint =
        'sha256:${digest.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
    final issuedAt = DateTime.fromMillisecondsSinceEpoch(
      (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final expiresAt = issuedAt.add(const Duration(minutes: 5));
    final fields = <String>[
      'pr0jectzer0-administrator-activation-v1',
      '1',
      'administrator_invitation',
      'server-2',
      'Pr0jectZer0 Secure Lab',
      'https://security.example.com:8443',
      'The Bostrom Group, LLC',
      'pz_auth',
      'invite-1',
      'admin-2',
      'Grace',
      'Hopper',
      'Security Lead',
      'security_administrator',
      'single-use-activation-secret',
      (issuedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      encodedPublicKey,
      fingerprint,
    ];
    final signature = await algorithm.sign(
      utf8.encode(fields.join('\n')),
      keyPair: keyPair,
    );
    final payload = Uri(
      scheme: 'pr0jectzer0',
      host: 'activate',
      queryParameters: <String, String>{
        'v': '1',
        'purpose': 'administrator_invitation',
        'server_id': 'server-2',
        'server_name': 'Pr0jectZer0 Secure Lab',
        'server_url': 'https://security.example.com:8443',
        'organization': 'The Bostrom Group, LLC',
        'device_type': 'pz_auth',
        'challenge_id': 'invite-1',
        'administrator_id': 'admin-2',
        'first_name': 'Grace',
        'last_name': 'Hopper',
        'position': 'Security Lead',
        'role': 'security_administrator',
        'secret': 'single-use-activation-secret',
        'issued_at': issuedAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'server_public_key': encodedPublicKey,
        'server_fingerprint': fingerprint,
        'signature': base64Url.encode(signature.bytes).replaceAll('=', ''),
      },
    ).toString();

    final invitation = await const EnrollmentPayloadParser().parse(payload);

    expect(invitation.purpose, EnrollmentPurpose.administratorInvitation);
    expect(invitation.administratorId, 'admin-2');
    expect(invitation.administratorRole, 'security_administrator');
    expect(invitation.requiresActivationPin, isTrue);
  });

  test('explains when a login QR is scanned as an enrollment QR', () async {
    await expectLater(
      enrollment.parseInvitation(
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

  test('rejects expired enrollment invitations', () async {
    final now = DateTime.now().toUtc();
    await expectLater(
      enrollment.parseInvitation(
        _payload(
          issuedAt: now.subtract(const Duration(hours: 2)),
          expiresAt: now.subtract(const Duration(hours: 1)),
        ),
      ),
      throwsA(isA<EnrollmentException>()),
    );
  });

  test('prepares a signed device registration request', () async {
    final invitation = await enrollment.parseInvitation(_payload());
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
    final invitation = await enrollment.parseInvitation(_payload());
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
      final invitation = await enrollment.parseInvitation(_payload());
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

  test('submits an activation PIN through the invitation endpoint', () async {
    final invitation = await const EnrollmentPayloadParser(
      allowLegacyInsecure: true,
    ).parse(_activationPayload());
    final request = await enrollment.prepareEnrollment(
      invitation: invitation,
      deviceName: 'Replacement Phone',
      platform: 'android',
    );

    await enrollment.submitEnrollment(
      invitation: invitation,
      request: request,
      activationPin: '728194',
    );

    expect(api.lastEnrollment?['_activation_kind'], 'lost_device_recovery');
    expect(api.lastEnrollment?['activation_secret'], invitation.nonce);
    expect(api.lastEnrollment?['pin'], '728194');
    expect(
      enrollment.snapshot.trustedSystems.single.administratorId,
      'admin-1',
    );
  });
}

class _FakeAuthApiClient implements AuthApiClient {
  Map<String, Object>? lastEnrollment;
  String? lastTrustedCaCertificate;

  @override
  Future<EnrolledDevice> completeEnrollment({
    required Uri serverBaseUrl,
    required Map<String, Object> payload,
    String? trustedCaCertificate,
  }) async {
    lastEnrollment = payload;
    lastTrustedCaCertificate = trustedCaCertificate;
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
    String? trustedCaCertificate,
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

String _activationPayload() {
  final issued = DateTime.now().toUtc();
  return Uri(
    scheme: 'pr0jectzer0',
    host: 'activate',
    queryParameters: <String, String>{
      'v': '1',
      'purpose': 'lost_device_recovery',
      'server_id': 'system-1',
      'server_name': 'Pr0jectZer0 Local',
      'server_url': 'http://192.168.1.20:8080',
      'organization': 'The Bostrom Group, LLC',
      'device_type': 'pz_auth',
      'challenge_id': 'recovery-1',
      'administrator_id': 'admin-1',
      'first_name': 'Ada',
      'last_name': 'Lovelace',
      'position': 'Owner',
      'role': 'owner',
      'secret': 'single-use-recovery-secret',
      'issued_at': issued.toIso8601String(),
      'expires_at': issued.add(const Duration(minutes: 5)).toIso8601String(),
    },
  ).toString();
}
