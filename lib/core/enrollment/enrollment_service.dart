import 'enrollment_models.dart';

abstract interface class EnrollmentService {
  EnrollmentSnapshot get snapshot;

  Stream<EnrollmentSnapshot> get changes;

  Future<void> initialize();

  Future<EnrollmentInvitation> parseInvitation(String payload);

  Future<DeviceEnrollmentRequest> prepareEnrollment({
    required EnrollmentInvitation invitation,
    required String deviceName,
    required String platform,
  });

  Future<void> submitEnrollment({
    required EnrollmentInvitation invitation,
    required DeviceEnrollmentRequest request,
    String? activationPin,
  });

  Future<void> completeEnrollment({
    required EnrollmentInvitation invitation,
    required EnrollmentConfirmation confirmation,
  });

  Future<void> cancelPendingEnrollment();

  Future<void> removeTrustedSystem(String trustedSystemId);

  Future<void> dispose();
}
