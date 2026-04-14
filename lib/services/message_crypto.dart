import 'dart:convert';

import 'package:keycase_core/keycase_core.dart' as core;

/// Output of [MessageCrypto.encryptMessage].
class EncryptedPayload {
  final String encryptedBody;
  final String nonce;
  const EncryptedPayload({required this.encryptedBody, required this.nonce});
}

/// Thin wrapper over keycase_core's X25519 + AES-GCM crypto that splits
/// the combined blob into separate [encryptedBody] and [nonce] fields
/// for transport.
class MessageCrypto {
  static const int _nonceLen = 12;

  Future<EncryptedPayload> encryptMessage(
    String plaintext,
    String recipientPublicKey,
    String senderPrivateKey,
  ) async {
    final combined = await core.encryptTo(
      plaintext,
      recipientPublicKey,
      senderPrivateKey,
    );
    final raw = base64Decode(combined);
    if (raw.length < _nonceLen) {
      throw StateError('encrypted payload shorter than nonce');
    }
    final nonce = raw.sublist(0, _nonceLen);
    final rest = raw.sublist(_nonceLen);
    return EncryptedPayload(
      encryptedBody: base64Encode(rest),
      nonce: base64Encode(nonce),
    );
  }

  Future<String> decryptMessage(
    String encryptedBody,
    String nonce,
    String senderPublicKey,
    String recipientPrivateKey,
  ) async {
    final nonceBytes = base64Decode(nonce);
    final bodyBytes = base64Decode(encryptedBody);
    final combined = [...nonceBytes, ...bodyBytes];
    return core.decryptFrom(
      base64Encode(combined),
      senderPublicKey,
      recipientPrivateKey,
    );
  }
}
