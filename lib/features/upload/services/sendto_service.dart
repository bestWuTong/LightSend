import 'dart:io';

/// Manages the Windows "Send to" menu entry via the SendTo folder.
///
/// Places a shortcut at `%APPDATA%\Microsoft\Windows\SendTo\轻传.lnk`.
/// When a user right-clicks a file → Send to → 轻传, Windows launches
/// the executable with the file path as the first argument.
class SendtoService {
  static const _shortcutName = '轻传.lnk';

  String get _sendToDir {
    final appData = Platform.environment['APPDATA'];
    return '$appData\\Microsoft\\Windows\\SendTo';
  }

  String get _shortcutPath => '$_sendToDir\\$_shortcutName';

  Future<bool> isRegistered() async {
    if (!Platform.isWindows) return false;

    try {
      return await File(_shortcutPath).exists();
    } catch (_) {
      return false;
    }
  }

  Future<bool> register() async {
    if (!Platform.isWindows) return false;

    try {
      final exePath = Platform.resolvedExecutable;

      // Ensure SendTo directory exists
      await Directory(_sendToDir).create(recursive: true);

      // Create shortcut via PowerShell COM
      final psScript = '''
\$ws = New-Object -ComObject WScript.Shell
\$sc = \$ws.CreateShortcut("$_shortcutPath")
\$sc.TargetPath = "$exePath"
\$sc.Save()
''';
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-NonInteractive', '-Command', psScript],
      );
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unregister() async {
    if (!Platform.isWindows) return false;

    try {
      final file = File(_shortcutPath);
      if (await file.exists()) {
        await file.delete();
      }
      return true;
    } catch (_) {
      return false;
    }
  }
}
