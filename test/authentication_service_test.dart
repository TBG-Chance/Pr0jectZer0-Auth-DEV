import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/auth/in_memory_authentication_service.dart';

void main() {
  group('InMemoryAuthenticationService', () {
    late InMemoryAuthenticationService service;

    setUp(() async {
      service = InMemoryAuthenticationService();
      await service.initialize();
    });

    tearDown(() => service.dispose());

    test('creates a PIN and authenticates a valid PIN', () async {
      await service.createPin('739204');

      final result = await service.authenticateWithPin('739204');

      expect(result.success, isTrue);
      expect(service.isAuthenticated, isTrue);
      expect(result.session, isNotNull);
    });

    test('rejects an incorrect PIN', () async {
      await service.createPin('739204');

      final result = await service.authenticateWithPin('000000');

      expect(result.success, isFalse);
      expect(result.errorCode, 'invalid_pin');
      expect(service.isAuthenticated, isFalse);
    });

    test('locks an authenticated session', () async {
      await service.createPin('739204');
      await service.authenticateWithPin('739204');

      await service.lock();

      expect(service.isAuthenticated, isFalse);
      expect(service.currentSession, isNull);
    });
  });
}
