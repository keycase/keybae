import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/presence_provider.dart';

class PresenceDot extends StatefulWidget {
  final String username;
  final double size;
  const PresenceDot({super.key, required this.username, this.size = 10});

  @override
  State<PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<PresenceDot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PresenceProvider>().checkPresence([widget.username]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<PresenceProvider>().online(widget.username);
    Color color;
    if (online == null) {
      color = Colors.grey.shade400;
    } else if (online) {
      color = Colors.green;
    } else {
      color = Colors.grey;
    }
    return Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).scaffoldBackgroundColor,
          width: 1.5,
        ),
      ),
    );
  }
}
