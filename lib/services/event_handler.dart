import 'dart:async';

import 'package:flutter/material.dart';

import '../models/file_item.dart';
import '../models/message.dart';
import '../models/team.dart';
import '../providers/file_provider.dart';
import '../providers/team_provider.dart';
import '../state/identity_provider.dart';
import '../state/message_provider.dart';
import '../state/proof_provider.dart';
import 'ws_service.dart';

/// Routes decoded WebSocket events to the appropriate providers and
/// surfaces background notifications via the global [ScaffoldMessenger].
class EventHandler {
  final WsService ws;
  final MessageProvider messages;
  final TeamProvider teams;
  final FileProvider files;
  final IdentityProvider identities;
  final ProofProvider proofs;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  StreamSubscription<Map<String, dynamic>>? _sub;

  /// Username currently being viewed in the conversation screen.
  /// Used to suppress "new message" snackbars for the open chat.
  String? activeConversation;

  /// Team id currently being viewed.
  String? activeTeamId;

  EventHandler({
    required this.ws,
    required this.messages,
    required this.teams,
    required this.files,
    required this.identities,
    required this.proofs,
    required this.messengerKey,
  });

  void start() {
    _sub ??= ws.events.listen(_dispatch);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }

  Future<void> _dispatch(Map<String, dynamic> event) async {
    final type = event['type'] as String?;
    final data = event['data'];
    if (type == null || data is! Map<String, dynamic>) return;
    try {
      switch (type) {
        case 'message':
          await _onMessage(data);
          break;
        case 'team_message':
          await _onTeamMessage(data);
          break;
        case 'team_invite':
          _onTeamInvite(data);
          break;
        case 'file_shared':
          _onFileShared(data);
          break;
        case 'proof_verified':
          _onProofVerified(data);
          break;
      }
    } catch (_) {
      // Never let a malformed event crash the stream subscription.
    }
  }

  Future<void> _onMessage(Map<String, dynamic> data) async {
    final msg = Message.fromJson(data);
    final dm = await messages.onIncomingMessage(msg);
    final isOpen = activeConversation == msg.senderUsername;
    if (!isOpen) {
      _snack('New message from @${msg.senderUsername}'
          '${dm.plaintext != null ? ': ${_preview(dm.plaintext!)}' : ''}');
    }
  }

  Future<void> _onTeamMessage(Map<String, dynamic> data) async {
    final msg = TeamMessage.fromJson(data);
    final dm = await teams.onIncomingTeamMessage(msg);
    final isOpen = activeTeamId == msg.teamId;
    if (!isOpen) {
      _snack('New team message from @${msg.senderUsername}'
          '${dm.plaintext != null ? ': ${_preview(dm.plaintext!)}' : ''}');
    }
  }

  void _onTeamInvite(Map<String, dynamic> data) {
    final team = Team.fromJson(data);
    teams.onTeamInvite(team);
    _snack('You were added to team ${team.displayName}');
  }

  void _onFileShared(Map<String, dynamic> data) {
    final file = FileItem.fromJson(data);
    files.onFileShared(file);
    _snack('@${file.ownerUsername} shared "${file.filename}" with you');
  }

  void _onProofVerified(Map<String, dynamic> data) {
    // ignore: discarded_futures
    identities.refresh();
    // ignore: discarded_futures
    proofs.refresh();
    final target = data['target'] as String? ?? 'proof';
    final status = data['status'] as String? ?? 'updated';
    _snack('Proof $target: $status');
  }

  String _preview(String text) =>
      text.length > 60 ? '${text.substring(0, 60)}…' : text;

  void _snack(String message) {
    final state = messengerKey.currentState;
    if (state == null) return;
    state.showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }
}
