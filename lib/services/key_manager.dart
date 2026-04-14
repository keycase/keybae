import 'package:keycase_core/keycase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's Ed25519 [KeyPair] and associated username in
/// [SharedPreferences]. In a production app the private key would live
/// in a platform keychain; for the MVP we accept the tradeoff.
class KeyManager {
  static const _kPublicKey = 'keybae.publicKey';
  static const _kPrivateKey = 'keybae.privateKey';
  static const _kCreatedAt = 'keybae.createdAt';
  static const _kUsername = 'keybae.username';

  Future<KeyPair?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final pub = prefs.getString(_kPublicKey);
    final priv = prefs.getString(_kPrivateKey);
    final created = prefs.getString(_kCreatedAt);
    if (pub == null || priv == null || created == null) return null;
    return KeyPair(
      publicKey: pub,
      privateKey: priv,
      createdAt: DateTime.parse(created),
    );
  }

  Future<KeyPair> generate() async {
    final kp = await generateKeyPair();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPublicKey, kp.publicKey);
    await prefs.setString(_kPrivateKey, kp.privateKey!);
    await prefs.setString(_kCreatedAt, kp.createdAt.toIso8601String());
    return kp;
  }

  Future<String?> loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsername);
  }

  Future<void> saveUsername(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsername, username);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPublicKey);
    await prefs.remove(_kPrivateKey);
    await prefs.remove(_kCreatedAt);
    await prefs.remove(_kUsername);
  }
}
