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
}
