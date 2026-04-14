import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/team_provider.dart';
import '../state/key_provider.dart';
import 'team_screen.dart';

class TeamsScreen extends StatefulWidget {
  const TeamsScreen({super.key});

  @override
  State<TeamsScreen> createState() => _TeamsScreenState();
}

class _TeamsScreenState extends State<TeamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<KeyProvider>().username != null) {
        context.read<TeamProvider>().loadTeams();
      }
    });
  }

  Future<void> _refresh() => context.read<TeamProvider>().loadTeams();

  Future<void> _openCreate() async {
    await showDialog<void>(
      context: context,
      builder: (_) => const _CreateTeamDialog(),
    );
  }

  void _openTeam(String teamId) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TeamScreen(teamId: teamId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    final provider = context.watch<TeamProvider>();

    if (keys.username == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Register an identity first to create or join teams.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.loadingTeams && provider.teams.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : (provider.teams.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No teams yet. Create one with the + button.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: provider.teams.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final t = provider.teams[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(t.displayName.isEmpty
                              ? '?'
                              : t.displayName[0].toUpperCase()),
                        ),
                        title: Text(t.displayName),
                        subtitle: Text(
                          '@${t.name} · ${t.memberCount} member${t.memberCount == 1 ? '' : 's'}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openTeam(t.id),
                      );
                    },
                  )),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreate,
        child: const Icon(Icons.group_add),
      ),
    );
  }
}

class _CreateTeamDialog extends StatefulWidget {
  const _CreateTeamDialog();

  @override
  State<_CreateTeamDialog> createState() => _CreateTeamDialogState();
}

class _CreateTeamDialogState extends State<_CreateTeamDialog> {
  final _nameCtrl = TextEditingController();
  final _displayCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _displayCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameCtrl.text.trim();
    final display = _displayCtrl.text.trim();
    if (name.isEmpty || display.isEmpty) {
      setState(() => _error = 'Both fields are required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final team =
        await context.read<TeamProvider>().createTeam(name, display);
    if (!mounted) return;
    if (team != null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = context.read<TeamProvider>().error ?? 'create failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create team'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Slug',
              hintText: 'acme',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _displayCtrl,
            decoration: const InputDecoration(
              labelText: 'Display name',
              hintText: 'Acme Corp',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
