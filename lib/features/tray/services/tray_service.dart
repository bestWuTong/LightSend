import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';

import '../../../core/constants/app_constants.dart';

/// Manages the system tray icon and context menu.
class TrayService {
  bool _initialized = false;

  /// Initializes the system tray icon.
  Future<void> init() async {
    if (!Platform.isWindows) return;
    if (_initialized) return;

    await trayManager.setIcon(
      AppConstants.trayIconAsset,
      iconSize: 16,
    );

    await trayManager.setToolTip(AppConstants.trayTooltip);

    final menu = Menu(
      items: [
        MenuItem(
          key: AppConstants.trayMenuKeyShow,
          label: '显示窗口',
        ),
        MenuItem.separator(),
        MenuItem(
          key: AppConstants.trayMenuKeyExit,
          label: '退出',
        ),
      ],
    );

    await trayManager.setContextMenu(menu);
    _initialized = true;
    debugPrint('[TrayService] Initialized');
  }

  /// Pops up the tray context menu.
  Future<void> popUpContextMenu() async {
    await trayManager.popUpContextMenu();
  }

  /// Removes the tray icon.
  Future<void> destroy() async {
    if (!Platform.isWindows) return;
    await trayManager.destroy();
  }
}
