import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// File integrity utilities.
class ChecksumUtils {
  ChecksumUtils._();

  /// Computes the MD5 hex digest of the file at [filePath].
  static Future<String> md5File(String filePath) async {
    final file = File(filePath);
    final stream = file.openRead();
    final digest = await md5.bind(stream).first;
    return digest.toString();
  }

  /// Computes the MD5 hex digest of the given [text].
  static String md5String(String text) {
    final bytes = utf8.encode(text);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
}
