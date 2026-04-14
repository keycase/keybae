import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart';

import '../models/message.dart';
import '../services/keycase_client.dart';
import '../services/message_crypto.dart';
import '../widgets/friendly_error.dart';
import 'key_provider.dart';

/// A conversation summary derived from the inbox.
class ConversationSummary {
  final String username;
  final DecryptedMessage lastMessage;
  final int unreadCount;

  const ConversationSummary({
    required this.username,
    required this.lastMessage,
    required this.unreadCount,
  });
}

class MessageProvider extends ChangeNotifier {
  final KeyProvider _keys;
  final MessageCrypto _crypto;
  KeyCaseClient _client;

  final Map<String, Identity> _identityCache = {};
  List<DecryptedMessage> _inbox = const [];
  List<DecryptedMessage> _conversation = const [];
  String? _activeConversation;
  bool _loadingInbox = false;
  bool _loadingConversation = false;
  bool _sending = false;
  String? _error;

  MessageProvider({
    required KeyProvider keys,
    required KeyCaseClient client,
    MessageCrypto? crypto,
  })  : _keys = keys,
        _client = client,
        _crypto = crypto ?? MessageCrypto() {
    _keys.addListener(_onKeysChanged);
  }

  void updateClient(KeyCaseClient client) {
    _client = client;
  }

  List<DecryptedMessage> get inbox => _inbox;
  List<DecryptedMessage> get conversation => _conversation;
  String? get activeConversation => _activeConversation;
  bool get loadingInbox => _loadingInbox;
  bool get loadingConversation => _loadingConversation;
  bool get sending => _sending;
  String? get error => _error;

  int get unreadCount =>
      _inbox.where((m) => !m.message.read && _isIncoming(m.message)).length;

  List<ConversationSummary> get conversations {
    final me = _keys.username;
    final Map<String, List<DecryptedMessage>> groups = {};
    for (final dm in _inbox) {
      final other = dm.message.senderUsername == me
          ? dm.message.recipientUsername
          : dm.message.senderUsername;
      groups.putIfAbsent(other, () => []).add(dm);
    }
    final summaries = <ConversationSummary>[];
    for (final entry in groups.entries) {
      entry.value.sort(
        (a, b) => b.message.createdAt.compareTo(a.message.createdAt),
      );
      final unread = entry.value
          .where((m) => !m.message.read && _isIncoming(m.message))
          .length;
      summaries.add(ConversationSummary(
        username: entry.key,
        lastMessage: entry.value.first,
        unreadCount: unread,
      ));
    }
    summaries.sort((a, b) => b.lastMessage.message.createdAt
        .compareTo(a.lastMessage.message.createdAt));
    return summaries;
  }

  bool _isIncoming(Message m) => m.recipientUsername == _keys.username;

  void _onKeysChanged() {
    if (_keys.username == null) {
      _inbox = const [];
      _conversation = const [];
      _activeConversation = null;
      _identityCache.clear();
      notifyListeners();
    }
  }

  ClientCredentials? _creds() {
    final kp = _keys.keyPair;
    final username = _keys.username;
    if (kp == null || kp.privateKey == null || username == null) return null;
    return ClientCredentials(username: username, privateKey: kp.privateKey!);
  }

  Future<Identity?> _lookupIdentity(String username) async {
    final cached = _identityCache[username];
    if (cached != null) return cached;
    final id = await _client.lookupIdentity(username);
    if (id != null) _identityCache[username] = id;
    return id;
  }

  Future<DecryptedMessage> _decrypt(Message m) async {
    final kp = _keys.keyPair;
    final me = _keys.username;
    if (kp == null || kp.privateKey == null || me == null) {
      return DecryptedMessage(message: m, error: 'no key');
    }
    final otherUsername =
        m.senderUsername == me ? m.recipientUsername : m.senderUsername;
    try {
      final other = await _lookupIdentity(otherUsername);
      if (other == null) {
        return DecryptedMessage(message: m, error: 'identity not found');
      }
      // Shared secret is symmetric, so we use the counterparty's public key
      // and our own private key regardless of direction.
      final plaintext = await _crypto.decryptMessage(
        m.encryptedBody,
        m.nonce,
        other.publicKey,
        kp.privateKey!,
      );
      return DecryptedMessage(message: m, plaintext: plaintext);
    } catch (e) {
      return DecryptedMessage(message: m, error: e.toString());
    }
  }

  /// Inject a server-pushed message into the inbox and (if it belongs to
  /// the active conversation) into the conversation view. Returns the
  /// decrypted message so the caller can decide whether to notify.
  Future<DecryptedMessage> onIncomingMessage(Message m) async {
    final dm = await _decrypt(m);
    if (!_inbox.any((e) => e.message.id == m.id)) {
      _inbox = [dm, ..._inbox];
    }
    final me = _keys.username;
    final otherUsername =
        m.senderUsername == me ? m.recipientUsername : m.senderUsername;
    if (_activeConversation == otherUsername &&
        !_conversation.any((e) => e.message.id == m.id)) {
      _conversation = [..._conversation, dm];
      if (_isIncoming(m) && !m.read) {
        // ignore: discarded_futures
        markAsReadMessage(m.id);
      }
    }
    notifyListeners();
    return dm;
  }

  Future<void> loadInbox() async {
    final creds = _creds();
    if (creds == null) return;
    _loadingInbox = true;
    _error = null;
    notifyListeners();
    try {
      final messages = await _client.getInbox(creds: creds);
      final decrypted = <DecryptedMessage>[];
      for (final m in messages) {
        decrypted.add(await _decrypt(m));
      }
      _inbox = decrypted;
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loadingInbox = false;
      notifyListeners();
    }
  }

  Future<void> loadConversation(String username, {bool markAsRead = true}) async {
    final creds = _creds();
    if (creds == null) return;
    _activeConversation = username;
    _loadingConversation = true;
    _error = null;
    notifyListeners();
    try {
      final messages = await _client.getConversation(
        creds: creds,
        username: username,
      );
      final decrypted = <DecryptedMessage>[];
      for (final m in messages) {
        decrypted.add(await _decrypt(m));
      }
      decrypted.sort((a, b) =>
          a.message.createdAt.compareTo(b.message.createdAt));
      _conversation = decrypted;
      if (markAsRead) {
        for (final dm in decrypted) {
          if (!dm.message.read && _isIncoming(dm.message)) {
            // ignore: discarded_futures
            markAsReadMessage(dm.message.id);
          }
        }
      }
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loadingConversation = false;
      notifyListeners();
    }
  }

  Future<void> loadOlder(String username) async {
    final creds = _creds();
    if (creds == null) return;
    try {
      final older = await _client.getConversation(
        creds: creds,
        username: username,
        offset: _conversation.length,
      );
      if (older.isEmpty) return;
      final decrypted = <DecryptedMessage>[];
      for (final m in older) {
        decrypted.add(await _decrypt(m));
      }
      final merged = [...decrypted, ..._conversation];
      merged.sort((a, b) =>
          a.message.createdAt.compareTo(b.message.createdAt));
      _conversation = merged;
      notifyListeners();
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
    }
  }

  Future<bool> sendMessage(String recipientUsername, String plaintext) async {
    final creds = _creds();
    final kp = _keys.keyPair;
    if (creds == null || kp == null || kp.privateKey == null) return false;
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      final recipient = await _lookupIdentity(recipientUsername);
      if (recipient == null) {
        _error = 'recipient not found';
        return false;
      }
      final payload = await _crypto.encryptMessage(
        plaintext,
        recipient.publicKey,
        kp.privateKey!,
      );
      final message = await _client.sendMessage(
        creds: creds,
        recipientUsername: recipientUsername,
        encryptedBody: payload.encryptedBody,
        nonce: payload.nonce,
      );
      final dm = DecryptedMessage(message: message, plaintext: plaintext);
      if (_activeConversation == recipientUsername) {
        _conversation = [..._conversation, dm];
      }
      _inbox = [dm, ..._inbox];
      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  Future<void> markAsReadMessage(String messageId) async {
    final creds = _creds();
    if (creds == null) return;
    try {
      await _client.markRead(creds: creds, messageId: messageId);
      _inbox = [
        for (final dm in _inbox)
          dm.message.id == messageId
              ? DecryptedMessage(
                  message: dm.message.copyWith(read: true),
                  plaintext: dm.plaintext,
                  error: dm.error,
                )
              : dm,
      ];
      _conversation = [
        for (final dm in _conversation)
          dm.message.id == messageId
              ? DecryptedMessage(
                  message: dm.message.copyWith(read: true),
                  plaintext: dm.plaintext,
                  error: dm.error,
                )
              : dm,
      ];
      notifyListeners();
    } catch (_) {
      // swallow — best-effort
    }
  }

  void clearActiveConversation() {
    _activeConversation = null;
    _conversation = const [];
    notifyListeners();
  }

  @override
  void dispose() {
    _keys.removeListener(_onKeysChanged);
    super.dispose();
  }
}
