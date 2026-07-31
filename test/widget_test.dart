import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_models.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_service.dart';
import 'package:pr0jectzer0_auth/core/login/login_models.dart';
import 'package:pr0jectzer0_auth/core/models/trusted_system.dart';
import 'package:pr0jectzer0_auth/features/approvals/login_approval_screen.dart';
import 'package:pr0jectzer0_auth/shared/widgets/device_status_banner.dart';

void main() {
  testWidgets('device banner follows persisted enrollment state', (
    tester,
  ) async {
    final enrollment = _FakeEnrollmentService();
    addTearDown(enrollment.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EnrollmentStatusBanner(enrollment: enrollment)),
      ),
    );

    expect(find.text('Device Not Enrolled'), findsOneWidget);

    enrollment.emit(
      EnrollmentSnapshot(
        status: EnrollmentStatus.enrolled,
        trustedSystems: <TrustedSystem>[
          TrustedSystem(
            id: 'device-1',
            systemId: 'server-1',
            displayName: 'Pr0jectZer0 Lab',
            organization: 'Test Organization',
            productType: 'management-platform',
            serverBaseUrl: 'http://192.168.1.20:8080',
            publicKey: '',
            enrolledAt: DateTime.utc(2026),
            trusted: true,
          ),
        ],
      ),
    );
    await tester.pump();

    expect(find.text('Trusted Device'), findsOneWidget);
    expect(find.text('Device Not Enrolled'), findsNothing);
  });

  testWidgets(
    'login approval shows signed browser context and comparison code',
    (tester) async {
      final system = TrustedSystem(
        id: 'device-1',
        systemId: 'server-1',
        displayName: 'Pr0jectZer0 Production',
        organization: 'The Bostrom Group, LLC',
        productType: 'management-platform',
        serverBaseUrl: 'https://security.example.test',
        publicKey: 'public-key',
        enrolledAt: DateTime.utc(2026),
        trusted: true,
      );
      final requestedAt = DateTime.now().toUtc();
      final challenge = DashboardLoginChallenge(
        version: 3,
        serverId: system.systemId,
        serverName: system.displayName,
        organization: system.organization,
        challengeId: 'login-1',
        nonce: 'nonce-1',
        requestedAt: requestedAt,
        expiresAt: requestedAt.add(const Duration(minutes: 5)),
        browserName: 'Microsoft Edge',
        operatingSystem: 'Windows',
        networkAddress: '198.51.100.18',
        verificationCode: '123456',
        trustedSystem: system,
      );

      await tester.pumpWidget(
        MaterialApp(home: LoginApprovalScreen(challenge: challenge)),
      );
      await tester.pump();

      expect(find.text('123 456'), findsOneWidget);
      expect(find.text('Microsoft Edge on Windows'), findsOneWidget);
      expect(find.text('198.51.100.18'), findsOneWidget);
      expect(
        find.textContaining('Approve only if you started'),
        findsOneWidget,
      );
    },
  );
}

class _FakeEnrollmentService implements EnrollmentService {
  final StreamController<EnrollmentSnapshot> _changes =
      StreamController<EnrollmentSnapshot>.broadcast();

  EnrollmentSnapshot _snapshot = const EnrollmentSnapshot(
    status: EnrollmentStatus.notEnrolled,
    trustedSystems: <TrustedSystem>[],
  );

  void emit(EnrollmentSnapshot value) {
    _snapshot = value;
    _changes.add(value);
  }

  @override
  EnrollmentSnapshot get snapshot => _snapshot;

  @override
  Stream<EnrollmentSnapshot> get changes => _changes.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<EnrollmentInvitation> parseInvitation(String payload) async =>
      throw UnimplementedError();

  @override
  Future<DeviceEnrollmentRequest> prepareEnrollment({
    required EnrollmentInvitation invitation,
    required String deviceName,
    required String platform,
  }) => throw UnimplementedError();

  @override
  Future<void> submitEnrollment({
    required EnrollmentInvitation invitation,
    required DeviceEnrollmentRequest request,
    String? activationPin,
  }) => throw UnimplementedError();

  @override
  Future<void> completeEnrollment({
    required EnrollmentInvitation invitation,
    required EnrollmentConfirmation confirmation,
  }) => throw UnimplementedError();

  @override
  Future<void> cancelPendingEnrollment() => throw UnimplementedError();

  @override
  Future<void> removeTrustedSystem(String trustedSystemId) =>
      throw UnimplementedError();

  @override
  Future<void> dispose() => _changes.close();
}
