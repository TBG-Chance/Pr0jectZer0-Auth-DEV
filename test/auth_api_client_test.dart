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
}
