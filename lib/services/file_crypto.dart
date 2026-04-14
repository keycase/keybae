import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'message_crypto.dart';

/// Output of [FileCrypto.encryptFile].
///
/// [encryptedBytes] is `fileNonce ‖ ciphertext ‖ mac` — the self-contained
/// blob stored server-side. [fileNonce] is returned separately as a
/// convenience (matches the task contract) but is also the prefix of
/// [encryptedBytes] so [decryptFile] doesn't need it as a parameter.
class EncryptedFile {
  final Uint8List encryptedBytes;
  final String encryptedKey;
  final String nonce;
  final String fileNonce;
  const EncryptedFile({
    required this.encryptedBytes,
    required this.encryptedKey,
    required this.nonce,
    required this.fileNonce,
  });
}

class WrappedKey {
  final String encryptedKey;
  final String nonce;
  const WrappedKey({required this.encryptedKey, required this.nonce});
}

class FileCrypto {
  final AesGcm _aes = AesGcm.with256bits();
  final MessageCrypto _wrap;

  FileCrypto({MessageCrypto? wrap}) : _wrap = wrap ?? MessageCrypto();

  Future<EncryptedFile> encryptFile(
    Uint8List plainBytes,
    String ownerPublicKey,
    String ownerPrivateKey,
  ) async {
    final key = await _aes.newSecretKey();
    final keyBytes = await key.extractBytes();
    final nonce = _aes.newNonce();
    final box = await _aes.encrypt(plainBytes, secretKey: key, nonce: nonce);
    final blob = Uint8List(nonce.length + box.cipherText.length + box.mac.bytes.length);
    blob.setAll(0, nonce);
    blob.setAll(nonce.length, box.cipherText);
    blob.setAll(nonce.length + box.cipherText.length, box.mac.bytes);

    final wrapped = await _wrap.encryptMessage(
      base64Encode(keyBytes),
      ownerPublicKey,
      ownerPrivateKey,
    );

    return EncryptedFile(
      encryptedBytes: blob,
      encryptedKey: wrapped.encryptedBody,
      nonce: wrapped.nonce,
      fileNonce: base64Encode(nonce),
    );
  }

  Future<Uint8List> decryptFile(
    Uint8List encryptedBytes,
    String encryptedKey,
    String nonce,
    String senderPublicKey,
    String recipientPrivateKey,
  ) async {
    final keyB64 = await _wrap.decryptMessage(
      encryptedKey,
      nonce,
      senderPublicKey,
      recipientPrivateKey,
    );
    final key = SecretKey(base64Decode(keyB64));
    const nonceLen = 12;
    const macLen = 16;
    if (encryptedBytes.length < nonceLen + macLen) {
      throw ArgumentError('encrypted file shorter than nonce+mac');
    }
    final fileNonce = encryptedBytes.sublist(0, nonceLen);
    final cipher = encryptedBytes.sublist(nonceLen, encryptedBytes.length - macLen);
    final mac = Mac(encryptedBytes.sublist(encryptedBytes.length - macLen));
    final clear = await _aes.decrypt(
      SecretBox(cipher, nonce: fileNonce, mac: mac),
      secretKey: key,
    );
    return Uint8List.fromList(clear);
  }

  /// Unwrap the file key using the owner's identity keys, then rewrap it
  /// to a recipient's identity public key.
  Future<WrappedKey> reEncryptKeyForRecipient(
    String encryptedKey,
    String nonce,
    String ownerPublicKey,
    String ownerPrivateKey,
    String recipientPublicKey,
  ) async {
    final keyB64 = await _wrap.decryptMessage(
      encryptedKey,
      nonce,
      ownerPublicKey,
      ownerPrivateKey,
    );
    final rewrapped = await _wrap.encryptMessage(
      keyB64,
      recipientPublicKey,
      ownerPrivateKey,
    );
    return WrappedKey(
      encryptedKey: rewrapped.encryptedBody,
      nonce: rewrapped.nonce,
    );
  }
}
