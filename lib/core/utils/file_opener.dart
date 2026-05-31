import 'dart:io' show Directory, File, Platform, Process;

import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';

const _fileChannel = MethodChannel('lightsend/file');

/// Opens a file or directory using the appropriate platform mechanism.
class FileOpener {
  FileOpener._();

  /// Opens a file with the default application.
  static Future<void> openFile(String path) async {
    if (!await File(path).exists()) return;
    await _openPath(path);
  }

  /// Opens the parent directory of the given file in the system file manager.
  static Future<void> openContainingFolder(String filePath) async {
    final dir = File(filePath).parent.path;
    if (!await Directory(dir).exists()) return;

    if (Platform.isAndroid) {
      // Use native MethodChannel to open directory properly on Android
      try {
        await _fileChannel.invokeMethod('openDirectory', {'path': dir});
      } catch (_) {
        // Fallback: try open_filex
        await _openPath(dir);
      }
    } else {
      await _openPath(dir);
    }
  }

  static Future<void> _openPath(String path) async {
    if (Platform.isLinux) {
      final opened =
          await _tryRun('xdg-open', [path]) ||
          await _tryRun('gio', ['open', path]);
      if (opened) return;
    }

    await OpenFilex.open(path);
  }

  static Future<bool> _tryRun(String executable, List<String> arguments) async {
    try {
      final result = await Process.run(executable, arguments);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
