import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

typedef ScopedClientFactory = http.Client Function(String certificateBase64Url);

class EnrolledDevice {
  const EnrolledDevice({
    required this.id,
    required this.administratorId,
    required this.name,
    required this.enrolledAt,
  });

  final String id;
  final String administratorId;
  final String name;
  final DateTime enrolledAt;

  factory EnrolledDevice.fromJson(Map<String, dynamic> json) {
    return EnrolledDevice(
      id: json['id'] as String,
      administratorId: json['administrator_id'] as String,
      name: json['name'] as String,
      enrolledAt: DateTime.parse(json['enrolled_at'] as String).toUtc(),
    );
  }
}

abstract interface class AuthApiClient {
  Future<EnrolledDevice> completeEnrollment({
    required Uri serverBaseUrl,
    required Map<String, Object> payload,
    String? trustedCaCertificate,
  });

  Future<void> approveLogin({
    required Uri serverBaseUrl,
    required String challengeId,
    required String nonce,
    required String deviceId,
    required String signature,
    String? trustedCaCertificate,
  });
}

class HttpAuthApiClient implements AuthApiClient {
  HttpAuthApiClient({
    http.Client? client,
    ScopedClientFactory? scopedClientFactory,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _scopedClientFactory = scopedClientFactory ?? _newScopedClient;

  final http.Client _client;
  final ScopedClientFactory _scopedClientFactory;
  final Duration timeout;

  @override
  Future<EnrolledDevice> completeEnrollment({
    required Uri serverBaseUrl,
    required Map<String, Object> payload,
    String? trustedCaCertificate,
  }) async {
    final requestPayload = Map<String, Object>.from(payload);
    final activationKind = requestPayload.remove('_activation_kind');
    final endpointPath = switch (activationKind) {
      'administrator_invitation' =>
        '/api/v1/auth/administrator-invitations/activate',
      'lost_device_recovery' => '/api/v1/auth/recovery/activate',
      _ => '/api/v1/auth/enrollment/complete',
    };
    final response = await _post(
      serverBaseUrl,
      endpointPath,
      requestPayload,
      trustedCaCertificate: trustedCaCertificate,
    );
    final device = response['device'];
    if (device is! Map) {
      throw const AuthApiException(
        'The enrollment response did not contain a device.',
      );
    }
    return EnrolledDevice.fromJson(Map<String, dynamic>.from(device));
  }

  @override
  Future<void> approveLogin({
    required Uri serverBaseUrl,
    required String challengeId,
    required String nonce,
    required String deviceId,
    required String signature,
    String? trustedCaCertificate,
  }) async {
    await _post(
      serverBaseUrl,
      '/api/v1/auth/login/approve',
      <String, Object>{
        'challenge_id': challengeId,
        'nonce': nonce,
        'device_id': deviceId,
        'signature': signature,
      },
      trustedCaCertificate: trustedCaCertificate,
    );
  }

  Future<Map<String, dynamic>> _post(
    Uri serverBaseUrl,
    String path,
    Map<String, Object> payload, {
    String? trustedCaCertificate,
  }) async {
    final endpoint = _endpoint(serverBaseUrl, path);
    late http.Response response;
    final scopedCA = trustedCaCertificate?.trim() ?? '';
    final requestClient = scopedCA.isEmpty
        ? _client
        : _scopedClientFactory(scopedCA);
    try {
      response = await requestClient
          .post(
            endpoint,
            headers: const <String, String>{
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw AuthApiException(
        'The server did not respond within ${timeout.inSeconds} seconds.',
      );
    } on Object catch (error) {
      throw AuthApiException('Unable to reach ${endpoint.host}: $error');
    } finally {
      if (!identical(requestClient, _client)) requestClient.close();
    }

    Map<String, dynamic> decoded = const <String, dynamic>{};
    if (response.body.trim().isNotEmpty) {
      try {
        final value = jsonDecode(response.body);
        if (value is Map) decoded = Map<String, dynamic>.from(value);
      } on FormatException {
        // The HTTP status still provides a useful error below.
      }
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['error'];
      final nestedMessage = error is Map ? error['message'] : null;
      final topLevelMessage = decoded['message'];
      final message = nestedMessage is String && nestedMessage.isNotEmpty
          ? nestedMessage
          : topLevelMessage;
      throw AuthApiException(
        message is String && message.isNotEmpty
            ? message
            : 'The server rejected the request (HTTP ${response.statusCode}).',
        statusCode: response.statusCode,
      );
    }
    return decoded;
  }

  Uri _endpoint(Uri base, String path) {
    final normalized = base
        .replace(path: '', query: null, fragment: null)
        .toString();
    return Uri.parse('${normalized.replaceFirst(RegExp(r'/$'), '')}$path');
  }
}

http.Client _newScopedClient(String certificateBase64Url) {
  late List<int> certificateDER;
  try {
    certificateDER = base64Url.decode(
      base64Url.normalize(certificateBase64Url),
    );
  } on FormatException {
    throw const AuthApiException(
      'The enrolled installation HTTPS trust anchor is invalid.',
    );
  }
  if (certificateDER.isEmpty || certificateDER.length > 16 * 1024) {
    throw const AuthApiException(
      'The enrolled installation HTTPS trust anchor is invalid.',
    );
  }
  final encoded = base64.encode(certificateDER);
  final pem = StringBuffer('-----BEGIN CERTIFICATE-----\n');
  for (var offset = 0; offset < encoded.length; offset += 64) {
    final end = (offset + 64 < encoded.length) ? offset + 64 : encoded.length;
    pem.writeln(encoded.substring(offset, end));
  }
  pem.write('-----END CERTIFICATE-----\n');
  final context = SecurityContext(withTrustedRoots: false)
    ..setTrustedCertificatesBytes(utf8.encode(pem.toString()));
  return IOClient(HttpClient(context: context));
}

class AuthApiException implements Exception {
  const AuthApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
