import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:keycase_core/keycase_core.dart' as core;
import 'package:keycase_core/keycase_core.dart' show Identity, Proof;

import '../models/file_item.dart';
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

  // ---- Files ----

  Future<FileItem> uploadFile({
    required ClientCredentials creds,
    required String filename,
    required Uint8List encryptedBytes,
    required String encryptedKey,
    required String nonce,
    String? folderId,
  }) async {
    final uri = Uri.parse('$baseUrl/api/v1/files');
    final req = http.MultipartRequest('POST', uri);
    // Sign the filename+key payload so the server can attribute the upload.
    final canonical = '$filename|$encryptedKey|$nonce';
    final signature = await core.sign(canonical, creds.privateKey);
    req.headers['Authorization'] = 'KeyCase ${creds.username}:$signature';
    req.fields['filename'] = filename;
    req.fields['encryptedKey'] = encryptedKey;
    req.fields['nonce'] = nonce;
    if (folderId != null) req.fields['folderId'] = folderId;
    req.files.add(http.MultipartFile.fromBytes(
      'file',
      encryptedBytes,
      filename: filename,
    ));
    final streamed = await _client.send(req);
    final r = await http.Response.fromStream(streamed);
    _ensureOk(r);
    return FileItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<FileItem>> listFiles({
    required ClientCredentials creds,
    String? folderId,
  }) async {
    final path = folderId == null
        ? '/api/v1/files'
        : '/api/v1/files?folderId=$folderId';
    final r = await _authGet(creds, path);
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['files'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) FileItem.fromJson(j)];
  }

  Future<FileItem> getFileMetadata({
    required ClientCredentials creds,
    required String fileId,
  }) async {
    final r = await _authGet(creds, '/api/v1/files/$fileId');
    _ensureOk(r);
    return FileItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<Uint8List> downloadFile({
    required ClientCredentials creds,
    required String fileId,
  }) async {
    final path = '/api/v1/files/$fileId/download';
    final signature = await core.sign('GET $path', creds.privateKey);
    final r = await _client.get(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Authorization': 'KeyCase ${creds.username}:$signature',
      },
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw KeyCaseApiException(r.statusCode, 'download failed');
    }
    return r.bodyBytes;
  }

  Future<void> deleteFile({
    required ClientCredentials creds,
    required String fileId,
  }) async {
    final r = await _authDelete(creds, '/api/v1/files/$fileId');
    _ensureOk(r);
  }

  Future<FileItem> shareFile({
    required ClientCredentials creds,
    required String fileId,
    required String username,
    required String encryptedKey,
    required String nonce,
  }) async {
    final body = jsonEncode({
      'username': username,
      'encryptedKey': encryptedKey,
      'nonce': nonce,
    });
    final r = await _authPost(creds, '/api/v1/files/$fileId/share', body);
    _ensureOk(r);
    return FileItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<void> unshareFile({
    required ClientCredentials creds,
    required String fileId,
    required String username,
  }) async {
    final r = await _authDelete(creds, '/api/v1/files/$fileId/share/$username');
    _ensureOk(r);
  }

  Future<FolderItem> createFolder({
    required ClientCredentials creds,
    required String name,
    String? parentFolderId,
  }) async {
    final body = jsonEncode({
      'name': name,
      if (parentFolderId != null) 'parentFolderId': parentFolderId,
    });
    final r = await _authPost(creds, '/api/v1/folders', body);
    _ensureOk(r);
    return FolderItem.fromJson(jsonDecode(r.body) as Map<String, dynamic>);
  }

  Future<List<FolderItem>> listFolders({
    required ClientCredentials creds,
    String? parentFolderId,
  }) async {
    final path = parentFolderId == null
        ? '/api/v1/folders'
        : '/api/v1/folders?parentFolderId=$parentFolderId';
    final r = await _authGet(creds, path);
    _ensureOk(r);
    final data = jsonDecode(r.body) as Map<String, dynamic>;
    final arr = (data['folders'] as List).cast<Map<String, dynamic>>();
    return [for (final j in arr) FolderItem.fromJson(j)];
  }

  Future<void> deleteFolder({
    required ClientCredentials creds,
    required String folderId,
  }) async {
    final r = await _authDelete(creds, '/api/v1/folders/$folderId');
    _ensureOk(r);
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
