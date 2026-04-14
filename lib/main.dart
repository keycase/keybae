import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'providers/file_provider.dart';
import 'providers/presence_provider.dart';
import 'providers/team_provider.dart';
import 'services/event_handler.dart';
import 'services/key_manager.dart';
import 'services/ws_service.dart';
import 'state/identity_provider.dart';
import 'state/key_provider.dart';
import 'state/message_provider.dart';
import 'state/proof_provider.dart';
import 'state/settings_provider.dart';

/// Global messenger key so background event handlers can show snackbars
/// without a BuildContext.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsProvider.load();
  final keys = KeyProvider(KeyManager());

  final identities =
      IdentityProvider(keys: keys, client: settings.client);
  final proofs = ProofProvider(keys: keys, client: settings.client);
  final messages = MessageProvider(keys: keys, client: settings.client);
  final teams = TeamProvider(keys: keys, client: settings.client);
  final files = FileProvider(keys: keys, client: settings.client);
  final presence = PresenceProvider(settings);
  final ws = WsService();
  final eventHandler = EventHandler(
    ws: ws,
    messages: messages,
    teams: teams,
    files: files,
    identities: identities,
    proofs: proofs,
    messengerKey: rootMessengerKey,
  )..start();

  // Reactively (re)connect the websocket whenever the identity or
  // server URL changes. Disconnect when the user logs out.
  void syncWs() {
    final username = keys.username;
    final priv = keys.keyPair?.privateKey;
    if (username != null && priv != null) {
      // ignore: discarded_futures
      ws.connect(
        serverUrl: settings.baseUrl,
        username: username,
        privateKey: priv,
      );
    } else {
      // ignore: discarded_futures
      ws.disconnect();
    }
  }

  keys.addListener(syncWs);
  settings.addListener(syncWs);
  // Kick off an initial attempt in case the identity was already loaded.
  syncWs();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<KeyProvider>.value(value: keys),
        ChangeNotifierProvider<IdentityProvider>.value(value: identities),
        ChangeNotifierProvider<ProofProvider>.value(value: proofs),
        ChangeNotifierProvider<MessageProvider>.value(value: messages),
        ChangeNotifierProvider<TeamProvider>.value(value: teams),
        ChangeNotifierProvider<FileProvider>.value(value: files),
        ChangeNotifierProvider<PresenceProvider>.value(value: presence),
        Provider<WsService>.value(value: ws),
        Provider<EventHandler>.value(value: eventHandler),
      ],
      child: const KeybaeApp(),
    ),
  );
}
