import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/identity_screen.dart';
import 'screens/proofs_screen.dart';
import 'screens/settings_screen.dart';

class KeybaeApp extends StatelessWidget {
  const KeybaeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Keybae',
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
      home: const HomeScreen(),
      routes: {
        '/identity': (context) => const IdentityScreen(),
        '/proofs': (context) => const ProofsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
