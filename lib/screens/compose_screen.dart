import 'dart:async';

import 'package:flutter/material.dart';
import 'package:keycase_core/keycase_core.dart';
import 'package:provider/provider.dart';

import '../state/settings_provider.dart';
import '../widgets/friendly_error.dart';
import 'conversation_screen.dart';

class ComposeScreen extends StatefulWidget {
  const ComposeScreen({super.key});

  @override
  State<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends State<ComposeScreen> {
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
      final r = await client.searchIdentities(q);
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _results = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || q != _lastQuery) return;
      setState(() {
        _error = friendlyError(e);
        _loading = false;
      });
    }
  }

  void _open(Identity id) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(username: id.username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New message')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              autocorrect: false,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search users…',
                border: OutlineInputBorder(),
              ),
              onChanged: _onChanged,
              onSubmitted: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _error != null
                ? Center(child: Text(_error!))
                : (_lastQuery.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Search for a user to start a chat.'),
                        ),
                      )
                    : (_results.isEmpty && !_loading
                        ? Center(child: Text('No users matching "$_lastQuery"'))
                        : ListView.builder(
                            itemCount: _results.length,
                            itemBuilder: (context, i) {
                              final id = _results[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(id.username[0].toUpperCase()),
                                ),
                                title: Text(id.username),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => _open(id),
                              );
                            },
                          ))),
          ),
        ],
      ),
    );
  }
}
