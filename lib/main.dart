import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/key_manager.dart';
import 'state/identity_provider.dart';
import 'state/key_provider.dart';
import 'state/message_provider.dart';
import 'state/proof_provider.dart';
import 'state/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await SettingsProvider.load();
  final keys = KeyProvider(KeyManager());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
        ChangeNotifierProvider<KeyProvider>.value(value: keys),
        ChangeNotifierProvider<IdentityProvider>(
          create: (_) => IdentityProvider(keys: keys, client: settings.client),
        ),
        ChangeNotifierProvider<ProofProvider>(
          create: (_) => ProofProvider(keys: keys, client: settings.client),
        ),
        ChangeNotifierProvider<MessageProvider>(
          create: (_) => MessageProvider(keys: keys, client: settings.client),
        ),
      ],
      child: const KeybaeApp(),
    ),
  );
}
