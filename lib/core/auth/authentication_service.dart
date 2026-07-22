import 'authentication_models.dart';

abstract interface class AuthenticationService {
  AuthenticationSession? get currentSession;

  bool get isAuthenticated;

  Stream<AuthenticationSession?> get sessionChanges;

  Future<void> initialize();

  Future<bool> hasPin();

  Future<void> createPin(String pin);

  Future<void> changePin({
    required String currentPin,
    required String newPin,
  });

  Future<AuthenticationResult> authenticateWithPin(String pin);

  Future<AuthenticationResult> authenticateWithBiometrics();

  Future<void> lock();

  Future<void> dispose();
}
