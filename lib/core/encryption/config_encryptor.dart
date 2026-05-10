import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// AES-CBC encryptor for sensitive config fields (WebDAV password, device ID).
class ConfigEncryptor {
  final enc.Key _key;

  ConfigEncryptor({required String salt}) : _key = _deriveKey(salt);

  static enc.Key _deriveKey(String salt) {
    final hash = sha256.convert(utf8.encode(salt));
    return enc.Key(Uint8List.fromList(hash.bytes));
  }

  /// Encrypts [plaintext] and returns a base64-encoded string.
  ///
  /// Returns the plaintext as-is if it is empty, avoiding encrypt package
  /// padding issues with zero-length input.
  String encrypt(String plaintext) {
    if (plaintext.isEmpty) return '';

    final ivBytes = List<int>.generate(16, (_) => Random().nextInt(256));
    final iv = enc.IV(Uint8List.fromList(ivBytes));
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final combined = Uint8List.fromList([...ivBytes, ...encrypted.bytes]);
    return base64.encode(combined);
  }

  /// Decrypts a base64 string produced by [encrypt].
  ///
  /// Returns empty string if [ciphertext] is empty.
  String decrypt(String ciphertext) {
    if (ciphertext.isEmpty) return '';

    final combined = base64.decode(ciphertext);
    final iv = enc.IV(Uint8List.fromList(combined.sublist(0, 16)));
    final encryptedBytes = Uint8List.fromList(combined.sublist(16));
    final encrypter = enc.Encrypter(enc.AES(_key, mode: enc.AESMode.cbc));
    return encrypter.decrypt(enc.Encrypted(encryptedBytes), iv: iv);
  }
}
