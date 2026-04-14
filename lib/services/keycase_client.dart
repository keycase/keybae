import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:keycase_core/keycase_core.dart' as core;
import 'package:keycase_core/keycase_core.dart' show Identity, Proof;

import '../models/message.dart';
import '../models/team.dart';

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

  Future<Message> sendMessage({
    required ClientCredentials creds,
    required String recipientUsername,
    required String encryptedBody,
    required String nonce,
  }) async {
    final body = jsonEncode({
      'recipientUsername': recipientUsername,
      'encryptedBody': encryptedBody,
      'nonce': nonce,
    });
    final r = await _authPost(creds, '/api/v1/messages', body);
    _ensureOk(r);
    return Message.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<Message>> getInbox({
    required ClientCredentials creds,
    bool unreadOnly = false,
  }) async {
    final path = unreadOnly ? '/api/v1/messages?unread=true' : '/api/v1/messages';
    final r = await _authGet(creds, path);
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['messages'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) Message.fromJson(j)];
  }

  Future<List<Message>> getConversation({
    required ClientCredentials creds,
    required String username,
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _authGet(
      creds,
      '/api/v1/messages/$username?limit=$limit&offset=$offset',
    );
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['messages'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) Message.fromJson(j)];
  }

  Future<void> markRead({
    required ClientCredentials creds,
    required String messageId,
  }) async {
    final r = await _authPut(creds, '/api/v1/messages/$messageId/read', '');
    _ensureOk(r);
  }

  // ---- Teams ----

  Future<Team> createTeam({
    required ClientCredentials creds,
    required String name,
    required String displayName,
  }) async {
    final body = jsonEncode({'name': name, 'displayName': displayName});
    final r = await _authPost(creds, '/api/v1/teams', body);
    _ensureOk(r);
    return Team.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<Team>> getMyTeams({required ClientCredentials creds}) async {
    final r = await _authGet(creds, '/api/v1/teams');
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['teams'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) Team.fromJson(j)];
  }

  Future<Team> getTeam({
    required ClientCredentials creds,
    required String teamId,
  }) async {
    final r = await _authGet(creds, '/api/v1/teams/$teamId');
    _ensureOk(r);
    return Team.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Team> addTeamMember({
    required ClientCredentials creds,
    required String teamId,
    required String username,
    required String role,
  }) async {
    final body = jsonEncode({'username': username, 'role': role});
    final r = await _authPost(creds, '/api/v1/teams/$teamId/members', body);
    _ensureOk(r);
    return Team.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> removeTeamMember({
    required ClientCredentials creds,
    required String teamId,
    required String username,
  }) async {
    final r = await _authDelete(
      creds,
      '/api/v1/teams/$teamId/members/$username',
    );
    _ensureOk(r);
  }

  Future<Team> updateMemberRole({
    required ClientCredentials creds,
    required String teamId,
    required String username,
    required String role,
  }) async {
    final body = jsonEncode({'role': role});
    final r = await _authPut(
      creds,
      '/api/v1/teams/$teamId/members/$username/role',
      body,
    );
    _ensureOk(r);
    return Team.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> deleteTeam({
    required ClientCredentials creds,
    required String teamId,
  }) async {
    final r = await _authDelete(creds, '/api/v1/teams/$teamId');
    _ensureOk(r);
  }

  Future<TeamMessage> sendTeamMessage({
    required ClientCredentials creds,
    required String teamId,
    required List<Map<String, String>> recipients,
  }) async {
    final body = jsonEncode({'recipients': recipients});
    final r = await _authPost(creds, '/api/v1/teams/$teamId/messages', body);
    _ensureOk(r);
    return TeamMessage.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<TeamMessage>> getTeamMessages({
    required ClientCredentials creds,
    required String teamId,
    int limit = 50,
    int offset = 0,
  }) async {
    final r = await _authGet(
      creds,
      '/api/v1/teams/$teamId/messages?limit=$limit&offset=$offset',
    );
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['messages'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) TeamMessage.fromJson(j)];
  }

  Future<http.Response> _authDelete(
    ClientCredentials creds,
    String path,
  ) async {
    final signature = await core.sign('DELETE $path', creds.privateKey);
    return _client.delete(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'KeyCase ${creds.username}:$signature',
      },
    );
  }

  Future<http.Response> _authGet(ClientCredentials creds, String path) async {
    final signature = await core.sign('GET $path', creds.privateKey);
    return _client.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'KeyCase ${creds.username}:$signature',
      },
    );
  }

  Future<http.Response> _authPut(
    ClientCredentials creds,
    String path,
    String body,
  ) async {
    final signature = await core.sign(body.isEmpty ? 'PUT $path' : body, creds.privateKey);
    return _client.put(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'KeyCase ${creds.username}:$signature',
      },
      body: body,
    );
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
