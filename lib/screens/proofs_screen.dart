import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:provider/provider.dart';

import '../state/key_provider.dart';
import '../state/proof_provider.dart';
import '../widgets/proof_status_chip.dart';

class ProofsScreen extends StatelessWidget {
  const ProofsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    final proofs = context.watch<ProofProvider>();

    if (keys.username == null) {
      return const _NoIdentityState();
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: proofs.refresh,
          child: proofs.proofs.isEmpty && !proofs.loading
              ? ListView(
                  children: const [_EmptyProofsState()],
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: proofs.proofs.length,
                  itemBuilder: (context, i) {
                    final p = proofs.proofs[i];
                    return Card(
                      child: ListTile(
                        leading: Icon(_iconFor(p.type)),
                        title: Text(p.target),
                        subtitle: Text(
                          '${p.type.name.toUpperCase()} · added '
                          '${_formatDate(p.createdAt)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ProofStatusChip(status: p.status),
                            IconButton(
                              tooltip: 'Re-verify',
                              icon: const Icon(Icons.refresh),
                              onPressed: () => _reverify(context, p),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        if (proofs.loading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(minHeight: 2),
          ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => _showAddSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Add proof'),
          ),
        ),
      ],
    );
  }

  static Future<void> _reverify(BuildContext context, Proof p) async {
    final provider = context.read<ProofProvider>();
    try {
      final updated = await provider.reverify(p.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Re-verified: ${updated.status.name}'),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Re-verify failed: $e')),
      );
    }
  }

  static void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('DNS proof'),
              subtitle: const Text('Prove ownership of a domain'),
              onTap: () {
                Navigator.pop(context);
                _openProofFlow(context, ProofType.dns);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: const Text('URL proof'),
              subtitle: const Text('Host a signed statement at a URL'),
              onTap: () {
                Navigator.pop(context);
                _openProofFlow(context, ProofType.url);
              },
            ),
          ],
        ),
      ),
    );
  }

  static void _openProofFlow(BuildContext context, ProofType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AddProofScreen(type: type)),
    );
  }

  static String _formatDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${_pad(l.month)}-${_pad(l.day)}';
  }

  static String _pad(int v) => v.toString().padLeft(2, '0');

  static IconData _iconFor(ProofType type) => switch (type) {
        ProofType.dns => Icons.dns,
        ProofType.url => Icons.link,
        ProofType.keySigning => Icons.handshake,
      };
}

class _NoIdentityState extends StatelessWidget {
  const _NoIdentityState();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Create your identity first to add proofs.',
            textAlign: TextAlign.center,
          ),
        ),
      );
}

class _EmptyProofsState extends StatelessWidget {
  const _EmptyProofsState();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 72),
        child: Column(
          children: [
            Icon(Icons.verified_outlined, size: 64, color: Colors.teal),
            SizedBox(height: 16),
            Text(
              'No proofs yet',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Text(
              'Link your identity to a domain or URL you control. Tap '
              '“Add proof” to get started.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
}

class AddProofScreen extends StatefulWidget {
  final ProofType type;
  const AddProofScreen({super.key, required this.type});

  @override
  State<AddProofScreen> createState() => _AddProofScreenState();
}

class _AddProofScreenState extends State<AddProofScreen> {
  final _targetCtrl = TextEditingController();
  ProofStatement? _statement;
  String? _signature;
  String? _publish;
  bool _preparing = false;
  bool _submitting = false;
  String? _error;

  bool get _isDns => widget.type == ProofType.dns;

  @override
  void dispose() {
    _targetCtrl.dispose();
    super.dispose();
  }

  Future<void> _prepare() async {
    final target = _normalizeTarget(_targetCtrl.text.trim());
    if (target.isEmpty) {
      setState(() => _error = _isDns ? 'Enter a domain' : 'Enter a URL');
      return;
    }
    setState(() {
      _preparing = true;
      _error = null;
    });
    try {
      final prov = context.read<ProofProvider>();
      final result = await prov.prepareProof(
        type: widget.type,
        target: target,
      );
      setState(() {
        _statement = result.statement;
        _signature = result.signature;
        _publish = result.publish;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _preparing = false);
    }
  }

  String _normalizeTarget(String raw) {
    if (_isDns) return raw.toLowerCase();
    if (raw.isEmpty) return raw;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;
    return 'https://$raw';
  }

  Future<void> _verify() async {
    if (_statement == null || _signature == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final prov = context.read<ProofProvider>();
      final proof = await prov.submit(
        type: widget.type,
        target: _statement!.target,
        statement: _statement!,
        signature: _signature!,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proof ${proof.status.name}')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isDns ? 'Add DNS proof' : 'Add URL proof';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isDns
                  ? 'Enter the domain you want to link to your identity.'
                  : 'Enter the URL where you will publish your proof document.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _targetCtrl,
              enabled: !_preparing && _publish == null,
              decoration: InputDecoration(
                labelText: _isDns ? 'Domain' : 'URL',
                hintText: _isDns ? 'example.com' : 'https://example.com/proof',
                border: const OutlineInputBorder(),
              ),
              keyboardType:
                  _isDns ? TextInputType.url : TextInputType.url,
              autocorrect: false,
            ),
            const SizedBox(height: 12),
            if (_publish == null)
              FilledButton.icon(
                onPressed: _preparing ? null : _prepare,
                icon: _preparing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note),
                label: Text(_preparing ? 'Signing…' : 'Generate proof'),
              )
            else ...[
              Text(
                _isDns
                    ? 'Add this TXT record to $_targetLabel:'
                    : 'Publish this document at $_targetLabel, then tap Verify:',
              ),
              const SizedBox(height: 12),
              _PublishBox(value: _publish!),
              const SizedBox(height: 8),
              if (_isDns)
                const Text(
                  'TXT record name: @ (root) or the subdomain you entered. '
                  'Value: the full string above.',
                  style: TextStyle(fontSize: 12),
                )
              else
                const Text(
                  'The document must be reachable at exactly that URL and '
                  'contain the BEGIN/END markers intact.',
                  style: TextStyle(fontSize: 12),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _submitting ? null : _verify,
                icon: _submitting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: Text(_submitting ? 'Verifying…' : 'Verify'),
              ),
              TextButton(
                onPressed: _submitting
                    ? null
                    : () => setState(() {
                          _statement = null;
                          _signature = null;
                          _publish = null;
                        }),
                child: const Text('Start over'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String get _targetLabel => _statement?.target ?? _targetCtrl.text;
}

class _PublishBox extends StatelessWidget {
  final String value;
  const _PublishBox({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SelectableText(
            value,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: value));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy'),
            ),
          ),
        ],
      ),
    );
  }
}
