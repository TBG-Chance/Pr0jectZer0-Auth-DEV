import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_models.dart';
import 'package:pr0jectzer0_auth/core/enrollment/enrollment_service.dart';
import 'package:pr0jectzer0_auth/core/models/trusted_system.dart';
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
  EnrollmentInvitation parseInvitation(String payload) =>
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
