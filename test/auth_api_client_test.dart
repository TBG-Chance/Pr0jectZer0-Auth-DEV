import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pr0jectzer0_auth/core/network/auth_api_client.dart';

void main() {
  test('surfaces the platform top-level API error message', () async {
    final client = HttpAuthApiClient(
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(<String, Object>{
            'error': 'invalid_login_challenge',
            'message': 'login challenge is invalid, expired, or already used',
          }),
          401,
          headers: const <String, String>{'content-type': 'application/json'},
        ),
      ),
    );

    await expectLater(
      client.approveLogin(
        serverBaseUrl: Uri.parse('http://192.168.1.20:8080'),
        challengeId: 'login-1',
        nonce: 'nonce-1',
        deviceId: 'device-1',
        signature: 'signature-1',
      ),
      throwsA(
        isA<AuthApiException>()
            .having((error) => error.statusCode, 'statusCode', 401)
            .having(
              (error) => error.message,
              'message',
              'login challenge is invalid, expired, or already used',
            ),
      ),
    );
  });

  for (final scenario in <(String, String)>[
    (
      'administrator_invitation',
      '/api/v1/auth/administrator-invitations/activate',
    ),
    ('lost_device_recovery', '/api/v1/auth/recovery/activate'),
  ]) {
    test('routes ${scenario.$1} activation without client metadata', () async {
      late http.Request captured;
      final client = HttpAuthApiClient(
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode(<String, Object>{
              'device': <String, Object>{
                'id': 'device-2',
                'administrator_id': 'admin-2',
                'name': 'Test Phone',
                'enrolled_at': DateTime.utc(2026).toIso8601String(),
              },
            }),
            200,
            headers: const <String, String>{'content-type': 'application/json'},
          );
        }),
      );

      final device = await client.completeEnrollment(
        serverBaseUrl: Uri.parse('https://security.example.com'),
        payload: <String, Object>{
          '_activation_kind': scenario.$1,
          'challenge_id': 'challenge-1',
          'activation_secret': 'secret-1',
          'pin': '728194',
          'device_name': 'Test Phone',
          'key_algorithm': 'ed25519',
          'public_key': 'public-key',
        },
      );

      expect(captured.url.path, scenario.$2);
      expect(jsonDecode(captured.body), isNot(contains('_activation_kind')));
      expect(device.administratorId, 'admin-2');
    });
  }

  test('uses the enrolled installation CA only for that request', () async {
    const trustedCA = 'base64url-installation-ca';
    String? selectedCA;
    late http.Request captured;
    final client = HttpAuthApiClient(
      client: MockClient(
        (_) async => throw StateError('the system trust client was used'),
      ),
      scopedClientFactory: (certificate) {
        selectedCA = certificate;
        return MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        });
      },
    );

    await client.approveLogin(
      serverBaseUrl: Uri.parse('https://192.168.1.20:8443'),
      challengeId: 'login-1',
      nonce: 'nonce-1',
      deviceId: 'device-1',
      signature: 'signature-1',
      trustedCaCertificate: trustedCA,
    );

    expect(selectedCA, trustedCA);
    expect(captured.url.host, '192.168.1.20');
    expect(captured.url.port, 8443);
  });
}
