import 'dart:developer' as developer;
import 'dart:io' show File, Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:window_manager/window_manager.dart';

import 'app.dart';
import 'core/storage/shared_preferences_storage.dart';
import 'core/utils/version_helper.dart';
import 'features/config/presentation/providers/config_providers.dart';

/// Holds file paths passed via command-line (e.g. --upload "C:\file.pdf").
/// Set before app starts, consumed by UploadPage.
List<String> pendingUploadPaths = [];

/// Notifies UploadPage when new pending files arrive (Android share, etc.).
final ValueNotifier<int> pendingUploadTick = ValueNotifier<int>(0);

/// MethodChannel for receiving shared files on Android.
const _shareChannel = MethodChannel('lightsend/share');

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load app version from pubspec.yaml (bundled as asset)
  await VersionHelper.init();

  // window_manager is desktop-only — skip on Android/iOS
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    await windowManager.ensureInitialized();
  }

  // Parse --upload <path> from command line (desktop)
  _parseArgs(args);

  // Listen for Android share intents
  _setupShareIntentListener();

  FlutterError.onError = (details) {
    developer.log('FlutterError',
        error: details.exception, stackTrace: details.stack);
    FlutterError.presentError(details);
  };

  try {
    final prefs = await SharedPreferences.getInstance();

    final storage = SharedPreferencesStorage(prefs);

    runApp(
      ProviderScope(
        overrides: [
          localStorageProvider.overrideWithValue(storage),
        ],
        child: const LightSendApp(),
      ),
    );
    developer.log('App started');
  } catch (e, st) {
    developer.log('Fatal error in main', error: e, stackTrace: st);
    runApp(ErrorApp(error: e));
  }
}

void _setupShareIntentListener() {
  _shareChannel.setMethodCallHandler((call) async {
    if (call.method == 'onSharedFiles') {
      final List<dynamic>? paths = (call.arguments as Map?)?['paths'];
      if (paths != null) {
        for (final path in paths) {
          if (path is String) {
            pendingUploadPaths.add(path);
          }
        }
        pendingUploadTick.value++;
      }
    }
  });
}

void _parseArgs(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    if (args[i] == '--upload' && i + 1 < args.length) {
      // Explicit --upload flag from registry context menu
      pendingUploadPaths.add(args[i + 1]);
      i++;
    } else if (!args[i].startsWith('-')) {
      // Bare file path from SendTo menu or drag-to-shortcut
      final file = File(args[i]);
      if (file.existsSync()) {
        pendingUploadPaths.add(args[i]);
      }
    }
  }
}

class ErrorApp extends StatelessWidget {
  final Object error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text('启动失败',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectableText('$error',
                    style: const TextStyle(fontSize: 13),
                    textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
