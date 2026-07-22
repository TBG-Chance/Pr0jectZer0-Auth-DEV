class TrustedSystem {
  const TrustedSystem({
    required this.id,
    required this.systemId,
    required this.displayName,
    required this.organization,
    required this.productType,
    required this.serverBaseUrl,
    required this.publicKey,
    required this.enrolledAt,
    required this.trusted,
  });

  final String id;
  final String systemId;
  final String displayName;
  final String organization;
  final String productType;
  final String serverBaseUrl;
  final String publicKey;
  final DateTime enrolledAt;
  final bool trusted;

  factory TrustedSystem.fromJson(Map<String, dynamic> json) {
    return TrustedSystem(
      id: json['id'] as String,
      systemId: json['systemId'] as String,
      displayName: json['displayName'] as String,
      organization: json['organization'] as String,
      productType: json['productType'] as String,
      serverBaseUrl: json['serverBaseUrl'] as String,
      publicKey: json['publicKey'] as String,
      enrolledAt: DateTime.parse(json['enrolledAt'] as String).toUtc(),
      trusted: json['trusted'] as bool,
    );
  }

  Map<String, Object> toJson() => <String, Object>{
        'id': id,
        'systemId': systemId,
        'displayName': displayName,
        'organization': organization,
        'productType': productType,
        'serverBaseUrl': serverBaseUrl,
        'publicKey': publicKey,
        'enrolledAt': enrolledAt.toUtc().toIso8601String(),
        'trusted': trusted,
      };
}
