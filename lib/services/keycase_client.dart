import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycase_core/keycase_core.dart' as core;
import 'package:keycase_core/keycase_core.dart' show Identity, Proof;

class KeyCaseApiException implements Exception {
  final int statusCode;
  final String message;
  KeyCaseApiException(this.statusCode, this.message);
  @override
  String toString() => 'KeyCaseApiException($statusCode): $message';
}

/// Credentials for signing mutation requests.
class ClientCredentials {
  final String username;
  final String privateKey;
  const ClientCredentials({required this.username, required this.privateKey});
}

class KeyCaseClient {
  String baseUrl;
  final http.Client _client;

  KeyCaseClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  Future<bool> isHealthy() async {
    try {
      final r = await _client.get(Uri.parse('$baseUrl/health'));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<Identity> registerIdentity({
    required String username,
    required String publicKey,
    required String privateKey,
  }) async {
    final signature = await core.sign(username, privateKey);
    final body = jsonEncode({
      'username': username,
      'publicKey': publicKey,
      'signature': signature,
    });
    final r = await _client.post(
      Uri.parse('$baseUrl/api/v1/identity'),
      headers: {'Content-Type': 'application/json'},
      body: body,
    );
    _ensureOk(r);
    return Identity.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Identity?> lookupIdentity(String username) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/api/v1/identity/$username'),
    );
    if (r.statusCode == 404) return null;
    _ensureOk(r);
    return Identity.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<Identity>> searchIdentities(String query) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/api/v1/identity?q=${Uri.encodeQueryComponent(query)}'),
    );
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final results = (data['results'] as List).cast<Map<String, dynamic>>();
    return [for (final j in results) Identity.fromJson(j)];
  }

  Future<List<Proof>> listProofs(String username) async {
    final r = await _client.get(
      Uri.parse('$baseUrl/api/v1/identity/$username/proofs'),
    );
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['proofs'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) Proof.fromJson(j)];
  }

  Future<Proof> submitProof({
    required ClientCredentials creds,
    required String type,
    required String target,
    required String signature,
    String? statement,
  }) async {
    final body = jsonEncode({
      'identityUsername': creds.username,
      'type': type,
      'target': target,
      'signature': signature,
      if (statement != null) 'statement': statement,
    });
    final r = await _authPost(creds, '/api/v1/proof', body);
    _ensureOk(r);
    return Proof.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Proof> reverifyProof({
    required ClientCredentials creds,
    required String proofId,
  }) async {
    final r = await _authPost(creds, '/api/v1/proof/$proofId/verify', '');
    _ensureOk(r);
    return Proof.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Proof> signKey({
    required ClientCredentials creds,
    required String targetUsername,
    required String targetPublicKey,
  }) async {
    final signature = await core.KeySigningVerifier.sign(
      targetPublicKey: targetPublicKey,
      signerPrivateKey: creds.privateKey,
    );
    final body = jsonEncode({
      'signerUsername': creds.username,
      'signature': signature,
    });
    final r = await _authPost(
      creds,
      '/api/v1/identity/$targetUsername/sign',
      body,
    );
    _ensureOk(r);
    return Proof.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<http.Response> _authPost(
    ClientCredentials creds,
    String path,
    String body,
  ) async {
    final signature = await core.sign(body, creds.privateKey);
    return _client.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'KeyCase ${creds.username}:$signature',
      },
      body: body,
    );
  }

  void _ensureOk(http.Response r) {
    if (r.statusCode >= 200 && r.statusCode < 300) return;
    String message = 'HTTP ${r.statusCode}';
    try {
      final decoded = jsonDecode(r.body);
      if (decoded is Map && decoded['error'] is String) {
        message = decoded['error'] as String;
      } else if (decoded is Map && decoded['message'] is String) {
        message = decoded['message'] as String;
      }
    } catch (_) {}
    throw KeyCaseApiException(r.statusCode, message);
  }

  void dispose() => _client.close();
}
