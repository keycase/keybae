import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:provider/provider.dart';

import '../state/settings_provider.dart';
import 'profile_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;
  List<Identity> _results = const [];
  bool _loading = false;
  String? _error;
  String _lastQuery = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(value));
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _results = const [];
        _loading = false;
        _error = null;
        _lastQuery = '';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _lastQuery = q;
    });
    try {
      final client = context.read<SettingsProvider>().client;
      final results = await client.searchIdentities(q);
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _searchCtrl,
            autocorrect: false,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Search usernames…',
              border: const OutlineInputBorder(),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        _onChanged('');
                      },
                    ),
            ),
            onChanged: (v) {
              setState(() {});
              _onChanged(v);
            },
            onSubmitted: _search,
          ),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_lastQuery.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Find other KeyCase users by username prefix.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No identities matching “$_lastQuery”.'),
        ),
      );
    }
    return ListView.builder(
      itemCount: _results.length,
      itemBuilder: (context, i) {
        final id = _results[i];
        return ListTile(
          leading: CircleAvatar(child: Text(id.username[0].toUpperCase())),
          title: Text(id.username),
          subtitle: Text(
            '${id.proofIds.length} proof${id.proofIds.length == 1 ? '' : 's'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => ProfileScreen(identity: id)),
          ),
        );
      },
    );
  }
}
