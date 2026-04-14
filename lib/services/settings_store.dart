import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore {
  static const _kBaseUrl = 'keybae.baseUrl';
  static const defaultBaseUrl = 'http://localhost:8080';

  Future<String> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl) ?? defaultBaseUrl;
  }

  Future<void> saveBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, url);
  }
}
