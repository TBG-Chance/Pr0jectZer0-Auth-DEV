import 'package:flutter/widgets.dart';

import '../approval/approval_service.dart';
import '../auth/authentication_service.dart';
import '../crypto/crypto_service.dart';
import '../device_security/device_security_service.dart';
import '../enrollment/enrollment_service.dart';
import '../login/login_service.dart';
import '../storage/secure_storage_service.dart';

class AppServices extends InheritedWidget {
  const AppServices({
    required this.authentication,
    required this.approval,
    required this.secureStorage,
    required this.deviceSecurity,
    required this.crypto,
    required this.enrollment,
    required this.login,
    required super.child,
    super.key,
  });

  final AuthenticationService authentication;
  final ApprovalService approval;
  final SecureStorageService secureStorage;
  final DeviceSecurityService deviceSecurity;
  final CryptoService crypto;
  final EnrollmentService enrollment;
  final LoginService login;

  static AppServices of(BuildContext context) {
    final services = context.dependOnInheritedWidgetOfExactType<AppServices>();
    assert(services != null, 'AppServices was not found in the widget tree.');
    return services!;
  }

  static AppServices? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppServices>();
  }

  @override
  bool updateShouldNotify(AppServices oldWidget) {
    return authentication != oldWidget.authentication ||
        approval != oldWidget.approval ||
        secureStorage != oldWidget.secureStorage ||
        deviceSecurity != oldWidget.deviceSecurity ||
        crypto != oldWidget.crypto ||
        enrollment != oldWidget.enrollment ||
        login != oldWidget.login;
  }
}
