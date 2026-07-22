import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/approval/local_approval_service.dart';
import 'core/auth/pin_credential_store.dart';
import 'core/auth/biometric_authenticator.dart';
import 'core/auth/secure_authentication_service.dart';
import 'core/crypto/secure_ed25519_crypto_service.dart';
import 'core/device_security/platform_device_security_service.dart';
import 'core/enrollment/local_enrollment_service.dart';
import 'core/enrollment/trusted_system_store.dart';
import 'core/login/registered_device_login_service.dart';
import 'core/network/auth_api_client.dart';
import 'core/services/app_services.dart';
import 'core/storage/flutter_secure_storage_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final secureStorage = FlutterSecureStorageService();
  await secureStorage.initialize();

  final authenticationService = SecureAuthenticationService(
    PinCredentialStore(secureStorage),
    biometrics: LocalBiometricAuthenticator(),
  );
  await authenticationService.initialize();

  final cryptoService = SecureEd25519CryptoService(secureStorage);
  await cryptoService.initialize();

  final approvalService = LocalApprovalService(
    crypto: cryptoService,
    secureStorage: secureStorage,
  );
  await approvalService.initialize();

  final apiClient = HttpAuthApiClient();
  final trustedSystems = TrustedSystemStore(secureStorage);
  final enrollmentService = LocalEnrollmentService(
    crypto: cryptoService,
    trustedSystems: trustedSystems,
    api: apiClient,
  );
  await enrollmentService.initialize();

  final loginService = RegisteredDeviceLoginService(
    crypto: cryptoService,
    trustedSystems: trustedSystems,
    api: apiClient,
  );

  final deviceSecurityService = PlatformDeviceSecurityService(
    secureStorage: secureStorage,
  );
  await deviceSecurityService.initialize();

  runApp(
    AppServices(
      authentication: authenticationService,
      approval: approvalService,
      secureStorage: secureStorage,
      deviceSecurity: deviceSecurityService,
      crypto: cryptoService,
      enrollment: enrollmentService,
      login: loginService,
      child: const Pr0jectZer0AuthApp(),
    ),
  );
}
