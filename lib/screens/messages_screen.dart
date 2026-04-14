import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/key_provider.dart';
import '../state/message_provider.dart';
import '../widgets/presence_dot.dart';
import '../widgets/relative_time.dart';
import 'compose_screen.dart';
import 'conversation_screen.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<KeyProvider>().username != null) {
        context.read<MessageProvider>().loadInbox();
      }
    });
  }

  Future<void> _refresh() async {
    await context.read<MessageProvider>().loadInbox();
  }

  void _openCompose() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ComposeScreen()),
    );
  }

  void _openConversation(String username) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ConversationScreen(username: username),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final keys = context.watch<KeyProvider>();
    final provider = context.watch<MessageProvider>();

    if (keys.username == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Register an identity first to send and receive messages.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final conversations = provider.conversations;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: provider.loadingInbox && conversations.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : (conversations.isEmpty
                ? ListView(
                    children: const [
                      SizedBox(height: 120),
                      Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No messages yet. Start a conversation from the search.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  )
                : ListView.separated(
                    itemCount: conversations.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = conversations[i];
                      final preview = c.lastMessage.previewText;
                      final isMine =
                          c.lastMessage.message.senderUsername == keys.username;
                      return ListTile(
                        leading: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              child: Text(c.username[0].toUpperCase()),
                            ),
                            Positioned(
                              right: -1,
                              bottom: -1,
                              child: PresenceDot(username: c.username),
                            ),
                          ],
                        ),
                        title: Text(c.username),
                        subtitle: Text(
                          (isMine ? 'You: ' : '') + preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatRelativeTime(c.lastMessage.message.createdAt),
                              style: const TextStyle(fontSize: 11),
                            ),
                            const SizedBox(height: 4),
                            if (c.unreadCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: const BoxDecoration(
                                  color: Colors.teal,
                                  shape: BoxShape.rectangle,
                                  borderRadius:
                                      BorderRadius.all(Radius.circular(10)),
                                ),
                                child: Text(
                                  '${c.unreadCount}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        onTap: () => _openConversation(c.username),
                      );
                    },
                  )),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCompose,
        child: const Icon(Icons.edit),
      ),
    );
  }
}
