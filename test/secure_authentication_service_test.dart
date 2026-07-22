import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/auth/pin_credential_store.dart';
import 'package:pr0jectzer0_auth/core/auth/biometric_authenticator.dart';
import 'package:pr0jectzer0_auth/core/auth/secure_authentication_service.dart';
import 'package:pr0jectzer0_auth/core/storage/in_memory_secure_storage_service.dart';

void main() {
  group('SecureAuthenticationService', () {
    late InMemorySecureStorageService storage;
    late SecureAuthenticationService service;

    setUp(() async {
      storage = InMemorySecureStorageService();
      await storage.initialize();
      service = SecureAuthenticationService(
        PinCredentialStore(storage, iterations: 1000),
      );
      await service.initialize();
    });

    tearDown(() async {
      await service.dispose();
      await storage.dispose();
    });

    test('persists a derived PIN credential instead of the raw PIN', () async {
      await service.createPin('739204');

      expect(await service.hasPin(), isTrue);
      final storedValues = storage.debugValues.values.join();
      expect(storedValues, isNot(contains('739204')));
    });

    test('authenticates the correct PIN', () async {
      await service.createPin('739204');

      final result = await service.authenticateWithPin('739204');

      expect(result.success, isTrue);
      expect(service.isAuthenticated, isTrue);
    });

    test('rejects an incorrect PIN', () async {
      await service.createPin('739204');

      final result = await service.authenticateWithPin('928374');

      expect(result.success, isFalse);
      expect(result.errorCode, 'invalid_pin');
    });

    test('credential remains usable by a recreated auth service', () async {
      await service.createPin('739204');
      await service.dispose();

      service = SecureAuthenticationService(
        PinCredentialStore(storage, iterations: 1000),
      );
      await service.initialize();

      final result = await service.authenticateWithPin('739204');
      expect(result.success, isTrue);
    });

    test('creates a biometric session after platform authentication', () async {
      await service.dispose();
      service = SecureAuthenticationService(
        PinCredentialStore(storage, iterations: 1000),
        biometrics: _FakeBiometricAuthenticator(true),
      );
      await service.initialize();

      final result = await service.authenticateWithBiometrics();

      expect(result.success, isTrue);
      expect(result.session?.method.name, 'biometric');
    });
  });
}

class _FakeBiometricAuthenticator implements BiometricAuthenticator {
  const _FakeBiometricAuthenticator(this.result);

  final bool result;

  @override
  Future<bool> authenticate() async => result;
}
