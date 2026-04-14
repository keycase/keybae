import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart' as core;
import 'package:web_socket_channel/web_socket_channel.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting }

/// Manages a single authenticated WebSocket connection to the KeyCase
/// server. Exposes decoded events as a broadcast stream and connection
/// state as a [ValueNotifier] for UI binding.
class WsService {
  WsService();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final StreamController<Map<String, dynamic>> _events =
      StreamController.broadcast();
  final ValueNotifier<ConnectionStatus> status =
      ValueNotifier(ConnectionStatus.disconnected);

  String? _baseUrl;
  String? _username;
  String? _privateKey;
  int _attempt = 0;
  Timer? _reconnectTimer;
  bool _manualClose = false;

  Stream<Map<String, dynamic>> get events => _events.stream;

  bool get isConnected => status.value == ConnectionStatus.connected;

  /// Connect or reconnect with a fresh auth frame.
  Future<void> connect({
    required String serverUrl,
    required String username,
    required String privateKey,
  }) async {
    _baseUrl = serverUrl;
    _username = username;
    _privateKey = privateKey;
    _manualClose = false;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    if (_baseUrl == null || _username == null || _privateKey == null) return;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();

    status.value = _attempt == 0
        ? ConnectionStatus.connecting
        : ConnectionStatus.reconnecting;

    final wsUrl = _toWsUrl(_baseUrl!);
    try {
      final channel = WebSocketChannel.connect(Uri.parse('$wsUrl/api/v1/ws'));
      _channel = channel;

      final timestamp = DateTime.now().toUtc().toIso8601String();
      final signature = await core.sign(timestamp, _privateKey!);
      channel.sink.add(jsonEncode({
        'type': 'auth',
        'username': _username,
        'timestamp': timestamp,
        'signature': signature,
      }));

      _sub = channel.stream.listen(
        _onMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final decoded = jsonDecode(raw as String);
      if (decoded is! Map<String, dynamic>) return;
      final type = decoded['type'] as String?;
      if (type == 'ping') {
        _channel?.sink.add(jsonEncode({'type': 'pong'}));
        return;
      }
      if (type == 'auth_ok') {
        _attempt = 0;
        status.value = ConnectionStatus.connected;
        return;
      }
      if (type == 'auth_error') {
        _manualClose = true;
        status.value = ConnectionStatus.disconnected;
        _channel?.sink.close();
        return;
      }
      _events.add(decoded);
    } catch (_) {
      // Ignore malformed frames.
    }
  }

  void _scheduleReconnect() {
    if (_manualClose) {
      status.value = ConnectionStatus.disconnected;
      return;
    }
    status.value = ConnectionStatus.reconnecting;
    final delay = _backoff(_attempt);
    _attempt += 1;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, _openSocket);
  }

  Duration _backoff(int attempt) {
    final seconds = [1, 2, 4, 8, 16, 30];
    final idx = attempt.clamp(0, seconds.length - 1);
    return Duration(seconds: seconds[idx]);
  }

  String _toWsUrl(String httpUrl) {
    if (httpUrl.startsWith('https://')) {
      return 'wss://${httpUrl.substring('https://'.length)}';
    }
    if (httpUrl.startsWith('http://')) {
      return 'ws://${httpUrl.substring('http://'.length)}';
    }
    return httpUrl;
  }

  Future<void> disconnect() async {
    _manualClose = true;
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _channel?.sink.close();
    _sub = null;
    _channel = null;
    _attempt = 0;
    status.value = ConnectionStatus.disconnected;
  }

  Future<void> dispose() async {
    await disconnect();
    await _events.close();
    status.dispose();
  }
}
