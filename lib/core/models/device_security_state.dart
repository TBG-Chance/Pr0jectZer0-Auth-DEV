enum DeviceTrustState {
  trusted,
  notEnrolled,
  screenLockRequired,
  requirementsNotMet,
}

class DeviceSecurityState {
  final DeviceTrustState trustState;

  final bool screenLockEnabled;
  final bool biometricsAvailable;
  final bool secureStorageAvailable;
  final bool hardwareBackedKeyStore;
  final bool developerMode;
  final bool rooted;

  const DeviceSecurityState({
    required this.trustState,
    required this.screenLockEnabled,
    required this.biometricsAvailable,
    required this.secureStorageAvailable,
    required this.hardwareBackedKeyStore,
    required this.developerMode,
    required this.rooted,
  });
}
