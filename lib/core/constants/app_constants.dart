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

  // WebDAV
  static const int webdavConnectTimeoutMs = 10000;
  static const int webdavReceiveTimeoutMs = 15000;
  static const int webdavTransferMinTimeoutMs = 60000;
  static const int webdavTransferTimeoutMsPerMb = 1000;
  static const int webdavTransferMaxTimeoutMs = 30 * 60 * 1000;

  static int webdavTransferTimeoutMsForBytes(int bytes) {
    final megabytes = (bytes / (1024 * 1024)).ceil();
    final timeout =
        webdavTransferMinTimeoutMs + megabytes * webdavTransferTimeoutMsPerMb;
    if (timeout > webdavTransferMaxTimeoutMs) {
      return webdavTransferMaxTimeoutMs;
    }
    if (timeout < webdavTransferMinTimeoutMs) {
      return webdavTransferMinTimeoutMs;
    }
    return timeout;
  }

  // WebDAV transfer directory on the remote server
  static const String remoteTransferDir = 'LightSend';

  // Text file constants
  static const String textFileSuffix = '.lightsend.txt';
  static const String textFilePrefix = 'text_';
  static const int textPreviewMaxLength = 100;

  // Window defaults
  static const double windowWidth = 480;
  static const double windowHeight = 680;
}
