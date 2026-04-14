import 'package:flutter/foundation.dart';

@immutable
class FileShare {
  final String username;
  final DateTime sharedAt;
  const FileShare({required this.username, required this.sharedAt});

  factory FileShare.fromJson(Map<String, dynamic> json) => FileShare(
        username: json['username'] as String,
        sharedAt: DateTime.parse(json['sharedAt'] as String),
      );
}

@immutable
class FileItem {
  final String id;
  final String filename;
  final int size;
  final String ownerUsername;
  final String? folderId;
  final String encryptedKey;
  final String nonce;
  final DateTime createdAt;
  final List<FileShare> shares;

  const FileItem({
    required this.id,
    required this.filename,
    required this.size,
    required this.ownerUsername,
    required this.folderId,
    required this.encryptedKey,
    required this.nonce,
    required this.createdAt,
    this.shares = const [],
  });

  bool get isShared => shares.isNotEmpty;

  factory FileItem.fromJson(Map<String, dynamic> json) => FileItem(
        id: json['id'] as String,
        filename: json['filename'] as String,
        size: (json['size'] as num?)?.toInt() ?? 0,
        ownerUsername: json['ownerUsername'] as String,
        folderId: json['folderId'] as String?,
        encryptedKey: json['encryptedKey'] as String? ?? '',
        nonce: json['nonce'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        shares: (json['shares'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(FileShare.fromJson)
                .toList() ??
            const [],
      );
}

@immutable
class FolderItem {
  final String id;
  final String name;
  final String? parentFolderId;
  final String ownerUsername;
  final DateTime createdAt;

  const FolderItem({
    required this.id,
    required this.name,
    required this.parentFolderId,
    required this.ownerUsername,
    required this.createdAt,
  });

  factory FolderItem.fromJson(Map<String, dynamic> json) => FolderItem(
        id: json['id'] as String,
        name: json['name'] as String,
        parentFolderId: json['parentFolderId'] as String?,
        ownerUsername: json['ownerUsername'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}
