import 'dart:convert';

import '../crypto/crypto_service.dart';
import '../enrollment/trusted_system_store.dart';
import '../network/auth_api_client.dart';
import 'login_models.dart';
import 'login_service.dart';

class RegisteredDeviceLoginService implements LoginService {
  const RegisteredDeviceLoginService({
    required CryptoService crypto,
    required TrustedSystemStore trustedSystems,
    required AuthApiClient api,
  }) : _crypto = crypto,
       _trustedSystems = trustedSystems,
       _api = api;

  static const _signatureDomain = 'pr0jectzer0-login-v1';

  final CryptoService _crypto;
  final TrustedSystemStore _trustedSystems;
  final AuthApiClient _api;

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
    if (version != 1) {
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
    return DashboardLoginChallenge(
      version: version!,
      serverId: serverId,
      challengeId: requiredValue('challenge_id'),
      nonce: requiredValue('nonce'),
      expiresAt: expiresAt,
      trustedSystem: matches.first,
    );
  }

  @override
  Future<void> approve(DashboardLoginChallenge challenge) async {
    if (challenge.isExpired) {
      throw const LoginApprovalException('This login code has expired.');
    }
    final expiresAtSeconds = challenge.expiresAt.millisecondsSinceEpoch ~/ 1000;
    final payload = utf8.encode(
      '$_signatureDomain\n${challenge.challengeId}\n${challenge.nonce}\n$expiresAtSeconds',
    );
    final signature = await _crypto.sign(payload);
    await _api.approveLogin(
      serverBaseUrl: Uri.parse(challenge.trustedSystem.serverBaseUrl),
      challengeId: challenge.challengeId,
      nonce: challenge.nonce,
      deviceId: challenge.trustedSystem.id,
      signature: signature.signatureBase64Url,
    );
  }
}
