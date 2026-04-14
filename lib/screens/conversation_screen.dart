import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/message.dart';
import '../state/key_provider.dart';
import '../state/message_provider.dart';
import '../widgets/relative_time.dart';

class ConversationScreen extends StatefulWidget {
  final String username;
  const ConversationScreen({super.key, required this.username});

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final _inputCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _loadingOlder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MessageProvider>().loadConversation(widget.username);
    });
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
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
    await context.read<MessageProvider>().loadOlder(widget.username);
    if (mounted) setState(() => _loadingOlder = false);
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;
    _inputCtrl.clear();
    final ok = await context
        .read<MessageProvider>()
        .sendMessage(widget.username, text);
    if (!mounted) return;
    if (!ok) {
      final err = context.read<MessageProvider>().error ?? 'send failed';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MessageProvider>();
    final me = context.watch<KeyProvider>().username;
    final messages = provider.conversation;
    return Scaffold(
      appBar: AppBar(title: Text('@${widget.username}')),
      body: Column(
        children: [
          if (provider.loadingConversation && messages.isEmpty)
            const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: messages.isEmpty && !provider.loadingConversation
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No messages yet. Say hello.'),
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
      ),
    );
  }

  Widget _bubble(BuildContext context, DecryptedMessage dm, bool isMine) {
    final scheme = Theme.of(context).colorScheme;
    final bg = isMine ? Colors.teal : scheme.surfaceContainerHighest;
    final fg = isMine ? Colors.white : scheme.onSurface;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
          crossAxisAlignment:
              isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              dm.previewText,
              style: TextStyle(color: fg),
            ),
            const SizedBox(height: 2),
            Text(
              formatRelativeTime(dm.message.createdAt),
              style: TextStyle(
                color: fg.withValues(alpha: 0.7),
                fontSize: 10,
              ),
            ),
          ],
        ),
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
                  hintText: 'Message…',
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
