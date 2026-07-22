import 'package:local_auth/local_auth.dart';

abstract interface class BiometricAuthenticator {
  Future<bool> authenticate();
}

class LocalBiometricAuthenticator implements BiometricAuthenticator {
  LocalBiometricAuthenticator({LocalAuthentication? localAuthentication})
    : _localAuthentication = localAuthentication ?? LocalAuthentication();

  final LocalAuthentication _localAuthentication;

  @override
  Future<bool> authenticate() async {
    try {
      if (!await _localAuthentication.isDeviceSupported()) return false;
      final available = await _localAuthentication.getAvailableBiometrics();
      if (available.isEmpty) return false;
      return _localAuthentication.authenticate(
        localizedReason: 'Confirm this Pr0jectZer0 dashboard sign-in',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
        sensitiveTransaction: true,
      );
    } on LocalAuthException {
      return false;
    }
  }
}
