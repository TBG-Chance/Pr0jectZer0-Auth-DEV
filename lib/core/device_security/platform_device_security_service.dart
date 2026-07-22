import 'dart:async';
import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../storage/secure_storage_service.dart';
import 'device_security_models.dart';
import 'device_security_service.dart';

class PlatformDeviceSecurityService implements DeviceSecurityService {
  PlatformDeviceSecurityService({required this._secureStorage});

  static const MethodChannel _channel = MethodChannel('pr0jectzer0/device_security');
  final SecureStorageService _secureStorage;
  final LocalAuthentication _localAuth = LocalAuthentication();
  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  final StreamController<DeviceSecurityReport> _controller = StreamController.broadcast();

  DeviceSecurityReport? _currentReport;
  bool _disposed = false;

  @override
  DeviceSecurityReport? get currentReport => _currentReport;

  @override
  Stream<DeviceSecurityReport> get reportChanges => _controller.stream;

  @override
  Future<void> initialize() async {
    await refresh();
  }

  @override
  Future<DeviceSecurityReport> refresh() async {
    if (_disposed) throw StateError('DeviceSecurityService has been disposed.');

    final package = await PackageInfo.fromPlatform();
    final device = await _readDeviceIdentity();
    final native = await _readNativeChecks();
    final biometrics = await _readBiometrics();
    final secureStorage = await _probeSecureStorage();

    final report = DeviceSecurityReport(
      generatedAt: DateTime.now(),
      platform: device.platform,
      deviceName: device.name,
      osVersion: device.osVersion,
      appVersion: package.version,
      buildNumber: package.buildNumber,
      checks: <SecurityCheck>[
        SecurityCheck(
          name: 'Screen lock',
          status: native.screenLockEnabled == true
              ? SecurityCheckStatus.passed
              : native.screenLockEnabled == false
                  ? SecurityCheckStatus.failed
                  : SecurityCheckStatus.unknown,
          detail: native.screenLockEnabled == true
              ? 'A device credential is configured.'
              : native.screenLockEnabled == false
                  ? 'No secure device credential is configured.'
                  : 'This platform did not expose screen-lock state.',
        ),
        SecurityCheck(
          name: 'Biometrics',
          status: biometrics.enrolled
              ? SecurityCheckStatus.passed
              : biometrics.supported
                  ? SecurityCheckStatus.failed
                  : SecurityCheckStatus.unavailable,
          detail: biometrics.detail,
        ),
        SecurityCheck(
          name: 'Secure storage',
          status: secureStorage ? SecurityCheckStatus.passed : SecurityCheckStatus.failed,
          detail: secureStorage
              ? 'Platform-protected storage is readable and writable.'
              : 'Secure storage probe failed.',
        ),
        SecurityCheck(
          name: 'Hardware-backed keystore',
          status: native.hardwareBacked == true
              ? SecurityCheckStatus.passed
              : native.hardwareBacked == false
                  ? SecurityCheckStatus.unavailable
                  : SecurityCheckStatus.unknown,
          detail: native.hardwareBacked == true
              ? 'Hardware-backed key protection is available.'
              : 'Hardware backing could not be verified.',
        ),
        SecurityCheck(
          name: 'Device integrity',
          status: native.compromised == true
              ? SecurityCheckStatus.failed
              : native.compromised == false
                  ? SecurityCheckStatus.passed
                  : SecurityCheckStatus.unknown,
          detail: native.compromised == true
              ? 'Root or jailbreak indicators were detected.'
              : native.compromised == false
                  ? 'No basic compromise indicators were detected.'
                  : 'Integrity state is unavailable on this platform.',
        ),
        SecurityCheck(
          name: 'Emulator or simulator',
          status: device.isPhysical == false
              ? SecurityCheckStatus.failed
              : device.isPhysical == true
                  ? SecurityCheckStatus.passed
                  : SecurityCheckStatus.unknown,
          detail: device.isPhysical == false
              ? 'The app is running on an emulator or simulator.'
              : 'The app appears to be running on physical hardware.',
        ),
        SecurityCheck(
          name: 'Developer mode',
          status: native.developerMode == true
              ? SecurityCheckStatus.failed
              : native.developerMode == false
                  ? SecurityCheckStatus.passed
                  : SecurityCheckStatus.unknown,
          detail: native.developerMode == true
              ? 'Developer options are enabled.'
              : native.developerMode == false
                  ? 'Developer options are disabled.'
                  : 'Developer-mode state is unavailable.',
        ),
        SecurityCheck(
          name: 'Debug build',
          status: kDebugMode ? SecurityCheckStatus.failed : SecurityCheckStatus.passed,
          detail: kDebugMode ? 'This is a debug build.' : 'This is not a debug build.',
        ),
        const SecurityCheck(
          name: 'Telemetry',
          status: SecurityCheckStatus.passed,
          detail: 'Telemetry is disabled.',
        ),
      ],
    );

    _currentReport = report;
    _controller.add(report);
    return report;
  }

  Future<_DeviceIdentity> _readDeviceIdentity() async {
    if (Platform.isAndroid) {
      final info = await _deviceInfo.androidInfo;
      return _DeviceIdentity(
        platform: 'Android',
        name: '${info.manufacturer} ${info.model}'.trim(),
        osVersion: 'Android ${info.version.release} (SDK ${info.version.sdkInt})',
        isPhysical: info.isPhysicalDevice,
      );
    }
    if (Platform.isIOS) {
      final info = await _deviceInfo.iosInfo;
      return _DeviceIdentity(
        platform: 'iOS',
        name: '${info.model} (${info.utsname.machine})',
        osVersion: '${info.systemName} ${info.systemVersion}',
        isPhysical: info.isPhysicalDevice,
      );
    }
    return _DeviceIdentity(
      platform: defaultTargetPlatform.name,
      name: 'Unknown device',
      osVersion: Platform.operatingSystemVersion,
      isPhysical: null,
    );
  }

  Future<_BiometricState> _readBiometrics() async {
    try {
      final supported = await _localAuth.isDeviceSupported();
      final available = await _localAuth.getAvailableBiometrics();
      return _BiometricState(
        supported: supported,
        enrolled: available.isNotEmpty,
        detail: available.isNotEmpty
            ? 'Enrolled: ${available.map((type) => type.name).join(', ')}.'
            : supported
                ? 'Biometric hardware is supported, but none are enrolled.'
                : 'Biometric authentication is unavailable.',
      );
    } on Object {
      return const _BiometricState(
        supported: false,
        enrolled: false,
        detail: 'Biometric state could not be read.',
      );
    }
  }

  Future<bool> _probeSecureStorage() async {
    const key = 'device_security_probe';
    final value = DateTime.now().microsecondsSinceEpoch.toString();
    try {
      await _secureStorage.write(key: key, value: value);
      final readBack = await _secureStorage.read(key);
      await _secureStorage.delete(key);
      return readBack == value;
    } on Object {
      return false;
    }
  }

  Future<_NativeChecks> _readNativeChecks() async {
    try {
      final values = await _channel.invokeMapMethod<String, Object?>('getSecurityState');
      return _NativeChecks(
        screenLockEnabled: values?['screenLockEnabled'] as bool?,
        compromised: values?['compromised'] as bool?,
        developerMode: values?['developerMode'] as bool?,
        hardwareBacked: values?['hardwareBacked'] as bool?,
      );
    } on MissingPluginException {
      return const _NativeChecks();
    } on PlatformException {
      return const _NativeChecks();
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _controller.close();
  }
}

class _DeviceIdentity {
  const _DeviceIdentity({required this.platform, required this.name, required this.osVersion, required this.isPhysical});
  final String platform;
  final String name;
  final String osVersion;
  final bool? isPhysical;
}

class _BiometricState {
  const _BiometricState({required this.supported, required this.enrolled, required this.detail});
  final bool supported;
  final bool enrolled;
  final String detail;
}

class _NativeChecks {
  const _NativeChecks({this.screenLockEnabled, this.compromised, this.developerMode, this.hardwareBacked});
  final bool? screenLockEnabled;
  final bool? compromised;
  final bool? developerMode;
  final bool? hardwareBacked;
}
