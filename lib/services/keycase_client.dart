import 'package:http/http.dart' as http;
import 'dart:convert';

/// Client for communicating with a KeyCase server.
class KeyCaseClient {
  final String baseUrl;
  final http.Client _client;

  KeyCaseClient({required this.baseUrl, http.Client? client})
      : _client = client ?? http.Client();

  /// Health check.
  Future<bool> isHealthy() async {
    try {
      final response = await _client.get(Uri.parse('$baseUrl/health'));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Register a new identity.
  Future<Map<String, dynamic>> registerIdentity({
    required String username,
    required String publicKey,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/identity'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'publicKey': publicKey}),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Look up an identity by username.
  Future<Map<String, dynamic>?> lookupIdentity(String username) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/identity/$username'),
    );
    if (response.statusCode == 404) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// Submit a proof.
  Future<Map<String, dynamic>> submitProof({
    required String identityUsername,
    required String type,
    required String target,
    required String signature,
  }) async {
    final response = await _client.post(
      Uri.parse('$baseUrl/api/v1/proof'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'identityUsername': identityUsername,
        'type': type,
        'target': target,
        'signature': signature,
      }),
    );
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  /// List proofs for an identity.
  Future<List<Map<String, dynamic>>> listProofs(String username) async {
    final response = await _client.get(
      Uri.parse('$baseUrl/api/v1/identity/$username/proofs'),
    );
    final data = jsonDecode(response.body);
    if (data is List) return data.cast<Map<String, dynamic>>();
    return [];
  }

  void dispose() => _client.close();
}
