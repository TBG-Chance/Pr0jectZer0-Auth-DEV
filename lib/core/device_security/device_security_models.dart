enum SecurityCheckStatus { passed, failed, unavailable, unknown }

class SecurityCheck {
  const SecurityCheck({required this.name, required this.status, required this.detail});
  final String name;
  final SecurityCheckStatus status;
  final String detail;
  bool get passed => status == SecurityCheckStatus.passed;
}

class DeviceSecurityReport {
  const DeviceSecurityReport({
    required this.generatedAt,
    required this.platform,
    required this.deviceName,
    required this.osVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.checks,
  });

  final DateTime generatedAt;
  final String platform;
  final String deviceName;
  final String osVersion;
  final String appVersion;
  final String buildNumber;
  final List<SecurityCheck> checks;

  bool get requirementsMet => checks
      .where((check) => check.name == 'Screen lock' || check.name == 'Secure storage' || check.name == 'Device integrity')
      .every((check) => check.status == SecurityCheckStatus.passed);

  SecurityCheck check(String name) => checks.firstWhere((item) => item.name == name);

  String toSupportReport() {
    final buffer = StringBuffer()
      ..writeln('Pr0jectZer0 Auth Device Security Report')
      ..writeln('Generated: ${generatedAt.toIso8601String()}')
      ..writeln('Platform: $platform')
      ..writeln('Device: $deviceName')
      ..writeln('OS: $osVersion')
      ..writeln('App: $appVersion ($buildNumber)')
      ..writeln();
    for (final item in checks) {
      buffer.writeln('${item.name}: ${item.status.name} - ${item.detail}');
    }
    buffer.writeln('\nNo keys, PINs, tokens, or server secrets are included.');
    return buffer.toString();
  }
}
