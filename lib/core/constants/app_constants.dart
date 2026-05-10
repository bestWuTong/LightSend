import '../utils/version_helper.dart';

/// Application-wide constants for LightSend.
class AppConstants {
  AppConstants._();

  static const String appName = 'LightSend';
  static const String appNameCN = '轻传';
  static String get appVersion => VersionHelper.version;

  // About
  static const String appAuthor = '無同';
  static const String appWebsite = 'https://lightsend.bestwutong.top';
  static const String appRepo = 'https://github.com/bestWuTong/LightSend';

  // Storage keys for SharedPreferences
  static const String storageKeyConfig = 'lightsend_config_v1';
  static const String storageKeyUseCustomFont = 'lightsend_use_custom_font';

  // Custom font
  static const String customFontFamily = 'HarmonyOS_Sans_SC';

  // WebDAV
  static const int webdavConnectTimeoutMs = 10000;
  static const int webdavReceiveTimeoutMs = 15000;

  // WebDAV transfer directory on the remote server
  static const String remoteTransferDir = 'LightSend';

  // Tray
  static const String trayIconAsset = 'assets/tray_icon.ico';
  static const String trayTooltip = '轻传 LightSend';
  static const String trayMenuKeyShow = 'show';
  static const String trayMenuKeyExit = 'exit';

  // Auto-start registry
  static const String autoStartRegKey =
      r'Software\Microsoft\Windows\CurrentVersion\Run';
  static const String autoStartValueName = 'LightSend';

  // Window defaults
  static const double windowWidth = 480;
  static const double windowHeight = 680;
}
