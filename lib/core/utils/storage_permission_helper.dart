import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Helper for Android storage permissions (MANAGE_EXTERNAL_STORAGE).
class StoragePermissionHelper {
  StoragePermissionHelper._();

  static const _channel = MethodChannel('lightsend/storage_permission');

  /// Whether the app has full storage access on the current platform.
  /// Android 11+: checks MANAGE_EXTERNAL_STORAGE
  /// Android 10-: checks WRITE_EXTERNAL_STORAGE
  /// Other platforms: always true (no restriction)
  static Future<bool> hasFullStorageAccess() async {
    if (!Platform.isAndroid) return true;

    try {
      // Request via platform channel to Android native side
      final result = await _channel.invokeMethod<bool>('hasManageStoragePermission');
      return result ?? false;
    } catch (_) {
      // Fallback: assume granted (will fail at write time if not)
      return true;
    }
  }

  /// Opens Android system settings page for "All files access" permission.
  /// Does nothing on non-Android platforms.
  static Future<void> openStoragePermissionSettings() async {
    if (!Platform.isAndroid) return;

    try {
      await _channel.invokeMethod('openManageStorageSettings');
    } catch (_) {}
  }
}
