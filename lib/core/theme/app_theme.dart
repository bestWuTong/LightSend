import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Material3 theme data for LightSend.
class AppTheme {
  AppTheme._();

  static ThemeData light({String? fontFamily, Color seedColor = AppColors.defaultSeed}) {
    final colorScheme = AppColors.lightScheme(seedColor: seedColor);
    return _buildTheme(colorScheme, Brightness.light, fontFamily);
  }

  static ThemeData dark({String? fontFamily, Color seedColor = AppColors.defaultSeed}) {
    final colorScheme = AppColors.darkScheme(seedColor: seedColor);
    return _buildTheme(colorScheme, Brightness.dark, fontFamily);
  }

  static ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness, String? fontFamily) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      brightness: brightness,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
