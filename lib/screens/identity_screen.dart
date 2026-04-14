import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/identity_provider.dart';
import '../state/key_provider.dart';
import '../state/proof_provider.dart';
import '../widgets/friendly_error.dart';
import '../widgets/proof_status_chip.dart';
import '../widgets/truncated_key.dart';
import 'proofs_screen.dart';

class IdentityScreen extends StatelessWidget {
  const IdentityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    if (keys.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (keys.username == null) {
      return const _CreateIdentityView();
    }
    return const _IdentityView();
  }
}

class _CreateIdentityView extends StatefulWidget {
  const _CreateIdentityView();

  @override
  State<_CreateIdentityView> createState() => _CreateIdentityViewState();
}

class _CreateIdentityViewState extends State<_CreateIdentityView> {
  final _usernameCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  static final _usernameRegex = RegExp(r'^[a-z0-9]{3,32}$');

  @override
  void dispose() {
    _usernameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtrl.text.trim().toLowerCase();
    if (!_usernameRegex.hasMatch(username)) {
      setState(() => _errorText =
          'Use 3–32 lowercase letters or digits (a–z, 0–9).');
      return;
    }
    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final keys = context.read<KeyProvider>();
    final identities = context.read<IdentityProvider>();
    try {
      if (!keys.hasKeyPair) {
        await keys.generate();
      }
      await identities.register(username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Welcome, $username!')),
      );
      // Fetch proofs now that we have an identity.
      // ignore: use_build_context_synchronously
      await context.read<ProofProvider>().refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorText = friendlyError(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.key, size: 72, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                'Create your identity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text(
                'Pick a username. We will generate an Ed25519 key pair on '
                'this device and register you with the server.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _usernameCtrl,
                enabled: !_submitting,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Username',
                  hintText: 'alice',
                  border: const OutlineInputBorder(),
                  errorText: _errorText,
                ),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(
                  _submitting ? 'Creating…' : 'Create identity',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IdentityView extends StatelessWidget {
  const _IdentityView();

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    final identityProvider = context.watch<IdentityProvider>();
    final proofs = context.watch<ProofProvider>();
    final kp = keys.keyPair;
    final identity = identityProvider.identity;

    return RefreshIndicator(
      onRefresh: () async {
        await identityProvider.refresh();
        await proofs.refresh();
      },
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
                      const Icon(Icons.person, size: 32, color: Colors.teal),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          keys.username ?? '—',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                      if (identityProvider.loading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('Public key'),
                  const SizedBox(height: 4),
                  if (kp != null) TruncatedKey(value: kp.publicKey),
                  const SizedBox(height: 12),
                  Text(
                    'Created ${_formatDate(identity?.createdAt ?? kp?.createdAt)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (identityProvider.error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      identityProvider.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                'Verified proofs',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Keybae · Proofs')),
                      body: const ProofsScreen(),
                    ),
                  ),
                ),
                icon: const Icon(Icons.tune, size: 18),
                label: const Text('Manage'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (proofs.loading && proofs.proofs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (proofs.proofs.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('No proofs yet'),
                subtitle: Text(
                  'Tap Manage to link a domain, URL, or get another user to '
                  'sign your key.',
                ),
              ),
            )
          else
            ...proofs.proofs.map(
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
    );
  }

  static String _formatDate(DateTime? d) {
    if (d == null) return '—';
    final l = d.toLocal();
    return '${l.year}-${_pad(l.month)}-${_pad(l.day)}';
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');

  static IconData _iconFor(dynamic type) => switch (type.toString()) {
        'ProofType.dns' => Icons.dns,
        'ProofType.url' => Icons.link,
        'ProofType.keySigning' => Icons.handshake,
        _ => Icons.verified,
      };
}
