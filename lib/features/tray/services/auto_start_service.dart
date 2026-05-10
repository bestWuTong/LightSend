import 'dart:io';

import '../../../core/constants/app_constants.dart';

/// Manages Windows auto-start via registry Run key.
class AutoStartService {
  /// Checks if auto-start is currently enabled.
  Future<bool> isEnabled() async {
    if (!Platform.isWindows) return false;

    try {
      final result = await Process.run('reg', [
        'query',
        'HKCU\\${AppConstants.autoStartRegKey}',
        '/v',
        AppConstants.autoStartValueName,
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Enables auto-start by adding the executable to registry Run.
  Future<bool> enable() async {
    if (!Platform.isWindows) return false;

    try {
      final exePath = Platform.resolvedExecutable;
      final result = await Process.run('reg', [
        'add',
        'HKCU\\${AppConstants.autoStartRegKey}',
        '/v',
        AppConstants.autoStartValueName,
        '/t',
        'REG_SZ',
        '/d',
        exePath,
        '/f',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// Removes the auto-start registry entry.
  Future<bool> disable() async {
    if (!Platform.isWindows) return false;

    try {
      final result = await Process.run('reg', [
        'delete',
        'HKCU\\${AppConstants.autoStartRegKey}',
        '/v',
        AppConstants.autoStartValueName,
        '/f',
      ]);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
