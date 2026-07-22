import 'dart:convert';

class DevicePublicKey {
  const DevicePublicKey({
    required this.algorithm,
    required this.keyId,
    required this.publicKeyBase64Url,
    required this.fingerprint,
    required this.createdAt,
  });

  final String algorithm;
  final String keyId;
  final String publicKeyBase64Url;
  final String fingerprint;
  final DateTime createdAt;

  Map<String, Object> toJson() => <String, Object>{
        'algorithm': algorithm,
        'keyId': keyId,
        'publicKey': publicKeyBase64Url,
        'fingerprint': fingerprint,
        'createdAt': createdAt.toUtc().toIso8601String(),
      };

  String toJsonString() => jsonEncode(toJson());
}

class SignatureEnvelope {
  const SignatureEnvelope({
    required this.algorithm,
    required this.keyId,
    required this.signatureBase64Url,
    required this.signedAt,
  });

  final String algorithm;
  final String keyId;
  final String signatureBase64Url;
  final DateTime signedAt;

  Map<String, Object> toJson() => <String, Object>{
        'algorithm': algorithm,
        'keyId': keyId,
        'signature': signatureBase64Url,
        'signedAt': signedAt.toUtc().toIso8601String(),
      };
}
