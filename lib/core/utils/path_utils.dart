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

  /// Returns a shortened display form of [path].
  static String displayPath(String path, {int maxSegments = 3}) {
    final sep = Platform.pathSeparator;
    final parts = path.split(sep);
    if (parts.length <= maxSegments) return path;
    final tail = parts.sublist(parts.length - maxSegments).join(sep);
    return '...$sep$tail';
  }
}
