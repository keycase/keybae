import 'package:flutter/foundation.dart';

@immutable
class Message {
  final String id;
  final String senderUsername;
  final String recipientUsername;
  final String encryptedBody;
  final String nonce;
  final bool read;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.senderUsername,
    required this.recipientUsername,
    required this.encryptedBody,
    required this.nonce,
    required this.read,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        senderUsername: json['senderUsername'] as String,
        recipientUsername: json['recipientUsername'] as String,
        encryptedBody: json['encryptedBody'] as String,
        nonce: json['nonce'] as String? ?? '',
        read: json['read'] as bool? ?? false,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  Message copyWith({bool? read}) => Message(
        id: id,
        senderUsername: senderUsername,
        recipientUsername: recipientUsername,
        encryptedBody: encryptedBody,
        nonce: nonce,
        read: read ?? this.read,
        createdAt: createdAt,
      );
}

/// A message with its plaintext decoded for display.
@immutable
class DecryptedMessage {
  final Message message;
  final String? plaintext;
  final String? error;

  const DecryptedMessage({
    required this.message,
    this.plaintext,
    this.error,
  });

  String get previewText =>
      plaintext ?? (error != null ? '[unable to decrypt]' : '');
}
