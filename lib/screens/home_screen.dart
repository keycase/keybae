import 'package:flutter/material.dart';

import 'discover_screen.dart';
import 'identity_screen.dart';
import 'proofs_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = <({String title, Widget body})>[
    (title: 'Identity', body: IdentityScreen()),
    (title: 'Proofs', body: ProofsScreen()),
    (title: 'Discover', body: DiscoverScreen()),
    (title: 'Settings', body: SettingsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final screen = _tabs[_selectedIndex];
    return Scaffold(
      appBar: AppBar(
        title: Text('Keybae · ${screen.title}'),
      ),
      body: screen.body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Identity',
          ),
          NavigationDestination(
            icon: Icon(Icons.verified_outlined),
            selectedIcon: Icon(Icons.verified),
            label: 'Proofs',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
