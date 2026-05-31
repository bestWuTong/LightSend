import 'package:flutter/material.dart';

/// Semantic color tokens for LightSend.
class AppColors {
  AppColors._();

  // Default brand seed color (Cyan 500)
  static const Color defaultSeed = Color(0xFF00BCD4);

  // Status colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFE53935);
  static const Color warning = Color(0xFFFB8C00);

  /// Preset seed colors for the theme picker.
  static const List<Color> presets = [
    Color(0xFF00BCD4), // Cyan
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
    Color(0xFFF44336), // Red
    Color(0xFFFF9800), // Orange
    Color(0xFF795548), // Brown
    Color(0xFF607D8B), // Blue Grey
    Color(0xFF8BC34A), // Light Green
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFF5722), // Deep Orange
  ];

  static ColorScheme lightScheme({Color seedColor = defaultSeed}) {
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
  }

  static ColorScheme darkScheme({Color seedColor = defaultSeed}) {
    return ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );
  }
}
