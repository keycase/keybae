import 'package:flutter/material.dart';

import 'main.dart' show rootMessengerKey;
import 'screens/bootstrap_screen.dart';

class KeybaeApp extends StatelessWidget {
  const KeybaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keybae',
      scaffoldMessengerKey: rootMessengerKey,
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      home: const BootstrapScreen(),
    );
  }
}
