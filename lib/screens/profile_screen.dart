import 'package:flutter/material.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:provider/provider.dart';

import '../services/keycase_client.dart';
import '../state/key_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/friendly_error.dart';
import '../widgets/proof_status_chip.dart';
import '../widgets/truncated_key.dart';

class ProfileScreen extends StatefulWidget {
  final Identity identity;
  const ProfileScreen({super.key, required this.identity});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Proof> _proofs = const [];
  bool _loading = true;
  bool _signing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = context.read<SettingsProvider>().client;
      final proofs = await client.listProofs(widget.identity.username);
      if (!mounted) return;
      setState(() {
        _proofs = proofs;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _signKey() async {
    final keys = context.read<KeyProvider>();
    if (keys.username == null || keys.keyPair?.privateKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create your identity first')),
      );
      return;
    }
    if (keys.username == widget.identity.username) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You can’t sign your own key')),
      );
      return;
    }
    setState(() => _signing = true);
    try {
      final client = context.read<SettingsProvider>().client;
      final creds = ClientCredentials(
        username: keys.username!,
        privateKey: keys.keyPair!.privateKey!,
      );
      await client.signKey(
        creds: creds,
        targetUsername: widget.identity.username,
        targetPublicKey: widget.identity.publicKey,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Signed ${widget.identity.username}’s key')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _signing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.identity;
    return Scaffold(
      appBar: AppBar(title: Text('@${id.username}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          child: Text(
                            id.username[0].toUpperCase(),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                id.username,
                                style: Theme.of(context).textTheme.headlineSmall,
                              ),
                              Text(
                                'Member since ${_formatDate(id.createdAt)}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('Public key'),
                    const SizedBox(height: 4),
                    TruncatedKey(value: id.publicKey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _signing ? null : _signKey,
              icon: _signing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.handshake),
              label: Text(_signing ? 'Signing…' : 'Sign key'),
            ),
            const SizedBox(height: 16),
            Text('Proofs', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              )
            else if (_proofs.isEmpty)
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('No proofs yet'),
                ),
              )
            else
              ..._proofs.map(
                (p) => Card(
                  child: ListTile(
                    leading: Icon(_iconFor(p.type)),
                    title: Text(p.target),
                    subtitle: Text(p.type.name.toUpperCase()),
                    trailing: ProofStatusChip(status: p.status),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static IconData _iconFor(ProofType type) => switch (type) {
        ProofType.dns => Icons.dns,
        ProofType.url => Icons.link,
        ProofType.keySigning => Icons.handshake,
      };

  static String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${_pad(l.month)}-${_pad(l.day)}';
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');
}
