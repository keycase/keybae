import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/file_item.dart';
import '../providers/file_provider.dart';
import '../state/key_provider.dart';
import '../widgets/relative_time.dart';
import 'file_detail_screen.dart';

class FilesScreen extends StatefulWidget {
  const FilesScreen({super.key});

  @override
  State<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends State<FilesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<KeyProvider>().username != null) {
        context.read<FileProvider>().refresh();
      }
    });
  }

  Future<void> _refresh() => context.read<FileProvider>().refresh();

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    final bytes = picked.bytes;
    if (bytes == null) {
      _toast('Could not read file bytes');
      return;
    }
    if (!mounted) return;
    final provider = context.read<FileProvider>();
    final ok = await provider.uploadFile(picked.name, bytes);
    if (!mounted) return;
    if (!ok) _toast(provider.error ?? 'Upload failed');
  }

  Future<void> _newFolder() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewFolderDialog(),
    );
    if (name == null || name.isEmpty || !mounted) return;
    final provider = context.read<FileProvider>();
    final ok = await provider.createFolder(name);
    if (!mounted) return;
    if (!ok) _toast(provider.error ?? 'Create folder failed');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  void _openFile(FileItem file) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => FileDetailScreen(fileId: file.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    final provider = context.watch<FileProvider>();

    if (keys.username == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Register an identity first to store encrypted files.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          _breadcrumbs(provider),
          if (provider.uploading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: provider.loading &&
                      provider.files.isEmpty &&
                      provider.folders.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _list(provider, keys.username!),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showFabMenu,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _breadcrumbs(FileProvider provider) {
    final items = <Widget>[
      _crumb('Home', () => provider.navigateToBreadcrumb(-1)),
    ];
    for (var i = 0; i < provider.breadcrumb.length; i++) {
      final folder = provider.breadcrumb[i];
      items.add(const Icon(Icons.chevron_right, size: 16));
      items.add(_crumb(folder.name, () => provider.navigateToBreadcrumb(i)));
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(children: items),
    );
  }

  Widget _crumb(String label, VoidCallback onTap) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
      ),
      child: Text(label),
    );
  }

  Widget _list(FileProvider provider, String me) {
    if (provider.folders.isEmpty && provider.files.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 120),
          Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No files here yet.', textAlign: TextAlign.center),
            ),
          ),
        ],
      );
    }
    final tiles = <Widget>[];
    for (final folder in provider.folders) {
      tiles.add(ListTile(
        leading: const Icon(Icons.folder, color: Colors.amber),
        title: Text(folder.name),
        subtitle: Text('Folder · ${formatRelativeTime(folder.createdAt)}'),
        onTap: () => provider.navigateToFolder(folder),
        onLongPress: () => _confirmDeleteFolder(folder),
      ));
    }
    for (final file in provider.files) {
      final mine = file.ownerUsername == me;
      tiles.add(ListTile(
        leading: Icon(_iconFor(file.filename)),
        title: Text(file.filename),
        subtitle: Text(
          '${_fmtSize(file.size)} · ${formatRelativeTime(file.createdAt)}'
          '${mine ? '' : ' · shared by @${file.ownerUsername}'}',
        ),
        trailing: file.isShared
            ? const Icon(Icons.group, size: 18, color: Colors.teal)
            : null,
        onTap: () => _openFile(file),
        onLongPress: () => _fileActions(file, mine),
      ));
    }
    return ListView.separated(
      itemCount: tiles.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) => tiles[i],
    );
  }

  Future<void> _confirmDeleteFolder(FolderItem folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "${folder.name}"?'),
        content: const Text('Folder must be empty.'),
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
    final success = await provider.deleteFolder(folder.id);
    if (!mounted) return;
    if (!success) _toast(provider.error ?? 'Delete failed');
  }

  Future<void> _fileActions(FileItem file, bool isMine) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Share'),
              enabled: isMine,
              onTap: () => Navigator.of(context).pop('share'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              enabled: isMine,
              onTap: () => Navigator.of(context).pop('delete'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'share') {
      _openFile(file);
    } else if (action == 'delete') {
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
      final success = await provider.deleteFile(file.id);
      if (!mounted) return;
      if (!success) _toast(provider.error ?? 'Delete failed');
    }
  }

  Future<void> _showFabMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (_) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Upload file'),
              onTap: () => Navigator.of(context).pop('upload'),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              onTap: () => Navigator.of(context).pop('folder'),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (choice == 'upload') {
      await _upload();
    } else if (choice == 'folder') {
      await _newFolder();
    }
  }

  static String _fmtSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static IconData _iconFor(String filename) {
    final ext = filename.split('.').last.toLowerCase();
    switch (ext) {
      case 'png':
      case 'jpg':
      case 'jpeg':
      case 'gif':
      case 'webp':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'txt':
      case 'md':
        return Icons.description_outlined;
      case 'zip':
      case 'tar':
      case 'gz':
        return Icons.archive_outlined;
      case 'mp3':
      case 'wav':
      case 'flac':
        return Icons.audiotrack_outlined;
      case 'mp4':
      case 'mov':
      case 'mkv':
        return Icons.movie_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}

class _NewFolderDialog extends StatefulWidget {
  const _NewFolderDialog();

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New folder'),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_ctrl.text.trim()),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
