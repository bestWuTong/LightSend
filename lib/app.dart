import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';

import 'core/constants/app_constants.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'features/config/presentation/providers/config_providers.dart';
import 'features/home/home.dart';

class LightSendApp extends ConsumerStatefulWidget {
  const LightSendApp({super.key});

  @override
  ConsumerState<LightSendApp> createState() => _LightSendAppState();
}

class _LightSendAppState extends ConsumerState<LightSendApp> {
  bool get _isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      _initWindow();
    }
  }

  Future<void> _initWindow() async {
    final options = WindowOptions(
      size: const Size(AppConstants.windowWidth, AppConstants.windowHeight),
      minimumSize: const Size(
        AppConstants.windowWidth,
        AppConstants.windowHeight,
      ),
      title: AppConstants.appNameCN,
      center: true,
      skipTaskbar: false,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // ─── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configProvider).valueOrNull;
    final seedColor = Color(
      config?.seedColor ?? AppColors.defaultSeed.toARGB32(),
    );
    final themeMode = _parseThemeMode(config?.themeMode);

    return MaterialApp(
      title: AppConstants.appNameCN,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seedColor: seedColor),
      darkTheme: AppTheme.dark(seedColor: seedColor),
      themeMode: themeMode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
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
