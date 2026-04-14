import 'package:flutter/foundation.dart';

import '../services/keycase_client.dart';
import '../services/settings_store.dart';

class SettingsProvider extends ChangeNotifier {
  final SettingsStore _store;
  final KeyCaseClient client;
  String _baseUrl;

  SettingsProvider._(this._store, this.client, this._baseUrl);

  static Future<SettingsProvider> load() async {
    final store = SettingsStore();
    final url = await store.loadBaseUrl();
    final client = KeyCaseClient(baseUrl: url);
    return SettingsProvider._(store, client, url);
  }

  String get baseUrl => _baseUrl;

  Future<void> updateBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty || trimmed == _baseUrl) return;
    _baseUrl = trimmed;
    client.baseUrl = trimmed;
    await _store.saveBaseUrl(trimmed);
    notifyListeners();
  }
}
