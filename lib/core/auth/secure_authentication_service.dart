import 'dart:async';
import 'dart:math';

import 'authentication_models.dart';
import 'authentication_service.dart';
import 'biometric_authenticator.dart';
import 'pin_credential_store.dart';
import 'pin_policy.dart';

class SecureAuthenticationService implements AuthenticationService {
  SecureAuthenticationService(
    this._pinCredentials, {
    BiometricAuthenticator? biometrics,
    this.sessionDuration = const Duration(minutes: 5),
  }) : _biometrics = biometrics;

  final PinCredentialStore _pinCredentials;
  final BiometricAuthenticator? _biometrics;
  final Duration sessionDuration;
  final StreamController<AuthenticationSession?> _sessionController =
      StreamController<AuthenticationSession?>.broadcast();

  AuthenticationSession? _currentSession;
  Timer? _expirationTimer;
  bool _initialized = false;
  bool _disposed = false;

  @override
  AuthenticationSession? get currentSession {
    if (_currentSession?.isExpired ?? false) {
      _clearSession();
    }
    return _currentSession;
  }

  @override
  bool get isAuthenticated => currentSession != null;

  @override
  Stream<AuthenticationSession?> get sessionChanges =>
      _sessionController.stream;

  @override
  Future<void> initialize() async {
    _ensureActive();
    _initialized = true;
  }

  @override
  Future<bool> hasPin() async {
    _ensureReady();
    return _pinCredentials.exists();
  }

  @override
  Future<void> createPin(String pin) async {
    _ensureReady();
    _validatePin(pin);
    await _pinCredentials.create(pin);
  }

  @override
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    _ensureReady();
    if (!await _pinCredentials.exists()) {
      throw StateError('No PIN has been created.');
    }
    if (!await _pinCredentials.verify(currentPin)) {
      throw ArgumentError('The current PIN is incorrect.');
    }

    _validatePin(newPin);
    await _pinCredentials.replace(newPin);
    await lock();
  }

  @override
  Future<AuthenticationResult> authenticateWithPin(String pin) async {
    _ensureReady();
    if (!await _pinCredentials.exists()) {
      return const AuthenticationResult.failure(
        errorCode: 'pin_not_configured',
        message: 'Create a PIN before attempting to unlock the app.',
      );
    }

    if (!await _pinCredentials.verify(pin)) {
      return const AuthenticationResult.failure(
        errorCode: 'invalid_pin',
        message: 'The PIN is incorrect.',
      );
    }

    return _createSession(AuthenticationMethod.pin);
  }

  @override
  Future<AuthenticationResult> authenticateWithBiometrics() async {
    _ensureReady();
    final biometrics = _biometrics;
    if (biometrics == null) {
      return const AuthenticationResult.failure(
        errorCode: 'biometrics_not_available',
        message: 'Biometric authentication is unavailable on this device.',
      );
    }
    final authenticated = await biometrics.authenticate();
    if (!authenticated) {
      return const AuthenticationResult.failure(
        errorCode: 'biometric_authentication_failed',
        message: 'Biometric authentication was cancelled or unsuccessful.',
      );
    }
    return _createSession(AuthenticationMethod.biometric);
  }

  @override
  Future<void> lock() async {
    _ensureReady();
    _clearSession();
  }

  AuthenticationResult _createSession(AuthenticationMethod method) {
    final authenticatedAt = DateTime.now();
    final session = AuthenticationSession(
      id: _randomId(),
      method: method,
      authenticatedAt: authenticatedAt,
      expiresAt: authenticatedAt.add(sessionDuration),
    );

    _expirationTimer?.cancel();
    _currentSession = session;
    _sessionController.add(session);
    _expirationTimer = Timer(sessionDuration, _clearSession);
    return AuthenticationResult.success(session);
  }

  void _clearSession() {
    _expirationTimer?.cancel();
    _expirationTimer = null;
    if (_currentSession == null) return;

    _currentSession = null;
    if (!_sessionController.isClosed) {
      _sessionController.add(null);
    }
  }

  void _validatePin(String pin) {
    final error = PinPolicy.validate(pin);
    if (error != null) throw ArgumentError(error);
  }

  String _randomId() {
    final random = Random.secure();
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    return '$timestamp-$suffix';
  }

  void _ensureReady() {
    _ensureActive();
    if (!_initialized) {
      throw StateError('AuthenticationService has not been initialized.');
    }
  }

  void _ensureActive() {
    if (_disposed) {
      throw StateError('AuthenticationService has been disposed.');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _expirationTimer?.cancel();
    await _sessionController.close();
  }
}
