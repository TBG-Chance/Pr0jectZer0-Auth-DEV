import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../crypto/crypto_service.dart';
import '../enrollment/trusted_system_store.dart';
import '../models/trusted_system.dart';
import '../network/auth_api_client.dart';
import 'login_models.dart';
import 'login_service.dart';

class RegisteredDeviceLoginService implements LoginService {
  const RegisteredDeviceLoginService({
    required CryptoService crypto,
    required TrustedSystemStore trustedSystems,
    required AuthApiClient api,
    this.allowLegacyInsecure = false,
  }) : _crypto = crypto,
       _trustedSystems = trustedSystems,
       _api = api;

  static const _signatureDomainV1 = 'pr0jectzer0-login-v1';
  static const _signatureDomainV2 = 'pr0jectzer0-login-v2';
  static const _signatureDomainV3 = 'pr0jectzer0-login-v3';
  static const _challengeDomainV2 = 'pr0jectzer0-login-challenge-v2';
  static const _challengeDomainV3 = 'pr0jectzer0-login-challenge-v3';

  final CryptoService _crypto;
  final TrustedSystemStore _trustedSystems;
  final AuthApiClient _api;
  final bool allowLegacyInsecure;

  @override
  Future<DashboardLoginChallenge> parseChallenge(String payload) async {
    final uri = Uri.tryParse(payload.trim());
    if (uri == null || uri.scheme != 'pr0jectzer0' || uri.host != 'login') {
      throw const LoginApprovalException(
        'This is not a Pr0jectZer0 login code.',
      );
    }
    final values = uri.queryParameters;
    String requiredValue(String name) {
      final value = values[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw LoginApprovalException('The login code is missing $name.');
      }
      return value;
    }

    final version = int.tryParse(requiredValue('v'));
    if (version != 3 &&
        version != 2 &&
        !(allowLegacyInsecure && version == 1)) {
      throw LoginApprovalException(
        'Unsupported login code version ${version ?? 'unknown'}.',
      );
    }
    final serverId = requiredValue('server_id');
    final expiresAt = DateTime.parse(requiredValue('expires_at')).toUtc();
    final now = DateTime.now().toUtc();
    if (!now.isBefore(expiresAt)) {
      throw const LoginApprovalException('This login code has expired.');
    }
    if (expiresAt.difference(now) > const Duration(minutes: 10)) {
      throw const LoginApprovalException(
        'The login code validity is unexpectedly long.',
      );
    }
    final systems = await _trustedSystems.readAll();
    final matches = systems.where(
      (system) => system.systemId == serverId && system.trusted,
    );
    if (matches.isEmpty) {
      throw const LoginApprovalException(
        'This server is not enrolled on this authentication device.',
      );
    }
    final trustedSystem = matches.first;
    var requestedAt = expiresAt;
    var serverName = trustedSystem.displayName;
    var organization = trustedSystem.organization;
    var browserName = '';
    var operatingSystem = '';
    var networkAddress = '';
    var verificationCode = '';
    if (version == 3) {
      serverName = requiredValue('server_name');
      organization = requiredValue('organization');
      if (serverName != trustedSystem.displayName ||
          organization != trustedSystem.organization) {
        throw const LoginApprovalException(
          'The login code server identity does not match the enrolled server.',
        );
      }
      requestedAt = DateTime.parse(requiredValue('requested_at')).toUtc();
      if (requestedAt.isAfter(now.add(const Duration(minutes: 1))) ||
          !requestedAt.isBefore(expiresAt) ||
          expiresAt.difference(requestedAt) > const Duration(minutes: 10)) {
        throw const LoginApprovalException(
          'The login request time is invalid.',
        );
      }
      browserName = _limitedContext(requiredValue('browser_name'), 80);
      operatingSystem = _limitedContext(requiredValue('operating_system'), 80);
      networkAddress = _limitedContext(requiredValue('network_address'), 64);
      verificationCode = requiredValue('verification_code');
      if (!RegExp(r'^\d{6}$').hasMatch(verificationCode)) {
        throw const LoginApprovalException(
          'The login comparison code is invalid.',
        );
      }
    }
    if (version == 2 || version == 3) {
      await _verifyChallenge(
        values,
        version!,
        requestedAt,
        expiresAt,
        trustedSystem,
      );
    }
    return DashboardLoginChallenge(
      version: version!,
      serverId: serverId,
      serverName: serverName,
      organization: organization,
      challengeId: requiredValue('challenge_id'),
      nonce: requiredValue('nonce'),
      requestedAt: requestedAt,
      expiresAt: expiresAt,
      browserName: browserName,
      operatingSystem: operatingSystem,
      networkAddress: networkAddress,
      verificationCode: verificationCode,
      trustedSystem: trustedSystem,
    );
  }

  String _limitedContext(String value, int maximum) {
    if (value.length > maximum) {
      throw const LoginApprovalException(
        'The login request context is unexpectedly long.',
      );
    }
    return value;
  }

  Future<void> _verifyChallenge(
    Map<String, String> values,
    int version,
    DateTime requestedAt,
    DateTime expiresAt,
    TrustedSystem trustedSystem,
  ) async {
    String requiredValue(String name) {
      final value = values[name]?.trim() ?? '';
      if (value.isEmpty) {
        throw LoginApprovalException('The login code is missing $name.');
      }
      return value;
    }

    final origin = requiredValue('server_url').replaceFirst(RegExp(r'/$'), '');
    final trustedOrigin = trustedSystem.serverBaseUrl.replaceFirst(
      RegExp(r'/$'),
      '',
    );
    if (origin != trustedOrigin || Uri.tryParse(origin)?.scheme != 'https') {
      throw const LoginApprovalException(
        'The login code server origin does not match the enrolled server.',
      );
    }
    if (trustedSystem.publicKey.isEmpty) {
      throw const LoginApprovalException(
        'The enrolled server does not have a trusted signing key.',
      );
    }
    late List<int> publicKey;
    late List<int> signatureBytes;
    try {
      publicKey = base64Url.decode(
        base64Url.normalize(trustedSystem.publicKey),
      );
      signatureBytes = base64Url.decode(
        base64Url.normalize(requiredValue('signature')),
      );
    } on FormatException {
      throw const LoginApprovalException(
        'The login code server signature is malformed.',
      );
    }
    final payloadFields = version == 3
        ? <String>[
            _challengeDomainV3,
            '3',
            requiredValue('server_id'),
            requiredValue('server_name'),
            requiredValue('organization'),
            origin,
            requiredValue('challenge_id'),
            requiredValue('nonce'),
            (requestedAt.millisecondsSinceEpoch ~/ 1000).toString(),
            (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
            requiredValue('browser_name'),
            requiredValue('operating_system'),
            requiredValue('network_address'),
            requiredValue('verification_code'),
          ]
        : <String>[
            _challengeDomainV2,
            '2',
            requiredValue('server_id'),
            origin,
            requiredValue('challenge_id'),
            requiredValue('nonce'),
            (expiresAt.millisecondsSinceEpoch ~/ 1000).toString(),
          ];
    final payload = utf8.encode(payloadFields.join('\n'));
    final valid =
        publicKey.length == 32 &&
        signatureBytes.length == 64 &&
        await Ed25519().verify(
          payload,
          signature: Signature(
            signatureBytes,
            publicKey: SimplePublicKey(publicKey, type: KeyPairType.ed25519),
          ),
        );
    if (!valid) {
      throw const LoginApprovalException(
        'The login code server signature is invalid.',
      );
    }
  }

  @override
  Future<void> approve(DashboardLoginChallenge challenge) async {
    if (challenge.isExpired) {
      throw const LoginApprovalException('This login code has expired.');
    }
    final expiresAtSeconds = challenge.expiresAt.millisecondsSinceEpoch ~/ 1000;
    final payload = challenge.version == 3
        ? utf8.encode(
            '$_signatureDomainV3\n${challenge.serverId}\n'
            '${challenge.serverName}\n${challenge.organization}\n'
            '${challenge.trustedSystem.serverBaseUrl.replaceFirst(RegExp(r'/$'), '')}\n'
            '${challenge.challengeId}\n${challenge.nonce}\n'
            '${challenge.requestedAt.millisecondsSinceEpoch ~/ 1000}\n'
            '$expiresAtSeconds\n${challenge.browserName}\n'
            '${challenge.operatingSystem}\n${challenge.networkAddress}\n'
            '${challenge.verificationCode}',
          )
        : challenge.version == 2
        ? utf8.encode(
            '$_signatureDomainV2\n${challenge.serverId}\n'
            '${challenge.trustedSystem.serverBaseUrl.replaceFirst(RegExp(r'/$'), '')}\n'
            '${challenge.challengeId}\n${challenge.nonce}\n$expiresAtSeconds',
          )
        : utf8.encode(
            '$_signatureDomainV1\n${challenge.challengeId}\n${challenge.nonce}\n$expiresAtSeconds',
          );
    final signature = await _crypto.sign(payload);
    await _api.approveLogin(
      serverBaseUrl: Uri.parse(challenge.trustedSystem.serverBaseUrl),
      challengeId: challenge.challengeId,
      nonce: challenge.nonce,
      deviceId: challenge.trustedSystem.id,
      signature: signature.signatureBase64Url,
      trustedCaCertificate: challenge.trustedSystem.tlsCaCertificate,
    );
  }
}
