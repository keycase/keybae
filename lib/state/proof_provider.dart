import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart';

import '../services/keycase_client.dart';
import '../widgets/friendly_error.dart';
import 'key_provider.dart';

class ProofProvider extends ChangeNotifier {
  final KeyProvider _keys;
  KeyCaseClient _client;

  List<Proof> _proofs = const [];
  bool _loading = false;
  String? _error;

  ProofProvider({required KeyProvider keys, required KeyCaseClient client})
      : _keys = keys,
        _client = client {
    _keys.addListener(_onKeysChanged);
    if (_keys.username != null) {
      // ignore: discarded_futures
      refresh();
    }
  }

  void updateClient(KeyCaseClient client) {
    _client = client;
  }

  List<Proof> get proofs => _proofs;
  bool get loading => _loading;
  String? get error => _error;

  void _onKeysChanged() {
    if (_keys.username == null) {
      _proofs = const [];
      notifyListeners();
    }
  }

  ClientCredentials? _creds() {
    final username = _keys.username;
    final priv = _keys.keyPair?.privateKey;
    if (username == null || priv == null) return null;
    return ClientCredentials(username: username, privateKey: priv);
  }

  Future<void> refresh() async {
    final username = _keys.username;
    if (username == null) {
      _proofs = const [];
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      _proofs = await _client.listProofs(username);
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _setLoading(false);
    }
  }

  /// Build a signed [ProofStatement] for [type] against [target], returning
  /// the statement, its base64 signature, and the final record/document
  /// string that the user must publish.
  Future<({ProofStatement statement, String signature, String publish})>
      prepareProof({
    required ProofType type,
    required String target,
  }) async {
    final username = _keys.username;
    final priv = _keys.keyPair?.privateKey;
    if (username == null || priv == null) {
      throw StateError('identity not ready');
    }
    final statement = ProofStatement(
      username: username,
      target: target,
      type: type,
      timestamp: DateTime.now().toUtc(),
    );
    final signature = await sign(statement.canonical(), priv);
    final publish = switch (type) {
      ProofType.dns =>
        DnsProofVerifier.generateTxtRecord(statement, signature),
      ProofType.url =>
        UrlProofVerifier.generateProofDocument(statement, signature),
      ProofType.keySigning => signature,
    };
    return (statement: statement, signature: signature, publish: publish);
  }

  Future<Proof> submit({
    required ProofType type,
    required String target,
    required ProofStatement statement,
    required String signature,
  }) async {
    final creds = _creds();
    if (creds == null) throw StateError('identity not ready');
    _setLoading(true);
    try {
      final proof = await _client.submitProof(
        creds: creds,
        type: type.name,
        target: target,
        signature: signature,
        statement: statement.canonical(),
      );
      _mergeOrAdd(proof);
      _error = null;
      return proof;
    } catch (e) {
      _error = friendlyError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<Proof> reverify(String proofId) async {
    final creds = _creds();
    if (creds == null) throw StateError('identity not ready');
    _setLoading(true);
    try {
      final updated = await _client.reverifyProof(
        creds: creds,
        proofId: proofId,
      );
      _mergeOrAdd(updated);
      _error = null;
      return updated;
    } catch (e) {
      _error = friendlyError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  void _mergeOrAdd(Proof updated) {
    final i = _proofs.indexWhere((p) => p.id == updated.id);
    final next = [..._proofs];
    if (i >= 0) {
      next[i] = updated;
    } else {
      next.add(updated);
    }
    _proofs = next;
  }

  void _setLoading(bool value) {
    _loading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _keys.removeListener(_onKeysChanged);
    super.dispose();
  }
}
