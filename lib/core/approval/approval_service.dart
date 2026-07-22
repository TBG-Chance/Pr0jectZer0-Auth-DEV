import 'approval_models.dart';

abstract interface class ApprovalService {
  ApprovalSnapshot get snapshot;

  Stream<ApprovalSnapshot> get changes;

  Future<void> initialize();

  Future<void> receiveRequest(ApprovalRequest request);

  Future<ApprovalResponse> decide({
    required String requestId,
    required ApprovalDecision decision,
    required String authenticationMethod,
  });

  Future<void> markResponseSynced(String requestId);

  Future<void> markResponseFailed(String requestId);

  Future<void> removeExpiredRequests();

  Future<void> dispose();
}
