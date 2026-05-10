import 'dart:io' show Platform;
import 'dart:ui' show Size;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../../../core/constants/app_constants.dart';

/// Manages window lifecycle for tray integration.
class WindowService {
  bool _initialized = false;

  /// Initializes window manager with default options.
  /// No-op on non-desktop platforms.
  Future<void> init() async {
    if (_initialized) return;
    if (!(Platform.isWindows || Platform.isMacOS || Platform.isLinux)) return;

    await windowManager.ensureInitialized();

    final options = WindowOptions(
      size: const Size(AppConstants.windowWidth, AppConstants.windowHeight),
      center: true,
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: AppConstants.appNameCN,
    );

    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // Prevent close → hide to tray instead
    await windowManager.setPreventClose(true);

    _initialized = true;
    debugPrint('[WindowService] Initialized');
  }

  /// Hides the window to the system tray.
  Future<void> hide() async {
    await windowManager.hide();
  }

  /// Shows and focuses the window.
  Future<void> show() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// Checks if window is currently visible.
  Future<bool> isVisible() async {
    return windowManager.isVisible();
  }

  /// Destroys the window and exits the app.
  Future<void> destroy() async {
    await windowManager.destroy();
  }

  /// Sets whether window close is prevented (for exit flow).
  Future<void> setPreventClose(bool value) async {
    await windowManager.setPreventClose(value);
  }
}
