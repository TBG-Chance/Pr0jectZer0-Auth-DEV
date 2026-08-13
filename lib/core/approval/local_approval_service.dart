// ignore_for_file: prefer_initializing_formals

import 'dart:async';
import 'dart:convert';

import '../crypto/crypto_service.dart';
import '../storage/secure_storage_service.dart';
import 'approval_models.dart';
import 'approval_service.dart';

class LocalApprovalService implements ApprovalService {
  LocalApprovalService({
    required CryptoService crypto,
    required SecureStorageService secureStorage,
  }) : _crypto = crypto,
       _secureStorage = secureStorage;

  static const _requestsKey = 'pz.auth.approvals.requests.v1';
  static const _responsesKey = 'pz.auth.approvals.responses.v1';
  static const _auditKey = 'pz.auth.approvals.audit.v1';
  static const _maximumAuditEntries = 100;

  final CryptoService _crypto;
  final SecureStorageService _secureStorage;
  final StreamController<ApprovalSnapshot> _changes =
      StreamController<ApprovalSnapshot>.broadcast();

  final List<ApprovalRequest> _requests = <ApprovalRequest>[];
  final List<ApprovalResponse> _responses = <ApprovalResponse>[];
  final List<ApprovalAuditEntry> _audit = <ApprovalAuditEntry>[];

  @override
  ApprovalSnapshot get snapshot => ApprovalSnapshot(
    pendingRequests: List<ApprovalRequest>.unmodifiable(_requests),
    queuedResponses: List<ApprovalResponse>.unmodifiable(_responses),
    auditTrail: List<ApprovalAuditEntry>.unmodifiable(_audit),
  );

  @override
  Stream<ApprovalSnapshot> get changes => _changes.stream;

  @override
  Future<void> initialize() async {
    _requests
      ..clear()
      ..addAll(await _readList(_requestsKey, ApprovalRequest.fromJson));
    _responses
      ..clear()
      ..addAll(await _readList(_responsesKey, ApprovalResponse.fromJson));
    _audit
      ..clear()
      ..addAll(await _readList(_auditKey, ApprovalAuditEntry.fromJson));
    await removeExpiredRequests();
    _emit();
  }

  @override
  Future<void> receiveRequest(ApprovalRequest request) async {
    if (request.isExpired) {
      throw StateError('The approval request has expired.');
    }
    if (_requests.any((item) => item.id == request.id) ||
        _responses.any((item) => item.requestId == request.id)) {
      return;
    }
    _requests.add(request);
    _requests.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    await _writeRequests();
    _emit();
  }

  @override
  Future<ApprovalResponse> decide({
    required String requestId,
    required ApprovalDecision decision,
    required String authenticationMethod,
  }) async {
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index < 0) {
      throw StateError('Approval request not found.');
    }
    final request = _requests[index];
    if (request.isExpired) {
      _requests.removeAt(index);
      await _writeRequests();
      _emit();
      throw StateError('The approval request has expired.');
    }

    final publicKey = await _crypto.ensureDeviceIdentity();
    final decidedAt = DateTime.now().toUtc();
    final deviceId =
        'device-${publicKey.fingerprint.replaceAll(':', '').substring(0, 24)}';
    final unsigned = ApprovalResponse(
      requestId: request.id,
      systemId: request.systemId,
      deviceId: deviceId,
      keyId: publicKey.keyId,
      decision: decision,
      decidedAt: decidedAt,
      requestNonce: request.nonce,
      signature: '',
      syncStatus: ApprovalSyncStatus.pending,
      authenticationMethod: authenticationMethod,
    );
    final signature = await _crypto.sign(unsigned.canonicalPayloadBytes());
    final response = ApprovalResponse(
      requestId: unsigned.requestId,
      systemId: unsigned.systemId,
      deviceId: unsigned.deviceId,
      keyId: unsigned.keyId,
      decision: unsigned.decision,
      decidedAt: unsigned.decidedAt,
      requestNonce: unsigned.requestNonce,
      signature: signature.signatureBase64Url,
      syncStatus: ApprovalSyncStatus.pending,
      authenticationMethod: authenticationMethod,
    );

    _requests.removeAt(index);
    _responses.removeWhere((item) => item.requestId == request.id);
    _responses.add(response);
    _audit.insert(
      0,
      ApprovalAuditEntry(
        requestId: request.id,
        systemId: request.systemId,
        title: request.title,
        decision: decision,
        decidedAt: decidedAt,
        authenticationMethod: authenticationMethod,
        syncStatus: ApprovalSyncStatus.pending,
      ),
    );
    if (_audit.length > _maximumAuditEntries) {
      _audit.removeRange(_maximumAuditEntries, _audit.length);
    }
    await Future.wait(<Future<void>>[
      _writeRequests(),
      _writeResponses(),
      _writeAudit(),
    ]);
    _emit();
    return response;
  }

  @override
  Future<void> markResponseSynced(String requestId) =>
      _updateResponseStatus(requestId, ApprovalSyncStatus.synced);

  @override
  Future<void> markResponseFailed(String requestId) =>
      _updateResponseStatus(requestId, ApprovalSyncStatus.failed);

  Future<void> _updateResponseStatus(
    String requestId,
    ApprovalSyncStatus status,
  ) async {
    final responseIndex = _responses.indexWhere(
      (response) => response.requestId == requestId,
    );
    if (responseIndex < 0) return;
    _responses[responseIndex] = _responses[responseIndex].copyWith(
      syncStatus: status,
    );
    final auditIndex = _audit.indexWhere(
      (entry) => entry.requestId == requestId,
    );
    if (auditIndex >= 0) {
      final entry = _audit[auditIndex];
      _audit[auditIndex] = ApprovalAuditEntry(
        requestId: entry.requestId,
        systemId: entry.systemId,
        title: entry.title,
        decision: entry.decision,
        decidedAt: entry.decidedAt,
        authenticationMethod: entry.authenticationMethod,
        syncStatus: status,
      );
    }
    await Future.wait(<Future<void>>[_writeResponses(), _writeAudit()]);
    _emit();
  }

  @override
  Future<void> removeExpiredRequests() async {
    final before = _requests.length;
    _requests.removeWhere((request) => request.isExpired);
    if (_requests.length != before) {
      await _writeRequests();
      _emit();
    }
  }

  Future<List<T>> _readList<T>(
    String key,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final raw = await _secureStorage.read(key);
    if (raw == null || raw.isEmpty) return <T>[];
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <T>[];
    return decoded
        .whereType<Map>()
        .map((item) => fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<void> _writeRequests() => _writeList(
    _requestsKey,
    _requests.map((request) => request.toJson()).toList(),
  );

  Future<void> _writeResponses() => _writeList(
    _responsesKey,
    _responses.map((response) => response.toJson()).toList(),
  );

  Future<void> _writeAudit() =>
      _writeList(_auditKey, _audit.map((entry) => entry.toJson()).toList());

  Future<void> _writeList(String key, Object values) {
    return _secureStorage.write(key: key, value: jsonEncode(values));
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(snapshot);
  }

  @override
  Future<void> dispose() => _changes.close();
}
