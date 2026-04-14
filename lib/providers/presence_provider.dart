import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../state/settings_provider.dart';

class _Entry {
  final bool online;
  final DateTime fetchedAt;
  const _Entry(this.online, this.fetchedAt);
}

/// Caches per-username online status with a 30-second TTL.
class PresenceProvider extends ChangeNotifier {
  final SettingsProvider _settings;
  final Map<String, _Entry> _cache = {};
  final Set<String> _inflight = {};
  static const Duration _ttl = Duration(seconds: 30);

  PresenceProvider(this._settings);

  bool? online(String username) {
    final e = _cache[username];
    if (e == null) return null;
    if (DateTime.now().difference(e.fetchedAt) > _ttl) return null;
    return e.online;
  }

  Future<void> checkPresence(List<String> usernames) async {
    final now = DateTime.now();
    final stale = usernames.where((u) {
      if (_inflight.contains(u)) return false;
      final e = _cache[u];
      return e == null || now.difference(e.fetchedAt) > _ttl;
    }).toList();
    if (stale.isEmpty) return;
    _inflight.addAll(stale);
    try {
      final query = stale.map(Uri.encodeQueryComponent).join(',');
      final uri = Uri.parse(
          '${_settings.baseUrl}/api/v1/presence?usernames=$query');
      final r = await http.get(uri);
      if (r.statusCode < 200 || r.statusCode >= 300) return;
      final data = jsonDecode(r.body);
      if (data is! Map<String, dynamic>) return;
      final results = data['presence'];
      if (results is! Map<String, dynamic>) return;
      final ts = DateTime.now();
      for (final entry in results.entries) {
        _cache[entry.key] = _Entry(entry.value == true, ts);
      }
      notifyListeners();
    } catch (_) {
      // Best-effort; stale cache is still returned.
    } finally {
      _inflight.removeAll(stale);
    }
  }
}
