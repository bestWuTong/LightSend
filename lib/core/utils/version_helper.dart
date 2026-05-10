import 'package:flutter/services.dart';

/// Reads the app version from pubspec.yaml (bundled as an asset).
/// Returns only the major.minor.patch part (e.g. "1.0.0" from "1.0.0+1").
class VersionHelper {
  VersionHelper._();

  static String? _version;

  static String get version => _version ?? '0.0.0';

  static Future<void> init() async {
    final yamlStr = await rootBundle.loadString('pubspec.yaml');
    final match = RegExp(r'^version:\s*(\S+)', multiLine: true).firstMatch(yamlStr);
    final raw = match?.group(1) ?? '0.0.0';
    _version = raw.split('+').first;
  }
}
