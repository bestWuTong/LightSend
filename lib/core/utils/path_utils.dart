import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Platform-appropriate path utilities.
class PathUtils {
  PathUtils._();

  /// Returns the default download directory for the current platform.
  static Future<String> getDefaultDownloadPath() async {
    if (Platform.isWindows) {
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null) return dir.path;
      } catch (_) {}
      final home = Platform.environment['USERPROFILE'] ?? r'C:\Users\Default';
      return '$home\\Downloads';
    }
    if (Platform.isAndroid) {
      // Android: prefer shared Downloads folder so users can find files easily.
      final sharedDownload = Directory('/storage/emulated/0/Download');
      if (await sharedDownload.exists()) return sharedDownload.path;
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) return '${extDir.path}/Download';
    }
    if (Platform.isLinux) {
      try {
        final dir = await getDownloadsDirectory();
        if (dir != null) {
          return dir.path;
        }
      } catch (_) {}

      final xdgDownloadDir = await _readLinuxXdgDownloadDir();
      if (xdgDownloadDir != null) {
        return xdgDownloadDir;
      }

      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return joinPath(home, 'Downloads');
      }
    }
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir.path;
    } catch (_) {}
    try {
      final appDir = await getApplicationDocumentsDirectory();
      return '${appDir.path}${Platform.pathSeparator}LightSend';
    } catch (_) {
      return '.';
    }
  }

  /// Joins [directory] and [fileName] using the current platform separator.
  static String joinPath(String directory, String fileName) {
    if (directory.isEmpty) return fileName;
    final sep = Platform.pathSeparator;
    if (directory.endsWith('/') || directory.endsWith(r'\')) {
      return '$directory$fileName';
    }
    return '$directory$sep$fileName';
  }

  /// Returns a shortened display form of [path].
  static String displayPath(String path, {int maxSegments = 3}) {
    final sep = Platform.pathSeparator;
    final parts = path.split(sep);
    if (parts.length <= maxSegments) return path;
    final tail = parts.sublist(parts.length - maxSegments).join(sep);
    return '...$sep$tail';
  }

  static Future<String?> _readLinuxXdgDownloadDir() async {
    final home = Platform.environment['HOME'];
    if (home == null || home.isEmpty) return null;

    final configFile = File(joinPath(home, '.config/user-dirs.dirs'));
    if (!await configFile.exists()) return null;

    try {
      final lines = await configFile.readAsLines();
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('XDG_DOWNLOAD_DIR=')) continue;

        final value = trimmed
            .substring('XDG_DOWNLOAD_DIR='.length)
            .trim()
            .replaceAll(RegExp(r'^"|"$'), '');
        if (value.isEmpty) return null;
        return value.replaceFirst(r'$HOME', home);
      }
    } catch (_) {}
    return null;
  }
}
