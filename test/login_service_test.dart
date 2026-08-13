import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/crypto/crypto_models.dart';
import 'package:pr0jectzer0_auth/core/crypto/crypto_service.dart';
import 'package:pr0jectzer0_auth/core/enrollment/trusted_system_store.dart';
import 'package:pr0jectzer0_auth/core/login/registered_device_login_service.dart';
import 'package:pr0jectzer0_auth/core/models/trusted_system.dart';
import 'package:pr0jectzer0_auth/core/network/auth_api_client.dart';
import 'package:pr0jectzer0_auth/core/storage/in_memory_secure_storage_service.dart';

void main() {
  test(
    'signs the exact Go login payload and uses the server device ID',
    () async {
      final storage = InMemorySecureStorageService();
      await storage.initialize();
      final store = TrustedSystemStore(storage);
      await store.writeAll(<TrustedSystem>[
        TrustedSystem(
          id: 'authdev-server-assigned',
          systemId: 'server-1',
          displayName: 'Pr0jectZer0 Lab',
          organization: 'The Bostrom Group',
          productType: 'Pr0jectZer0 management platform',
          serverBaseUrl: 'https://security.example.test',
          publicKey: '',
          enrolledAt: DateTime.now().toUtc(),
          trusted: true,
        ),
      ]);
      final crypto = _CapturingCryptoService();
      final api = _CapturingAuthApiClient();
      final service = RegisteredDeviceLoginService(
        crypto: crypto,
        trustedSystems: store,
        api: api,
        allowLegacyInsecure: true,
      );
      final expiresAt = DateTime.now().toUtc().add(const Duration(minutes: 1));
      final payload = Uri(
        scheme: 'pr0jectzer0',
        host: 'login',
        queryParameters: <String, String>{
          'v': '1',
          'server_id': 'server-1',
          'challenge_id': 'login-123',
          'nonce': 'nonce-456',
          'expires_at': expiresAt.toIso8601String(),
        },
      ).toString();

      final challenge = await service.parseChallenge(payload);
      await service.approve(challenge);

      final unixSeconds = expiresAt.millisecondsSinceEpoch ~/ 1000;
      expect(
        utf8.decode(crypto.lastSignedPayload!),
        'pr0jectzer0-login-v1\nlogin-123\nnonce-456\n$unixSeconds',
      );
      expect(api.deviceId, 'authdev-server-assigned');
      expect(api.signature, 'test-signature');
      await storage.dispose();
    },
  );

  test('verifies and approves a server-signed version 2 login code', () async {
    final storage = InMemorySecureStorageService();
    await storage.initialize();
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final encodedPublicKey = base64Url
        .encode(publicKey.bytes)
        .replaceAll('=', '');
    final store = TrustedSystemStore(storage);
    await store.writeAll(<TrustedSystem>[
      TrustedSystem(
        id: 'authdev-v2',
        systemId: 'server-v2',
        displayName: 'Pr0jectZer0 Secure Lab',
        organization: 'The Bostrom Group, LLC',
        productType: 'Pr0jectZer0 management platform',
        serverBaseUrl: 'https://security.example.test:8443',
        publicKey: encodedPublicKey,
        enrolledAt: DateTime.now().toUtc(),
        trusted: true,
      ),
    ]);
    final crypto = _CapturingCryptoService();
    final api = _CapturingAuthApiClient();
    final service = RegisteredDeviceLoginService(
      crypto: crypto,
      trustedSystems: store,
      api: api,
    );
    final now = DateTime.now().toUtc();
    final expiresAt = DateTime.fromMillisecondsSinceEpoch(
      (now.add(const Duration(minutes: 2)).millisecondsSinceEpoch ~/ 1000) *
          1000,
      isUtc: true,
    );
    final challengePayload = <String>[
      'pr0jectzer0-login-challenge-v2',
      '2',
      'server-v2',
      'https://security.example.test:8443',
      'login-v2',
      'nonce-v2',
      (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
    ].join('\n');
    final serverSignature = await algorithm.sign(
      utf8.encode(challengePayload),
      keyPair: keyPair,
    );
    final payload = Uri(
      scheme: 'pr0jectzer0',
      host: 'login',
      queryParameters: <String, String>{
        'v': '2',
        'server_id': 'server-v2',
        'server_url': 'https://security.example.test:8443',
        'challenge_id': 'login-v2',
        'nonce': 'nonce-v2',
        'expires_at': expiresAt.toIso8601String(),
        'signature': base64Url
            .encode(serverSignature.bytes)
            .replaceAll('=', ''),
      },
    ).toString();

    final challenge = await service.parseChallenge(payload);
    await service.approve(challenge);

    final unixSeconds = expiresAt.millisecondsSinceEpoch ~/ 1000;
    expect(
      utf8.decode(crypto.lastSignedPayload!),
      'pr0jectzer0-login-v2\nserver-v2\nhttps://security.example.test:8443\n'
      'login-v2\nnonce-v2\n$unixSeconds',
    );
    expect(api.deviceId, 'authdev-v2');
    await storage.dispose();
  });

  test('verifies, displays, and signs version 3 browser context', () async {
    final storage = InMemorySecureStorageService();
    await storage.initialize();
    final algorithm = Ed25519();
    final keyPair = await algorithm.newKeyPair();
    final publicKey = await keyPair.extractPublicKey();
    final encodedPublicKey = base64Url
        .encode(publicKey.bytes)
        .replaceAll('=', '');
    final store = TrustedSystemStore(storage);
    await store.writeAll(<TrustedSystem>[
      TrustedSystem(
        id: 'authdev-v3',
        systemId: 'server-v3',
        displayName: 'Pr0jectZer0 Production',
        organization: 'The Bostrom Group, LLC',
        productType: 'Pr0jectZer0 management platform',
        serverBaseUrl: 'https://security.example.test',
        publicKey: encodedPublicKey,
        enrolledAt: DateTime.now().toUtc(),
        trusted: true,
      ),
    ]);
    final crypto = _CapturingCryptoService();
    final api = _CapturingAuthApiClient();
    final service = RegisteredDeviceLoginService(
      crypto: crypto,
      trustedSystems: store,
      api: api,
    );
    final requestedAt = DateTime.fromMillisecondsSinceEpoch(
      (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000) * 1000,
      isUtc: true,
    );
    final expiresAt = requestedAt.add(const Duration(minutes: 5));
    final values = <String, String>{
      'v': '3',
      'server_id': 'server-v3',
      'server_name': 'Pr0jectZer0 Production',
      'organization': 'The Bostrom Group, LLC',
      'server_url': 'https://security.example.test',
      'challenge_id': 'login-v3',
      'nonce': 'nonce-v3',
      'requested_at': requestedAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'browser_name': 'Microsoft Edge',
      'operating_system': 'Windows',
      'network_address': '198.51.100.18',
      'verification_code': '123456',
    };
    final serverPayload = <String>[
      'pr0jectzer0-login-challenge-v3',
      '3',
      'server-v3',
      'Pr0jectZer0 Production',
      'The Bostrom Group, LLC',
      'https://security.example.test',
      'login-v3',
      'nonce-v3',
      (requestedAt.millisecondsSinceEpoch ~/ 1000).toString(),
      (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
      'Microsoft Edge',
      'Windows',
      '198.51.100.18',
      '123456',
    ].join('\n');
    final serverSignature = await algorithm.sign(
      utf8.encode(serverPayload),
      keyPair: keyPair,
    );
    values['signature'] = base64Url
        .encode(serverSignature.bytes)
        .replaceAll('=', '');
    final payload = Uri(
      scheme: 'pr0jectzer0',
      host: 'login',
      queryParameters: values,
    ).toString();

    final challenge = await service.parseChallenge(payload);
    expect(challenge.verificationCode, '123456');
    expect(challenge.browserName, 'Microsoft Edge');
    expect(challenge.networkAddress, '198.51.100.18');
    await service.approve(challenge);

    expect(
      utf8.decode(crypto.lastSignedPayload!),
      'pr0jectzer0-login-v3\nserver-v3\nPr0jectZer0 Production\n'
      'The Bostrom Group, LLC\nhttps://security.example.test\n'
      'login-v3\nnonce-v3\n'
      '${requestedAt.millisecondsSinceEpoch ~/ 1000}\n'
      '${expiresAt.millisecondsSinceEpoch ~/ 1000}\n'
      'Microsoft Edge\nWindows\n198.51.100.18\n123456',
    );

    final tamperedValues = Map<String, String>.from(values)
      ..['browser_name'] = 'Google Chrome';
    final tamperedPayload = Uri(
      scheme: 'pr0jectzer0',
      host: 'login',
      queryParameters: tamperedValues,
    ).toString();
    await expectLater(
      service.parseChallenge(tamperedPayload),
      throwsA(isA<Exception>()),
    );

    final unsupportedPayload = Uri.parse(payload).replace(
      queryParameters: <String, String>{
        ...Uri.parse(payload).queryParameters,
        'unexpected': 'value',
      },
    );
    await expectLater(
      service.parseChallenge(unsupportedPayload.toString()),
      throwsA(isA<Exception>()),
    );
    await storage.dispose();
  });
}

class _CapturingCryptoService implements CryptoService {
  List<int>? lastSignedPayload;

  @override
  Future<SignatureEnvelope> sign(List<int> payload) async {
    lastSignedPayload = List<int>.from(payload);
    return SignatureEnvelope(
      algorithm: 'ed25519',
      keyId: 'key-1',
      signatureBase64Url: 'test-signature',
      signedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<void> deleteDeviceIdentity() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<DevicePublicKey> ensureDeviceIdentity() => throw UnimplementedError();

  @override
  Future<DevicePublicKey?> getDevicePublicKey() async => null;

  @override
  Future<bool> hasDeviceIdentity() async => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<DevicePublicKey> rotateDeviceIdentity() => throw UnimplementedError();

  @override
  Future<bool> verify({
    required List<int> payload,
    required SignatureEnvelope signature,
    DevicePublicKey? publicKey,
  }) async => false;
}

class _CapturingAuthApiClient implements AuthApiClient {
  String? deviceId;
  String? signature;

  @override
  Future<void> approveLogin({
    required Uri serverBaseUrl,
    required String challengeId,
    required String nonce,
    required String deviceId,
    required String signature,
    String? trustedCaCertificate,
  }) async {
    this.deviceId = deviceId;
    this.signature = signature;
  }

  @override
  Future<EnrolledDevice> completeEnrollment({
    required Uri serverBaseUrl,
    required Map<String, Object> payload,
    String? trustedCaCertificate,
  }) => throw UnimplementedError();
}
