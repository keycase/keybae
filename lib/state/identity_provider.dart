import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart';

import '../services/keycase_client.dart';
import '../widgets/friendly_error.dart';
import 'key_provider.dart';

class IdentityProvider extends ChangeNotifier {
  final KeyProvider _keys;
  KeyCaseClient _client;

  Identity? _identity;
  bool _loading = false;
  String? _error;

  IdentityProvider({required KeyProvider keys, required KeyCaseClient client})
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

  Identity? get identity => _identity;
  bool get loading => _loading;
  String? get error => _error;

  void _onKeysChanged() {
    if (_keys.username == null) {
      _identity = null;
      notifyListeners();
    }
  }

  Future<Identity> register(String username) async {
    final kp = _keys.keyPair;
    if (kp == null || kp.privateKey == null) {
      throw StateError('cannot register without a key pair');
    }
    _setLoading(true);
    try {
      final id = await _client.registerIdentity(
        username: username,
        publicKey: kp.publicKey,
        privateKey: kp.privateKey!,
      );
      await _keys.setUsername(username);
      _identity = id;
      _error = null;
      return id;
    } catch (e) {
      _error = friendlyError(e);
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> refresh() async {
    final username = _keys.username;
    if (username == null) {
      _identity = null;
      notifyListeners();
      return;
    }
    _setLoading(true);
    try {
      _identity = await _client.lookupIdentity(username);
      _error = null;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _setLoading(false);
    }
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
