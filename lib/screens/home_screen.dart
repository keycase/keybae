import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keybae'),
      ),
      body: Center(
        child: _getBody(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
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

  Widget _getBody() {
    switch (_selectedIndex) {
      case 0:
        return const _IdentityTab();
      case 1:
        return const _ProofsTab();
      case 2:
        return const _DiscoverTab();
      case 3:
        return const _SettingsTab();
      default:
        return const _IdentityTab();
    }
  }
}

class _IdentityTab extends StatelessWidget {
  const _IdentityTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.key, size: 64, color: Colors.teal),
          SizedBox(height: 16),
          Text('Your Identity', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text('Create or import your cryptographic identity'),
        ],
      ),
    );
  }
}

class _ProofsTab extends StatelessWidget {
  const _ProofsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.verified, size: 64, color: Colors.teal),
          SizedBox(height: 16),
          Text('Your Proofs', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text('Link your identity to domains and URLs'),
        ],
      ),
    );
  }
}

class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 64, color: Colors.teal),
          SizedBox(height: 16),
          Text('Discover', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text('Find and verify other identities'),
        ],
      ),
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.settings, size: 64, color: Colors.teal),
          SizedBox(height: 16),
          Text('Settings', style: TextStyle(fontSize: 24)),
          SizedBox(height: 8),
          Text('Server, keys, and preferences'),
        ],
      ),
    );
  }
}
