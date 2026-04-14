import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../models/file_item.dart';
import '../providers/file_provider.dart';
import '../state/key_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/relative_time.dart';

class FileDetailScreen extends StatefulWidget {
  final String fileId;
  const FileDetailScreen({super.key, required this.fileId});

  @override
  State<FileDetailScreen> createState() => _FileDetailScreenState();
}

class _FileDetailScreenState extends State<FileDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FileProvider>().refreshMetadata(widget.fileId);
    });
  }

  FileItem? _file(FileProvider p) {
    for (final f in p.files) {
      if (f.id == widget.fileId) return f;
    }
    return null;
  }

  Future<void> _download(FileItem file) async {
    setState(() => _busy = true);
    final provider = context.read<FileProvider>();
    final bytes = await provider.downloadAndDecrypt(file.id);
    if (!mounted) return;
    if (bytes == null) {
      setState(() => _busy = false);
      _toast(provider.error ?? 'Download failed');
      return;
    }
    await _saveBytes(file.filename, bytes);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _saveBytes(String filename, Uint8List bytes) async {
    try {
      String? target;
      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        target = await FilePicker.platform.saveFile(
          fileName: filename,
          bytes: bytes,
        );
      }
      if (target == null) {
        // Fallback: write to app documents directory.
        final dir = await getApplicationDocumentsDirectory();
        final path = '${dir.path}/$filename';
        await File(path).writeAsBytes(bytes);
        target = path;
      } else if (!await File(target).exists()) {
        // saveFile on some platforms doesn't actually write — do it ourselves.
        await File(target).writeAsBytes(bytes);
      }
      if (!mounted) return;
      _toast('Saved to $target');
    } catch (e) {
      if (!mounted) return;
      _toast('Save failed: $e');
    }
  }

  Future<void> _delete(FileItem file) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${file.filename}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final provider = context.read<FileProvider>();
    final navigator = Navigator.of(context);
    final success = await provider.deleteFile(file.id);
    if (!mounted) return;
    if (success) {
      navigator.pop();
    } else {
      _toast(provider.error ?? 'Delete failed');
    }
  }

  Future<void> _share(FileItem file) async {
    final username = await showDialog<String>(
      context: context,
      builder: (_) => const _ShareDialog(),
    );
    if (username == null || username.isEmpty || !mounted) return;
    final provider = context.read<FileProvider>();
    final ok = await provider.shareFile(file.id, username);
    if (!mounted) return;
    if (!ok) _toast(provider.error ?? 'Share failed');
  }

  Future<void> _unshare(FileItem file, String username) async {
    final provider = context.read<FileProvider>();
    final ok = await provider.unshareFile(file.id, username);
    if (!mounted) return;
    if (!ok) _toast(provider.error ?? 'Unshare failed');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FileProvider>();
    final me = context.watch<KeyProvider>().username;
    final file = _file(provider);

    if (file == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final isOwner = file.ownerUsername == me;

    return Scaffold(
      appBar: AppBar(
        title: Text(file.filename, overflow: TextOverflow.ellipsis),
      ),
      body: ListView(
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
                      const Icon(Icons.lock_outline,
                          color: Colors.teal, size: 32),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          file.filename,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Size: ${_fmtSize(file.size)}'),
                  Text('Owner: @${file.ownerUsername}'),
                  Text('Uploaded: ${formatRelativeTime(file.createdAt)}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : () => _download(file),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download),
            label: Text(_busy ? 'Decrypting…' : 'Download & decrypt'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('Shared with',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (isOwner)
                IconButton(
                  onPressed: () => _share(file),
                  icon: const Icon(Icons.person_add_alt),
                  tooltip: 'Share',
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (file.shares.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Not shared with anyone.'),
            )
          else
            ...file.shares.map(
              (s) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(s.username[0].toUpperCase()),
                  ),
                  title: Text('@${s.username}'),
                  subtitle: Text('since ${formatRelativeTime(s.sharedAt)}'),
                  trailing: isOwner
                      ? IconButton(
                          icon: const Icon(Icons.person_remove_alt_1),
                          onPressed: () => _unshare(file, s.username),
                          tooltip: 'Unshare',
                        )
                      : null,
                ),
              ),
            ),
          if (isOwner) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _delete(file),
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('Delete file',
                  style: TextStyle(color: Colors.red)),
            ),
          ],
        ],
      ),
    );
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

class _ShareDialog extends StatefulWidget {
  const _ShareDialog();

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  final _ctrl = TextEditingController();
  Timer? _debounce;
  List<Identity> _results = const [];
  bool _loading = false;
  String? _selected;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(v));
  }

  Future<void> _search(String q) async {
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    try {
      final client = context.read<SettingsProvider>().client;
      final r = await client.searchIdentities(query);
      if (!mounted) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Share file'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _ctrl,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search users…',
              ),
              onChanged: (v) {
                setState(() => _selected = null);
                _onChanged(v);
              },
            ),
            const SizedBox(height: 8),
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            if (_results.isNotEmpty)
              SizedBox(
                height: 200,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final id in _results)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          _selected == id.username
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                        ),
                        title: Text(id.username),
                        onTap: () {
                          setState(() {
                            _selected = id.username;
                            _ctrl.text = id.username;
                          });
                        },
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final name = _selected ?? _ctrl.text.trim();
            Navigator.of(context).pop(name.isEmpty ? null : name);
          },
          child: const Text('Share'),
        ),
      ],
    );
  }
}
