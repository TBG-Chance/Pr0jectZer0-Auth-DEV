import 'dart:async';
import 'dart:math';

import 'authentication_models.dart';
import 'authentication_service.dart';
import 'pin_policy.dart';

/// Development implementation used until SecureStorageService is introduced.
/// It intentionally does not persist the PIN between app launches.
class InMemoryAuthenticationService implements AuthenticationService {
  InMemoryAuthenticationService({
    this.sessionDuration = const Duration(minutes: 5),
  });

  final Duration sessionDuration;
  final StreamController<AuthenticationSession?> _sessionController =
      StreamController<AuthenticationSession?>.broadcast();

  AuthenticationSession? _currentSession;
  String? _pin;
  Timer? _expirationTimer;
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
    if (_currentSession?.isExpired ?? false) {
      _clearSession();
    }
  }

  @override
  Future<bool> hasPin() async {
    _ensureActive();
    return _pin != null;
  }

  @override
  Future<void> createPin(String pin) async {
    _ensureActive();
    if (_pin != null) {
      throw StateError('A PIN has already been created.');
    }
    _validatePin(pin);
    _pin = pin;
  }

  @override
  Future<void> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    _ensureActive();
    if (_pin == null) {
      throw StateError('No PIN has been created.');
    }
    if (currentPin != _pin) {
      throw ArgumentError('The current PIN is incorrect.');
    }
    _validatePin(newPin);
    _pin = newPin;
    await lock();
  }

  @override
  Future<AuthenticationResult> authenticateWithPin(String pin) async {
    _ensureActive();
    if (_pin == null) {
      return const AuthenticationResult.failure(
        errorCode: 'pin_not_configured',
        message: 'Create a PIN before attempting to unlock the app.',
      );
    }

    if (pin != _pin) {
      return const AuthenticationResult.failure(
        errorCode: 'invalid_pin',
        message: 'The PIN is incorrect.',
      );
    }

    return _createSession(AuthenticationMethod.pin);
  }

  @override
  Future<AuthenticationResult> authenticateWithBiometrics() async {
    _ensureActive();
    return const AuthenticationResult.failure(
      errorCode: 'biometrics_not_available',
      message: 'Biometric authentication has not been configured yet.',
    );
  }

  @override
  Future<void> lock() async {
    _ensureActive();
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
    final validationError = PinPolicy.validate(pin);
    if (validationError != null) {
      throw ArgumentError(validationError);
    }
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
