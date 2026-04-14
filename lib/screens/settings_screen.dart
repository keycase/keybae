import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../state/identity_provider.dart';
import '../state/key_provider.dart';
import '../state/proof_provider.dart';
import '../state/settings_provider.dart';

const String kAppVersion = '0.1.0';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _urlCtrl;

  @override
  void initState() {
    super.initState();
    _urlCtrl = TextEditingController(
      text: context.read<SettingsProvider>().baseUrl,
    );
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveUrl() async {
    await context.read<SettingsProvider>().updateBaseUrl(_urlCtrl.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Server URL saved')),
    );
    // Refresh data against the new server.
    await context.read<IdentityProvider>().refresh();
    if (!mounted) return;
    await context.read<ProofProvider>().refresh();
  }

  Future<void> _exportBackup() async {
    final keys = context.read<KeyProvider>();
    final kp = keys.keyPair;
    if (kp == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No key pair to export')),
      );
      return;
    }
    final payload = jsonEncode({
      'version': 1,
      'username': keys.username,
      'publicKey': kp.publicKey,
      'privateKey': kp.privateKey,
      'createdAt': kp.createdAt.toIso8601String(),
    });
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Key backup'),
        content: SingleChildScrollView(
          child: SelectableText(
            payload,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: payload));
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Backup copied')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _resetIdentity() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete local identity?'),
        content: const Text(
          'This removes your key pair and username from this device. '
          'Make sure you have a backup if you want to recover the identity.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await context.read<KeyProvider>().clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Local identity cleared')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    final kp = keys.keyPair;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Server', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _urlCtrl,
          decoration: const InputDecoration(
            labelText: 'Base URL',
            border: OutlineInputBorder(),
          ),
          keyboardType: TextInputType.url,
          autocorrect: false,
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _saveUrl,
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
        const Divider(height: 32),
        Text('Your key', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (kp == null)
          const Card(
            child: ListTile(
              leading: Icon(Icons.key_off),
              title: Text('No key pair yet'),
              subtitle: Text('Create an identity to generate one.'),
            ),
          )
        else ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Public key'),
                  const SizedBox(height: 4),
                  SelectableText(
                    kp.publicKey,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        await Clipboard.setData(
                            ClipboardData(text: kp.publicKey));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Public key copied')),
                        );
                      },
                      icon: const Icon(Icons.copy, size: 16),
                      label: const Text('Copy'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _exportBackup,
            icon: const Icon(Icons.download),
            label: const Text('Export backup'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _resetIdentity,
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            label: const Text(
              'Delete local identity',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
        const Divider(height: 32),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Keybae'),
          subtitle: Text('Version $kAppVersion'),
        ),
      ],
    );
  }
}
