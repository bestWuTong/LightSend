import 'dart:async';
import 'dart:io' as io;

import 'package:path_provider/path_provider.dart';

/// Cleans up app cache files — primarily the Android share-intent cache.
class CacheCleaner {
  static String? _cacheDirPath;

  /// Initialize the cache path. Call once at startup.
  static Future<void> init() async {
    try {
      _cacheDirPath = (await getTemporaryDirectory()).path;
    } catch (_) {}
  }

  /// Deletes all files under cache/shared/, the directory where Android
  /// share-intent files are copied before upload. These are orphaned if
  /// a previous session crashed or was killed before cleaning up.
  static Future<void> clearSharedCache() async {
    if (_cacheDirPath == null) return;
    try {
      final sharedDir = io.Directory('$_cacheDirPath/shared');
      if (!await sharedDir.exists()) return;
      await for (final entity in sharedDir.list()) {
        if (entity is io.File) {
          try {
            await entity.delete();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Deletes [filePath] when it resides inside the app cache directory.
  static Future<void> deleteIfInCache(String filePath) async {
    if (_cacheDirPath == null) return;
    try {
      if (!filePath.startsWith(_cacheDirPath!)) return;
      final file = io.File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
