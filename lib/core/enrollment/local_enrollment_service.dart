import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../crypto/crypto_service.dart';
import '../models/trusted_system.dart';
import '../network/auth_api_client.dart';
import 'enrollment_models.dart';
import 'enrollment_payload_parser.dart';
import 'enrollment_service.dart';
import 'trusted_system_store.dart';

class LocalEnrollmentService implements EnrollmentService {
  LocalEnrollmentService({
    required CryptoService crypto,
    required TrustedSystemStore trustedSystems,
    required AuthApiClient api,
    EnrollmentPayloadParser parser = const EnrollmentPayloadParser(),
  }) : _crypto = crypto,
       _trustedSystems = trustedSystems,
       _api = api,
       _parser = parser;

  final CryptoService _crypto;
  final TrustedSystemStore _trustedSystems;
  final AuthApiClient _api;
  final EnrollmentPayloadParser _parser;
  final StreamController<EnrollmentSnapshot> _changes =
      StreamController<EnrollmentSnapshot>.broadcast();

  EnrollmentSnapshot _snapshot = const EnrollmentSnapshot(
    status: EnrollmentStatus.notEnrolled,
    trustedSystems: <TrustedSystem>[],
  );
  bool _initialized = false;
  bool _disposed = false;

  @override
  EnrollmentSnapshot get snapshot => _snapshot;

  @override
  Stream<EnrollmentSnapshot> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    _ensureActive();
    if (_initialized) return;
    final systems = await _trustedSystems.readAll();
    _initialized = true;
    _emit(
      EnrollmentSnapshot(
        status: systems.isEmpty
            ? EnrollmentStatus.notEnrolled
            : EnrollmentStatus.enrolled,
        trustedSystems: systems,
      ),
    );
  }

  @override
  Future<void> submitEnrollment({
    required EnrollmentInvitation invitation,
    required DeviceEnrollmentRequest request,
    String? activationPin,
  }) async {
    _ensureReady();
    if (invitation.isExpired) {
      throw const EnrollmentException('Enrollment invitation has expired.');
    }
    try {
      final device = await _api.completeEnrollment(
        serverBaseUrl: invitation.serverBaseUrl,
        trustedCaCertificate: invitation.tlsCaCertificate,
        payload: request.toApiJson(invitation, activationPin: activationPin),
      );
      await completeEnrollment(
        invitation: invitation,
        confirmation: EnrollmentConfirmation(
          enrollmentId: invitation.enrollmentId,
          systemId: invitation.systemId,
          trustedSystemId: device.id,
          confirmedAt: device.enrolledAt,
          serverPublicKey: invitation.serverPublicKey ?? '',
        ),
      );
    } on Object catch (error) {
      _emit(
        EnrollmentSnapshot(
          status: EnrollmentStatus.failed,
          trustedSystems: _snapshot.trustedSystems,
          pendingInvitation: invitation,
          lastError: error.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<EnrollmentInvitation> parseInvitation(String payload) {
    _ensureReady();
    return _parser.parse(payload);
  }

  @override
  Future<DeviceEnrollmentRequest> prepareEnrollment({
    required EnrollmentInvitation invitation,
    required String deviceName,
    required String platform,
  }) async {
    _ensureReady();
    if (deviceName.trim().isEmpty || platform.trim().isEmpty) {
      throw const EnrollmentException('Device name and platform are required.');
    }
    if (invitation.isExpired) {
      throw const EnrollmentException('Enrollment invitation has expired.');
    }
    if (_snapshot.trustedSystems.any(
      (system) => system.systemId == invitation.systemId,
    )) {
      throw const EnrollmentException('This system is already enrolled.');
    }

    _emit(
      EnrollmentSnapshot(
        status: EnrollmentStatus.preparing,
        trustedSystems: _snapshot.trustedSystems,
        pendingInvitation: invitation,
      ),
    );

    try {
      final publicKey = await _crypto.ensureDeviceIdentity();
      final createdAt = DateTime.now().toUtc();
      final deviceId = await _deviceId(publicKey.publicKeyBase64Url);
      final unsigned = <String, Object>{
        'version': 1,
        'enrollmentId': invitation.enrollmentId,
        'systemId': invitation.systemId,
        'deviceId': deviceId,
        'deviceName': deviceName.trim(),
        'platform': platform.trim(),
        'publicKey': publicKey.toJson(),
        'nonce': invitation.nonce,
        'createdAt': createdAt.toIso8601String(),
      };
      final signature = await _crypto.sign(utf8.encode(jsonEncode(unsigned)));
      final request = DeviceEnrollmentRequest(
        version: 1,
        enrollmentId: invitation.enrollmentId,
        systemId: invitation.systemId,
        deviceId: deviceId,
        deviceName: deviceName.trim(),
        platform: platform.trim(),
        publicKey: publicKey,
        nonce: invitation.nonce,
        createdAt: createdAt,
        signature: signature,
      );

      _emit(
        EnrollmentSnapshot(
          status: EnrollmentStatus.awaitingConfirmation,
          trustedSystems: _snapshot.trustedSystems,
          pendingInvitation: invitation,
        ),
      );
      return request;
    } on Object catch (error) {
      _emit(
        EnrollmentSnapshot(
          status: EnrollmentStatus.failed,
          trustedSystems: _snapshot.trustedSystems,
          pendingInvitation: invitation,
          lastError: error.toString(),
        ),
      );
      rethrow;
    }
  }

  @override
  Future<void> completeEnrollment({
    required EnrollmentInvitation invitation,
    required EnrollmentConfirmation confirmation,
  }) async {
    _ensureReady();
    if (confirmation.enrollmentId != invitation.enrollmentId ||
        confirmation.systemId != invitation.systemId) {
      throw const EnrollmentException(
        'Enrollment confirmation does not match the invitation.',
      );
    }

    final trustedSystem = TrustedSystem(
      id: confirmation.trustedSystemId,
      systemId: invitation.systemId,
      displayName: invitation.displayName,
      organization: invitation.organization,
      productType: invitation.productType,
      serverBaseUrl: invitation.serverBaseUrl.toString(),
      publicKey: confirmation.serverPublicKey,
      fingerprint: invitation.serverFingerprint ?? '',
      administratorId: invitation.administratorId ?? '',
      tlsCaCertificate: invitation.tlsCaCertificate ?? '',
      tlsCaFingerprint: invitation.tlsCaFingerprint ?? '',
      enrolledAt: confirmation.confirmedAt,
      trusted: true,
    );
    final systems = <TrustedSystem>[
      ..._snapshot.trustedSystems.where(
        (system) => system.id != trustedSystem.id,
      ),
      trustedSystem,
    ];
    await _trustedSystems.writeAll(systems);
    _emit(
      EnrollmentSnapshot(
        status: EnrollmentStatus.enrolled,
        trustedSystems: systems,
      ),
    );
  }

  @override
  Future<void> cancelPendingEnrollment() async {
    _ensureReady();
    _emit(
      EnrollmentSnapshot(
        status: _snapshot.trustedSystems.isEmpty
            ? EnrollmentStatus.notEnrolled
            : EnrollmentStatus.enrolled,
        trustedSystems: _snapshot.trustedSystems,
      ),
    );
  }

  @override
  Future<void> removeTrustedSystem(String trustedSystemId) async {
    _ensureReady();
    final systems = _snapshot.trustedSystems
        .where((system) => system.id != trustedSystemId)
        .toList(growable: false);
    await _trustedSystems.writeAll(systems);
    _emit(
      EnrollmentSnapshot(
        status: systems.isEmpty
            ? EnrollmentStatus.notEnrolled
            : EnrollmentStatus.enrolled,
        trustedSystems: systems,
      ),
    );
  }

  Future<String> _deviceId(String publicKey) async {
    final digest = await Sha256().hash(utf8.encode(publicKey));
    final value = digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return 'device-${value.substring(0, 32)}';
  }

  void _emit(EnrollmentSnapshot snapshot) {
    _snapshot = snapshot;
    if (!_changes.isClosed) _changes.add(snapshot);
  }

  void _ensureReady() {
    _ensureActive();
    if (!_initialized) {
      throw StateError('EnrollmentService has not been initialized.');
    }
  }

  void _ensureActive() {
    if (_disposed) throw StateError('EnrollmentService has been disposed.');
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _changes.close();
  }
}
