import 'dart:io' show Platform, exit;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/config/presentation/providers/config_providers.dart';
import 'features/home/home.dart';
import 'features/tray/services/tray_service.dart';
import 'features/tray/services/window_service.dart';

class LightSendApp extends ConsumerStatefulWidget {
  const LightSendApp({super.key});

  @override
  ConsumerState<LightSendApp> createState() => _LightSendAppState();
}

class _LightSendAppState extends ConsumerState<LightSendApp>
    with WindowListener, TrayListener {
  final WindowService _windowService = WindowService();
  final TrayService _trayService = TrayService();

  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      windowManager.addListener(this);
      trayManager.addListener(this);
      _initServices();
    }
  }

  Future<void> _initServices() async {
    await _windowService.init();
    await _trayService.init();
  }

  @override
  void dispose() {
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  // ─── WindowListener ──────────────────────────────────────────────────────

  @override
  void onWindowClose() {
    final config = ref.read(configProvider).valueOrNull;
    if (config?.exitOnClose ?? true) {
      exit(0);
    } else {
      _windowService.hide();
    }
  }

  // ─── TrayListener ────────────────────────────────────────────────────────

  @override
  void onTrayIconMouseDown() {
    _windowService.show();
  }

  @override
  void onTrayIconRightMouseDown() {
    _trayService.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case AppConstants.trayMenuKeyShow:
        _windowService.show();
        break;
      case AppConstants.trayMenuKeyExit:
        exit(0);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider).valueOrNull;
    final fontFamily =
        (config?.useCustomFont ?? true) ? AppConstants.customFontFamily : null;
    final seedColor = Color(config?.seedColor ?? AppColors.defaultSeed.toARGB32());
    final themeMode = _parseThemeMode(config?.themeMode);

    return MaterialApp(
      title: AppConstants.appNameCN,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(fontFamily: fontFamily, seedColor: seedColor),
      darkTheme: AppTheme.dark(fontFamily: fontFamily, seedColor: seedColor),
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      home: const HomePage(),
    );
  }

  ThemeMode _parseThemeMode(String? mode) {
    switch (mode) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }
}
