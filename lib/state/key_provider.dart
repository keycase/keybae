import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart';

import '../services/key_manager.dart';

class KeyProvider extends ChangeNotifier {
  final KeyManager _manager;
  KeyPair? _keyPair;
  String? _username;
  bool _loading = true;

  KeyProvider(this._manager) {
    _bootstrap();
  }

  KeyPair? get keyPair => _keyPair;
  String? get username => _username;
  bool get hasKeyPair => _keyPair != null;
  bool get loading => _loading;

  Future<void> _bootstrap() async {
    _keyPair = await _manager.load();
    _username = await _manager.loadUsername();
    _loading = false;
    notifyListeners();
  }

  Future<KeyPair> generate() async {
    _keyPair = await _manager.generate();
    notifyListeners();
    return _keyPair!;
  }

  Future<void> setUsername(String username) async {
    await _manager.saveUsername(username);
    _username = username;
    notifyListeners();
  }

  Future<void> clear() async {
    await _manager.clear();
    _keyPair = null;
    _username = null;
    notifyListeners();
  }
}
