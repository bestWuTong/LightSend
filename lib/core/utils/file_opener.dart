import 'dart:io' show Directory, File, Platform;

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

const _fileChannel = MethodChannel('lightsend/file');

/// Opens a file or directory using the appropriate platform mechanism.
class FileOpener {
  FileOpener._();

  /// Opens a file with the default application.
  static Future<void> openFile(String path) async {
    if (!await File(path).exists()) return;
    await OpenFilex.open(path);
  }

  /// Opens the parent directory of the given file in the system file manager.
  static Future<void> openContainingFolder(String filePath) async {
    final dir = filePath.substring(0, filePath.lastIndexOf('/'));
    if (!await Directory(dir).exists()) return;

    if (Platform.isAndroid) {
      // Use native MethodChannel to open directory properly on Android
      try {
        await _fileChannel.invokeMethod('openDirectory', {'path': dir});
      } catch (_) {
        // Fallback: try open_filex
        await OpenFilex.open(dir);
      }
    } else {
      await OpenFilex.open(dir);
    }
  }
}
