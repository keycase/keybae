import 'package:flutter/material.dart';

import '../services/ws_service.dart';

class ConnectionIndicator extends StatelessWidget {
  final WsService ws;
  const ConnectionIndicator({super.key, required this.ws});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectionStatus>(
      valueListenable: ws.status,
      builder: (context, status, _) {
        final color = _colorFor(status);
        final label = _labelFor(status);
        return IconButton(
          tooltip: label,
          onPressed: () => _showDetails(context, status),
          icon: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.cloud_outlined,
                  color: Theme.of(context).iconTheme.color),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDetails(BuildContext context, ConnectionStatus status) {
    final label = _labelFor(status);
    final detail = _detailFor(status);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(label),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Color _colorFor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.reconnecting:
      case ConnectionStatus.connecting:
        return Colors.amber;
      case ConnectionStatus.disconnected:
        return Colors.red;
    }
  }

  static String _labelFor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return 'Connected';
      case ConnectionStatus.connecting:
        return 'Connecting…';
      case ConnectionStatus.reconnecting:
        return 'Reconnecting…';
      case ConnectionStatus.disconnected:
        return 'Offline';
    }
  }

  static String _detailFor(ConnectionStatus s) {
    switch (s) {
      case ConnectionStatus.connected:
        return 'Live updates are active.';
      case ConnectionStatus.connecting:
        return 'Establishing a secure connection to the server.';
      case ConnectionStatus.reconnecting:
        return 'Lost connection — retrying with exponential backoff.';
      case ConnectionStatus.disconnected:
        return 'Not connected. Register an identity or check your network.';
    }
  }
}
