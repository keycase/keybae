import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:provider/provider.dart';

import '../models/team.dart';
import '../providers/team_provider.dart';
import '../services/event_handler.dart';
import '../state/key_provider.dart';
import '../state/settings_provider.dart';
import '../widgets/friendly_error.dart';
import '../widgets/presence_dot.dart';
import '../widgets/relative_time.dart';

enum _TeamView { chat, members }

class TeamScreen extends StatefulWidget {
  final String teamId;
  const TeamScreen({super.key, required this.teamId});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  _TeamView _view = _TeamView.chat;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<TeamProvider>();
      p.loadTeamDetails(widget.teamId);
      p.loadTeamMessages(widget.teamId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeamProvider>();
    final team = provider.activeTeam;
    return Scaffold(
      appBar: AppBar(
        title: Text(team?.displayName ?? 'Team'),
        actions: [
          if (provider.isOwner && team != null)
            PopupMenuButton<String>(
              onSelected: (v) async {
                if (v != 'delete') return;
                final provider = context.read<TeamProvider>();
                final navigator = Navigator.of(context);
                final ok = await _confirmDelete(context);
                if (ok != true || !mounted) return;
                final success = await provider.deleteTeam(team.id);
                if (success && mounted) navigator.pop();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('Delete team')),
              ],
            ),
        ],
      ),
      body: team == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Text(team.displayName.isEmpty
                            ? '?'
                            : team.displayName[0].toUpperCase()),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.displayName,
                                style: Theme.of(context).textTheme.titleMedium),
                            Text(
                                '@${team.name} · ${team.memberCount} member${team.memberCount == 1 ? '' : 's'}',
                                style:
                                    Theme.of(context).textTheme.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SegmentedButton<_TeamView>(
                    segments: const [
                      ButtonSegment(
                          value: _TeamView.chat,
                          label: Text('Chat'),
                          icon: Icon(Icons.chat_bubble_outline)),
                      ButtonSegment(
                          value: _TeamView.members,
                          label: Text('Members'),
                          icon: Icon(Icons.group_outlined)),
                    ],
                    selected: {_view},
                    onSelectionChanged: (s) =>
                        setState(() => _view = s.first),
                  ),
                ),
                Expanded(
                  child: _view == _TeamView.chat
                      ? _ChatView(teamId: team.id)
                      : _MembersView(team: team),
                ),
              ],
            ),
    );
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete team?'),
        content: const Text('This cannot be undone.'),
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
  }
}

class _ChatView extends StatefulWidget {
  final String teamId;
  const _ChatView({required this.teamId});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loadingOlder = false;
  int _lastMessageCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventHandler>().activeTeamId = widget.teamId;
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    final handler = context.read<EventHandler>();
    if (handler.activeTeamId == widget.teamId) {
      handler.activeTeamId = null;
    }
    _inputCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _maybeAutoScroll(int newCount) {
    if (newCount <= _lastMessageCount) {
      _lastMessageCount = newCount;
      return;
    }
    _lastMessageCount = newCount;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (_scrollCtrl.position.pixels < 120) {
        _scrollCtrl.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
            _scrollCtrl.position.maxScrollExtent - 40 &&
        !_loadingOlder) {
      _loadOlder();
    }
  }

  Future<void> _loadOlder() async {
    setState(() => _loadingOlder = true);
    final p = context.read<TeamProvider>();
    await p.loadTeamMessages(
      widget.teamId,
      offset: p.messages.length,
      append: true,
    );
    if (mounted) setState(() => _loadingOlder = false);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final ok =
        await context.read<TeamProvider>().sendTeamMessage(widget.teamId, text);
    if (!mounted) return;
    if (!ok) {
      final err = context.read<TeamProvider>().error ?? 'send failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeamProvider>();
    final me = context.watch<KeyProvider>().username;
    final messages = provider.messages;
    _maybeAutoScroll(messages.length);
    return Column(
      children: [
        if (provider.loadingMessages && messages.isEmpty)
          const LinearProgressIndicator(minHeight: 2),
        Expanded(
          child: messages.isEmpty && !provider.loadingMessages
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No messages yet.'),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + (_loadingOlder ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (_loadingOlder && i == messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(12),
                        child: Center(
                            child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )),
                      );
                    }
                    final dm = messages[messages.length - 1 - i];
                    final isMine = dm.message.senderUsername == me;
                    return _bubble(context, dm, isMine);
                  },
                ),
        ),
        _composer(provider.sending),
      ],
    );
  }

  Widget _bubble(BuildContext context, DecryptedTeamMessage dm, bool isMine) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isMine ? Colors.teal : scheme.surfaceContainerHighest;
    final fg = isMine ? Colors.white : scheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Column(
        crossAxisAlignment:
            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, right: 4, top: 4),
            child: Text(
              '@${dm.message.senderUsername}',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(14),
                topRight: const Radius.circular(14),
                bottomLeft: Radius.circular(isMine ? 14 : 2),
                bottomRight: Radius.circular(isMine ? 2 : 14),
              ),
            ),
            child: Column(
              crossAxisAlignment: isMine
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(dm.previewText, style: TextStyle(color: fg)),
                const SizedBox(height: 2),
                Text(
                  formatRelativeTime(dm.message.createdAt),
                  style: TextStyle(
                      color: fg.withValues(alpha: 0.7), fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _composer(bool sending) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _inputCtrl,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: const InputDecoration(
                  hintText: 'Message team…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            sending
                ? const SizedBox(
                    width: 40,
                    height: 40,
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
          ],
        ),
      ),
    );
  }
}

class _MembersView extends StatelessWidget {
  final Team team;
  const _MembersView({required this.team});

  Color _roleColor(String role, ColorScheme scheme) {
    switch (role) {
      case 'owner':
        return Colors.deepPurple;
      case 'admin':
        return Colors.teal;
      default:
        return scheme.surfaceContainerHighest;
    }
  }

  Future<void> _addMember(BuildContext context) async {
    final provider = context.read<TeamProvider>();
    await showDialog<void>(
      context: context,
      builder: (_) => _AddMemberDialog(teamId: team.id, provider: provider),
    );
  }

  Future<void> _changeRole(
      BuildContext context, TeamMember member) async {
    final role = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: Text('Role for @${member.username}'),
        children: [
          for (final r in const ['owner', 'admin', 'member'])
            SimpleDialogOption(
              onPressed: () => Navigator.of(context).pop(r),
              child: Text(r),
            ),
        ],
      ),
    );
    if (role == null || role == member.role) return;
    if (!context.mounted) return;
    await context.read<TeamProvider>().updateRole(team.id, member.username, role);
  }

  Future<void> _remove(BuildContext context, TeamMember member) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove @${member.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await context.read<TeamProvider>().removeMember(team.id, member.username);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TeamProvider>();
    final me = context.watch<KeyProvider>().username;
    final canManage = provider.canManageMembers;
    return Stack(
      children: [
        ListView.separated(
          itemCount: team.members.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final m = team.members[i];
            return ListTile(
              leading: Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(child: Text(m.username[0].toUpperCase())),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: PresenceDot(username: m.username),
                  ),
                ],
              ),
              title: Text('@${m.username}${m.username == me ? ' (you)' : ''}'),
              subtitle: Text('joined ${formatRelativeTime(m.joinedAt)}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roleColor(
                          m.role, Theme.of(context).colorScheme),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      m.role,
                      style: TextStyle(
                        color: m.role == 'member'
                            ? Theme.of(context).colorScheme.onSurface
                            : Colors.white,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  if (canManage && m.username != me)
                    PopupMenuButton<String>(
                      onSelected: (v) {
                        if (v == 'role') _changeRole(context, m);
                        if (v == 'remove') _remove(context, m);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                            value: 'role', child: Text('Change role')),
                        PopupMenuItem(
                            value: 'remove', child: Text('Remove')),
                      ],
                    ),
                ],
              ),
            );
          },
        ),
        if (canManage)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              heroTag: 'add-member-${team.id}',
              onPressed: () => _addMember(context),
              icon: const Icon(Icons.person_add),
              label: const Text('Add'),
            ),
          ),
      ],
    );
  }
}

class _AddMemberDialog extends StatefulWidget {
  final String teamId;
  final TeamProvider provider;
  const _AddMemberDialog({required this.teamId, required this.provider});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Identity> _results = const [];
  bool _loading = false;
  bool _saving = false;
  String _role = 'member';
  String? _selected;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  Future<void> _submit() async {
    final username = _selected ?? _searchCtrl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'pick a user');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final ok =
        await widget.provider.addMember(widget.teamId, username, _role);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _saving = false;
        _error = widget.provider.error ?? 'add failed';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add member'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchCtrl,
              autocorrect: false,
              autofocus: true,
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
                height: 150,
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
                            _searchCtrl.text = id.username;
                          });
                        },
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'member', child: Text('member')),
                DropdownMenuItem(value: 'admin', child: Text('admin')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'member'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style:
                      TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
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
              : const Text('Add'),
        ),
      ],
    );
  }
}
