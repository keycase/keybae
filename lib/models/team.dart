import 'package:flutter/foundation.dart';

@immutable
class TeamMember {
  final String username;
  final String role; // owner | admin | member
  final DateTime joinedAt;

  const TeamMember({
    required this.username,
    required this.role,
    required this.joinedAt,
  });

  factory TeamMember.fromJson(Map<String, dynamic> json) => TeamMember(
        username: json['username'] as String,
        role: json['role'] as String? ?? 'member',
        joinedAt: DateTime.parse(json['joinedAt'] as String),
      );
}

@immutable
class Team {
  final String id;
  final String name;
  final String displayName;
  final DateTime createdAt;
  final List<TeamMember> members;

  const Team({
    required this.id,
    required this.name,
    required this.displayName,
    required this.createdAt,
    this.members = const [],
  });

  int get memberCount => members.length;

  factory Team.fromJson(Map<String, dynamic> json) => Team(
        id: json['id'] as String,
        name: json['name'] as String,
        displayName: json['displayName'] as String? ?? json['name'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        members: (json['members'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(TeamMember.fromJson)
                .toList() ??
            const [],
      );
}

@immutable
class TeamMessage {
  final String id;
  final String teamId;
  final String senderUsername;
  final String encryptedBody;
  final String nonce;
  final DateTime createdAt;

  const TeamMessage({
    required this.id,
    required this.teamId,
    required this.senderUsername,
    required this.encryptedBody,
    required this.nonce,
    required this.createdAt,
  });

  factory TeamMessage.fromJson(Map<String, dynamic> json) => TeamMessage(
        id: json['id'] as String,
        teamId: json['teamId'] as String,
        senderUsername: json['senderUsername'] as String,
        encryptedBody: json['encryptedBody'] as String? ?? '',
        nonce: json['nonce'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

@immutable
class DecryptedTeamMessage {
  final TeamMessage message;
  final String? plaintext;
  final String? error;

  const DecryptedTeamMessage({
    required this.message,
    this.plaintext,
    this.error,
  });

  String get previewText =>
      plaintext ?? (error != null ? '[unable to decrypt]' : '');
}
