import 'package:flutter_test/flutter_test.dart';
import 'package:pr0jectzer0_auth/core/approval/approval_models.dart';
import 'package:pr0jectzer0_auth/core/approval/local_approval_service.dart';
import 'package:pr0jectzer0_auth/core/crypto/secure_ed25519_crypto_service.dart';
import 'package:pr0jectzer0_auth/core/storage/in_memory_secure_storage_service.dart';

void main() {
  late InMemorySecureStorageService storage;
  late SecureEd25519CryptoService crypto;
  late LocalApprovalService approvals;

  setUp(() async {
    storage = InMemorySecureStorageService();
    await storage.initialize();
    crypto = SecureEd25519CryptoService(storage);
    await crypto.initialize();
    approvals = LocalApprovalService(crypto: crypto, secureStorage: storage);
    await approvals.initialize();
  });

  tearDown(() async {
    await approvals.dispose();
    await crypto.dispose();
    await storage.dispose();
  });

  test('receives and persists a pending approval request', () async {
    final request = _request('request-1');
    await approvals.receiveRequest(request);

    expect(approvals.snapshot.pendingRequests, hasLength(1));

    final reloaded = LocalApprovalService(crypto: crypto, secureStorage: storage);
    await reloaded.initialize();
    expect(reloaded.snapshot.pendingRequests.single.id, request.id);
    await reloaded.dispose();
  });

  test('creates a signed queued response and audit entry', () async {
    await approvals.receiveRequest(_request('request-2'));

    final response = await approvals.decide(
      requestId: 'request-2',
      decision: ApprovalDecision.approve,
      authenticationMethod: 'pin',
    );

    expect(response.signature, isNotEmpty);
    expect(response.syncStatus, ApprovalSyncStatus.pending);
    expect(approvals.snapshot.pendingRequests, isEmpty);
    expect(approvals.snapshot.queuedResponses, hasLength(1));
    expect(approvals.snapshot.auditTrail.single.decision, ApprovalDecision.approve);
  });

  test('updates response synchronization status', () async {
    await approvals.receiveRequest(_request('request-3'));
    await approvals.decide(
      requestId: 'request-3',
      decision: ApprovalDecision.deny,
      authenticationMethod: 'pin',
    );

    await approvals.markResponseSynced('request-3');

    expect(
      approvals.snapshot.queuedResponses.single.syncStatus,
      ApprovalSyncStatus.synced,
    );
    expect(
      approvals.snapshot.auditTrail.single.syncStatus,
      ApprovalSyncStatus.synced,
    );
  });
}

ApprovalRequest _request(String id) {
  final now = DateTime.now().toUtc();
  return ApprovalRequest(
    id: id,
    systemId: 'system-1',
    systemName: 'Pr0jectZer0',
    organization: 'The Bostrom Group',
    title: 'Administrative sign-in',
    description: 'Approve an administrative console sign-in.',
    requestedBy: 'admin',
    requestingDevice: 'Console',
    sourceIp: '192.168.1.10',
    createdAt: now,
    expiresAt: now.add(const Duration(minutes: 5)),
    nonce: 'nonce-$id',
    risk: ApprovalRisk.high,
  );
}
