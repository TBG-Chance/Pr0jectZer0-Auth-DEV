import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/crypto/secure_ed25519_crypto_service.dart';
import 'package:pr0jectzer0_auth/core/storage/in_memory_secure_storage_service.dart';

void main() {
  late InMemorySecureStorageService storage;
  late SecureEd25519CryptoService crypto;

  setUp(() async {
    storage = InMemorySecureStorageService();
    await storage.initialize();
    crypto = SecureEd25519CryptoService(storage);
    await crypto.initialize();
  });

  tearDown(() async {
    await crypto.dispose();
    await storage.dispose();
  });

  test('creates and persists one device identity', () async {
    final first = await crypto.ensureDeviceIdentity();
    final second = await crypto.ensureDeviceIdentity();

    expect(first.keyId, second.keyId);
    expect(first.publicKeyBase64Url, second.publicKeyBase64Url);
    expect(await crypto.hasDeviceIdentity(), isTrue);
  });

  test('signs and verifies payloads', () async {
    await crypto.ensureDeviceIdentity();
    final payload = utf8.encode('approval-request-123');
    final signature = await crypto.sign(payload);

    expect(await crypto.verify(payload: payload, signature: signature), isTrue);
    expect(
      await crypto.verify(
        payload: utf8.encode('modified'),
        signature: signature,
      ),
      isFalse,
    );
  });

  test(
    'rotation replaces the identity and invalidates old signatures',
    () async {
      final first = await crypto.ensureDeviceIdentity();
      final payload = utf8.encode('challenge');
      final signature = await crypto.sign(payload);

      final second = await crypto.rotateDeviceIdentity();

      expect(second.keyId, isNot(first.keyId));
      expect(
        await crypto.verify(payload: payload, signature: signature),
        isFalse,
      );
    },
  );
}
