import 'package:flutter/foundation.dart';
import 'package:keycase_core/keycase_core.dart' show Identity;

import '../models/team.dart';
import '../services/keycase_client.dart';
import '../services/message_crypto.dart';
import '../state/key_provider.dart';
import '../widgets/friendly_error.dart';

class TeamProvider extends ChangeNotifier {
  final KeyProvider _keys;
  final MessageCrypto _crypto;
  KeyCaseClient _client;

  List<Team> _teams = const [];
  Team? _activeTeam;
  List<DecryptedTeamMessage> _messages = const [];
  final Map<String, Identity> _identityCache = {};

  bool _loadingTeams = false;
  bool _loadingTeam = false;
  bool _loadingMessages = false;
  bool _sending = false;
  String? _error;

  TeamProvider({
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

  List<Team> get teams => _teams;
  Team? get activeTeam => _activeTeam;
  List<DecryptedTeamMessage> get messages => _messages;
  bool get loadingTeams => _loadingTeams;
  bool get loadingTeam => _loadingTeam;
  bool get loadingMessages => _loadingMessages;
  bool get sending => _sending;
  String? get error => _error;

  String? get myRoleInActiveTeam {
    final me = _keys.username;
    if (_activeTeam == null || me == null) return null;
    for (final m in _activeTeam!.members) {
      if (m.username == me) return m.role;
    }
    return null;
  }

  bool get canManageMembers {
    final role = myRoleInActiveTeam;
    return role == 'owner' || role == 'admin';
  }

  bool get isOwner => myRoleInActiveTeam == 'owner';

  void _onKeysChanged() {
    if (_keys.username == null) {
      _teams = const [];
      _activeTeam = null;
      _messages = const [];
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

  Future<void> loadTeams() async {
    final creds = _creds();
    if (creds == null) return;
    _loadingTeams = true;
    _error = null;
    notifyListeners();
    try {
      _teams = await _client.getMyTeams(creds: creds);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loadingTeams = false;
      notifyListeners();
    }
  }

  Future<Team?> createTeam(String name, String displayName) async {
    final creds = _creds();
    if (creds == null) return null;
    try {
      final team = await _client.createTeam(
        creds: creds,
        name: name,
        displayName: displayName,
      );
      _teams = [..._teams, team];
      _error = null;
      notifyListeners();
      return team;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return null;
    }
  }

  Future<void> loadTeamDetails(String teamId) async {
    final creds = _creds();
    if (creds == null) return;
    _loadingTeam = true;
    _error = null;
    notifyListeners();
    try {
      _activeTeam = await _client.getTeam(creds: creds, teamId: teamId);
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loadingTeam = false;
      notifyListeners();
    }
  }

  Future<bool> addMember(String teamId, String username, String role) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      _activeTeam = await _client.addTeamMember(
        creds: creds,
        teamId: teamId,
        username: username,
        role: role,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeMember(String teamId, String username) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      await _client.removeTeamMember(
        creds: creds,
        teamId: teamId,
        username: username,
      );
      await loadTeamDetails(teamId);
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateRole(String teamId, String username, String role) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      _activeTeam = await _client.updateMemberRole(
        creds: creds,
        teamId: teamId,
        username: username,
        role: role,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTeam(String teamId) async {
    final creds = _creds();
    if (creds == null) return false;
    try {
      await _client.deleteTeam(creds: creds, teamId: teamId);
      _teams = _teams.where((t) => t.id != teamId).toList();
      if (_activeTeam?.id == teamId) {
        _activeTeam = null;
        _messages = const [];
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = friendlyError(e);
      notifyListeners();
      return false;
    }
  }

  Future<DecryptedTeamMessage> _decrypt(TeamMessage m) async {
    final kp = _keys.keyPair;
    if (kp == null || kp.privateKey == null) {
      return DecryptedTeamMessage(message: m, error: 'no key');
    }
    try {
      final sender = await _lookupIdentity(m.senderUsername);
      if (sender == null) {
        return DecryptedTeamMessage(message: m, error: 'sender not found');
      }
      final plaintext = await _crypto.decryptMessage(
        m.encryptedBody,
        m.nonce,
        sender.publicKey,
        kp.privateKey!,
      );
      return DecryptedTeamMessage(message: m, plaintext: plaintext);
    } catch (e) {
      return DecryptedTeamMessage(message: m, error: e.toString());
    }
  }

  /// Inject a server-pushed team message into the active conversation.
  Future<DecryptedTeamMessage> onIncomingTeamMessage(TeamMessage m) async {
    final dm = await _decrypt(m);
    if (_activeTeam?.id == m.teamId &&
        !_messages.any((e) => e.message.id == m.id)) {
      _messages = [..._messages, dm];
      notifyListeners();
    }
    return dm;
  }

  /// Inject a team the user was just added to without needing a refresh.
  void onTeamInvite(Team team) {
    if (_teams.any((t) => t.id == team.id)) return;
    _teams = [..._teams, team];
    notifyListeners();
  }

  Future<void> loadTeamMessages(String teamId,
      {int limit = 50, int offset = 0, bool append = false}) async {
    final creds = _creds();
    if (creds == null) return;
    if (!append) {
      _loadingMessages = true;
      notifyListeners();
    }
    try {
      final raw = await _client.getTeamMessages(
        creds: creds,
        teamId: teamId,
        limit: limit,
        offset: offset,
      );
      final decrypted = <DecryptedTeamMessage>[];
      for (final m in raw) {
        decrypted.add(await _decrypt(m));
      }
      if (append) {
        final merged = [...decrypted, ..._messages];
        merged.sort((a, b) =>
            a.message.createdAt.compareTo(b.message.createdAt));
        _messages = merged;
      } else {
        decrypted.sort((a, b) =>
            a.message.createdAt.compareTo(b.message.createdAt));
        _messages = decrypted;
      }
    } catch (e) {
      _error = friendlyError(e);
    } finally {
      _loadingMessages = false;
      notifyListeners();
    }
  }

  Future<bool> sendTeamMessage(String teamId, String plaintext) async {
    final creds = _creds();
    final kp = _keys.keyPair;
    if (creds == null || kp == null || kp.privateKey == null) return false;
    _sending = true;
    _error = null;
    notifyListeners();
    try {
      final team = _activeTeam?.id == teamId
          ? _activeTeam!
          : await _client.getTeam(creds: creds, teamId: teamId);
      final recipients = <Map<String, String>>[];
      for (final member in team.members) {
        final id = await _lookupIdentity(member.username);
        if (id == null) continue;
        final payload = await _crypto.encryptMessage(
          plaintext,
          id.publicKey,
          kp.privateKey!,
        );
        recipients.add({
          'username': member.username,
          'encryptedBody': payload.encryptedBody,
          'nonce': payload.nonce,
        });
      }
      final sent = await _client.sendTeamMessage(
        creds: creds,
        teamId: teamId,
        recipients: recipients,
      );
      // Assume the server echoes back the message for the sender —
      // show the plaintext we already know.
      _messages = [
        ..._messages,
        DecryptedTeamMessage(message: sent, plaintext: plaintext),
      ];
      return true;
    } catch (e) {
      _error = friendlyError(e);
      return false;
    } finally {
      _sending = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _keys.removeListener(_onKeysChanged);
    super.dispose();
  }
}
