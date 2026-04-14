import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/key_provider.dart';
import 'home_screen.dart';

/// Shown while the key manager is loading secrets off disk. Prevents
/// downstream screens from rendering a "no identity" state before the
/// key pair has actually been read.
class BootstrapScreen extends StatelessWidget {
  const BootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    if (!keys.loading) return const HomeScreen();
    return const _SplashView();
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.key,
                size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Keybae',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
      ),
    );
  }
}
