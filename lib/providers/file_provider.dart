import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart' show Identity;

import '../models/file_item.dart';
import '../services/file_crypto.dart';
import '../services/keycase_client.dart';
import '../state/key_provider.dart';

/// Maximum bytes accepted for upload.
const int kMaxFileUploadBytes = 50 * 1024 * 1024;

class FileProvider extends ChangeNotifier {
  final KeyProvider _keys;
  final FileCrypto _crypto;
  KeyCaseClient _client;

  List<FolderItem> _folders = const [];
  List<FileItem> _files = const [];
  final List<FolderItem> _breadcrumb = [];
  String? _currentFolderId;
  final Map<String, Identity> _identityCache = {};

  bool _loading = false;
  bool _uploading = false;
  String? _error;

  FileProvider({
    required KeyProvider keys,
    required KeyCaseClient client,
    FileCrypto? crypto,
  })  : _keys = keys,
        _client = client,
        _crypto = crypto ?? FileCrypto() {
    _keys.addListener(_onKeysChanged);
  }

  void updateClient(KeyCaseClient client) {
    _client = client;
  }

  List<FolderItem> get folders => _folders;
  List<FileItem> get files => _files;
  List<FolderItem> get breadcrumb => List.unmodifiable(_breadcrumb);
  String? get currentFolderId => _currentFolderId;
  bool get loading => _loading;
  bool get uploading => _uploading;
  String? get error => _error;

  void _onKeysChanged() {
    if (_keys.username == null) {
      _folders = const [];
      _files = const [];
      _breadcrumb.clear();
      _currentFolderId = null;
      _identityCache.clear();
      notifyListeners();
    }
  }

  ClientCredentials? _creds() {
    final kp = _keys.keyPair;
    final username = _keys.username;
    if (kp == null || kp.privateKey == null || username == null) return null;
    return ClientCredentials(username: username, privateKey: kp.privateKey!);
  }

  Future<Identity?> _lookupIdentity(String username) async {
    final cached = _identityCache[username];
    if (cached != null) return cached;
    final id = await _client.lookupIdentity(username);
    if (id != null) _identityCache[username] = id;
    return id;
  }

  Future<void> refresh() async {
    final creds = _creds();
    if (creds == null) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final folders = await _client.listFolders(
        creds: creds,
        parentFolderId: _currentFolderId,
      );
      final files = await _client.listFiles(
        creds: creds,
        folderId: _currentFolderId,
      );
      _folders = folders;
      _files = files;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> navigateToFolder(FolderItem folder) async {
    _breadcrumb.add(folder);
    _currentFolderId = folder.id;
    await refresh();
  }

  Future<void> navigateUp() async {
    if (_breadcrumb.isEmpty) return;
    _breadcrumb.removeLast();
    _currentFolderId =
        _breadcrumb.isEmpty ? null : _breadcrumb.last.id;
    await refresh();
  }

  Future<void> navigateToRoot() async {
    _breadcrumb.clear();
    _currentFolderId = null;
    await refresh();
  }

  Future<void> navigateToBreadcrumb(int index) async {
    if (index < -1 || index >= _breadcrumb.length) return;
    if (index == -1) {
      return navigateToRoot();
    }
    _breadcrumb.removeRange(index + 1, _breadcrumb.length);
    _currentFolderId = _breadcrumb.last.id;
    await refresh();
  }

  Future<bool> uploadFile(String filename, Uint8List bytes) async {
    if (bytes.length > kMaxFileUploadBytes) {
      _error = 'File exceeds 50 MB limit.';
      notifyListeners();
      return false;
    }
    final creds = _creds();
    final kp = _keys.keyPair;
    if (creds == null || kp == null || kp.privateKey == null) return false;
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      final encrypted = await _crypto.encryptFile(
        bytes,
        kp.publicKey,
        kp.privateKey!,
      );
      final file = await _client.uploadFile(
        creds: creds,
        filename: filename,
        encryptedBytes: encrypted.encryptedBytes,
        encryptedKey: encrypted.encryptedKey,
        nonce: encrypted.nonce,
        folderId: _currentFolderId,
      );
      _files = [..._files, file];
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<Uint8List?> downloadAndDecrypt(String fileId) async {
    final creds = _creds();
    final kp = _keys.keyPair;
    if (creds == null || kp == null || kp.privateKey == null) return null;
    try {
      final meta = await _client.getFileMetadata(creds: creds, fileId: fileId);
      final bytes = await _client.downloadFile(creds: creds, fileId: fileId);
      // Whoever owns the envelope key we can unwrap is the "sender" for
      // the purpose of the key exchange. For owner, it's ourselves; for
      // shared-with-me, it's the owner.
      final otherUsername = meta.ownerUsername == _keys.username
          ? _keys.username!
          : meta.ownerUsername;
      final other = await _lookupIdentity(otherUsername);
      if (other == null) {
        _error = 'owner identity not found';
        notifyListeners();
        return null;
      }
      return await _crypto.decryptFile(
        bytes,
        meta.encryptedKey,
        meta.nonce,
        other.publicKey,
        kp.privateKey!,
      );
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteFile(String fileId) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      await _client.deleteFile(creds: creds, fileId: fileId);
      _files = _files.where((f) => f.id != fileId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> shareFile(String fileId, String recipientUsername) async {
    final creds = _creds();
    final kp = _keys.keyPair;
    if (creds == null || kp == null || kp.privateKey == null) return false;
    try {
      final meta = await _client.getFileMetadata(creds: creds, fileId: fileId);
      final recipient = await _lookupIdentity(recipientUsername);
      if (recipient == null) {
        _error = 'recipient not found';
        notifyListeners();
        return false;
      }
      final rewrapped = await _crypto.reEncryptKeyForRecipient(
        meta.encryptedKey,
        meta.nonce,
        kp.publicKey,
        kp.privateKey!,
        recipient.publicKey,
      );
      final updated = await _client.shareFile(
        creds: creds,
        fileId: fileId,
        username: recipientUsername,
        encryptedKey: rewrapped.encryptedKey,
        nonce: rewrapped.nonce,
      );
      _replaceFile(updated);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> unshareFile(String fileId, String username) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      await _client.unshareFile(
        creds: creds,
        fileId: fileId,
        username: username,
      );
      // Refresh metadata for that file
      final meta = await _client.getFileMetadata(creds: creds, fileId: fileId);
      _replaceFile(meta);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  void _replaceFile(FileItem updated) {
    _files = [
      for (final f in _files) f.id == updated.id ? updated : f,
    ];
    notifyListeners();
  }

  Future<bool> createFolder(String name) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      final folder = await _client.createFolder(
        creds: creds,
        name: name,
        parentFolderId: _currentFolderId,
      );
      _folders = [..._folders, folder];
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteFolder(String folderId) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      await _client.deleteFolder(creds: creds, folderId: folderId);
      _folders = _folders.where((f) => f.id != folderId).toList();
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<FileItem?> refreshMetadata(String fileId) async {
    final creds = _creds();
    if (creds == null) return null;
    try {
      final meta = await _client.getFileMetadata(creds: creds, fileId: fileId);
      _replaceFile(meta);
      return meta;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  @override
  void dispose() {
    _keys.removeListener(_onKeysChanged);
    super.dispose();
  }
}
