import 'dart:convert';

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
  }) async {
    this.deviceId = deviceId;
    this.signature = signature;
  }

  @override
  Future<EnrolledDevice> completeEnrollment({
    required Uri serverBaseUrl,
    required Map<String, Object> payload,
  }) => throw UnimplementedError();
}
