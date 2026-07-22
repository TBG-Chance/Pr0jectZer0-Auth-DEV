import 'dart:convert';

enum ApprovalRisk { low, medium, high, critical }

enum ApprovalDecision { approve, deny }

enum ApprovalSyncStatus { pending, synced, failed }

class ApprovalRequest {
  const ApprovalRequest({
    required this.id,
    required this.systemId,
    required this.systemName,
    required this.organization,
    required this.title,
    required this.description,
    required this.requestedBy,
    required this.requestingDevice,
    required this.createdAt,
    required this.expiresAt,
    required this.nonce,
    required this.risk,
    this.sourceIp,
  });

  final String id;
  final String systemId;
  final String systemName;
  final String organization;
  final String title;
  final String description;
  final String requestedBy;
  final String requestingDevice;
  final String? sourceIp;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String nonce;
  final ApprovalRisk risk;

  bool get isExpired => !DateTime.now().toUtc().isBefore(expiresAt.toUtc());

  factory ApprovalRequest.fromJson(Map<String, dynamic> json) {
    return ApprovalRequest(
      id: json['id'] as String,
      systemId: json['systemId'] as String,
      systemName: json['systemName'] as String,
      organization: json['organization'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      requestedBy: json['requestedBy'] as String,
      requestingDevice: json['requestingDevice'] as String,
      sourceIp: json['sourceIp'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
      nonce: json['nonce'] as String,
      risk: ApprovalRisk.values.byName(json['risk'] as String),
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'systemId': systemId,
        'systemName': systemName,
        'organization': organization,
        'title': title,
        'description': description,
        'requestedBy': requestedBy,
        'requestingDevice': requestingDevice,
        'sourceIp': sourceIp,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'expiresAt': expiresAt.toUtc().toIso8601String(),
        'nonce': nonce,
        'risk': risk.name,
      };
}

class ApprovalResponse {
  const ApprovalResponse({
    required this.requestId,
    required this.systemId,
    required this.deviceId,
    required this.keyId,
    required this.decision,
    required this.decidedAt,
    required this.requestNonce,
    required this.signature,
    required this.syncStatus,
    required this.authenticationMethod,
  });

  final String requestId;
  final String systemId;
  final String deviceId;
  final String keyId;
  final ApprovalDecision decision;
  final DateTime decidedAt;
  final String requestNonce;
  final String signature;
  final ApprovalSyncStatus syncStatus;
  final String authenticationMethod;

  Map<String, Object> unsignedPayload() => <String, Object>{
        'requestId': requestId,
        'systemId': systemId,
        'deviceId': deviceId,
        'keyId': keyId,
        'decision': decision.name,
        'decidedAt': decidedAt.toUtc().toIso8601String(),
        'requestNonce': requestNonce,
      };

  List<int> canonicalPayloadBytes() => utf8.encode(jsonEncode(unsignedPayload()));

  ApprovalResponse copyWith({ApprovalSyncStatus? syncStatus}) {
    return ApprovalResponse(
      requestId: requestId,
      systemId: systemId,
      deviceId: deviceId,
      keyId: keyId,
      decision: decision,
      decidedAt: decidedAt,
      requestNonce: requestNonce,
      signature: signature,
      syncStatus: syncStatus ?? this.syncStatus,
      authenticationMethod: authenticationMethod,
    );
  }

  factory ApprovalResponse.fromJson(Map<String, dynamic> json) {
    return ApprovalResponse(
      requestId: json['requestId'] as String,
      systemId: json['systemId'] as String,
      deviceId: json['deviceId'] as String,
      keyId: json['keyId'] as String,
      decision: ApprovalDecision.values.byName(json['decision'] as String),
      decidedAt: DateTime.parse(json['decidedAt'] as String).toUtc(),
      requestNonce: json['requestNonce'] as String,
      signature: json['signature'] as String,
      syncStatus: ApprovalSyncStatus.values.byName(json['syncStatus'] as String),
      authenticationMethod: json['authenticationMethod'] as String,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        ...unsignedPayload(),
        'signature': signature,
        'syncStatus': syncStatus.name,
        'authenticationMethod': authenticationMethod,
      };
}

class ApprovalAuditEntry {
  const ApprovalAuditEntry({
    required this.requestId,
    required this.systemId,
    required this.title,
    required this.decision,
    required this.decidedAt,
    required this.authenticationMethod,
    required this.syncStatus,
  });

  final String requestId;
  final String systemId;
  final String title;
  final ApprovalDecision decision;
  final DateTime decidedAt;
  final String authenticationMethod;
  final ApprovalSyncStatus syncStatus;

  factory ApprovalAuditEntry.fromJson(Map<String, dynamic> json) {
    return ApprovalAuditEntry(
      requestId: json['requestId'] as String,
      systemId: json['systemId'] as String,
      title: json['title'] as String,
      decision: ApprovalDecision.values.byName(json['decision'] as String),
      decidedAt: DateTime.parse(json['decidedAt'] as String).toUtc(),
      authenticationMethod: json['authenticationMethod'] as String,
      syncStatus: ApprovalSyncStatus.values.byName(json['syncStatus'] as String),
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'requestId': requestId,
        'systemId': systemId,
        'title': title,
        'decision': decision.name,
        'decidedAt': decidedAt.toUtc().toIso8601String(),
        'authenticationMethod': authenticationMethod,
        'syncStatus': syncStatus.name,
      };
}

class ApprovalSnapshot {
  const ApprovalSnapshot({
    required this.pendingRequests,
    required this.queuedResponses,
    required this.auditTrail,
  });

  final List<ApprovalRequest> pendingRequests;
  final List<ApprovalResponse> queuedResponses;
  final List<ApprovalAuditEntry> auditTrail;
}
