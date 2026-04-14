import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/message_provider.dart';
import 'discover_screen.dart';
import 'files_screen.dart';
import 'identity_screen.dart';
import 'messages_screen.dart';
import 'settings_screen.dart';
import 'teams_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static const _tabs = <({String title, Widget body})>[
    (title: 'Identity', body: IdentityScreen()),
    (title: 'Messages', body: MessagesScreen()),
    (title: 'Teams', body: TeamsScreen()),
    (title: 'Files', body: FilesScreen()),
    (title: 'Settings', body: SettingsScreen()),
  ];

  void _openDiscover() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Keybae · Discover')),
          body: const DiscoverScreen(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = _tabs[_selectedIndex];
    final unread = context.watch<MessageProvider>().unreadCount;
    return Scaffold(
      appBar: AppBar(
        title: Text('Keybae · ${screen.title}'),
        actions: [
          IconButton(
            tooltip: 'Discover',
            icon: const Icon(Icons.search),
            onPressed: _openDiscover,
          ),
        ],
      ),
      body: screen.body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Identity',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble_outline),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.chat_bubble),
            ),
            label: 'Messages',
          ),
          const NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Teams',
          ),
          const NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder),
            label: 'Files',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
