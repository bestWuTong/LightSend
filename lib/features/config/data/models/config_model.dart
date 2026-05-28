import '../../../../core/encryption/config_encryptor.dart';

import 'webdav_config.dart';
import 'webdav_profile.dart';
import 'download_path_config.dart';

/// Aggregate configuration model for LightSend.
class ConfigModel {
  final WebdavConfig webdav;
  final DownloadPathConfig downloadPath;
  final bool useCustomFont;
  final bool sendToMenuEnabled;
  final List<WebdavProfile> profiles;
  final String? activeProfileId;
  final int seedColor;
  final String themeMode;

  static const int defaultSeedColor = 0xFF4CAF50;
  static const String defaultThemeMode = 'system';

  const ConfigModel({
    required this.webdav,
    required this.downloadPath,
    this.useCustomFont = true,
    this.sendToMenuEnabled = false,
    this.profiles = const [],
    this.activeProfileId,
    this.seedColor = defaultSeedColor,
    this.themeMode = defaultThemeMode,
  });

  factory ConfigModel.defaults() => ConfigModel(
        webdav: WebdavConfig.empty(),
        downloadPath: DownloadPathConfig.defaultPath(''),
        useCustomFont: true,
        sendToMenuEnabled: false,
        seedColor: defaultSeedColor,
        themeMode: defaultThemeMode,
      );

  ConfigModel copyWith({
    WebdavConfig? webdav,
    DownloadPathConfig? downloadPath,
    bool? useCustomFont,
    bool? sendToMenuEnabled,
    List<WebdavProfile>? profiles,
    String? activeProfileId,
    bool clearActiveProfile = false,
    int? seedColor,
    String? themeMode,
  }) {
    return ConfigModel(
      webdav: webdav ?? this.webdav,
      downloadPath: downloadPath ?? this.downloadPath,
      useCustomFont: useCustomFont ?? this.useCustomFont,
      sendToMenuEnabled: sendToMenuEnabled ?? this.sendToMenuEnabled,
      profiles: profiles ?? this.profiles,
      activeProfileId:
          clearActiveProfile ? null : (activeProfileId ?? this.activeProfileId),
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson(ConfigEncryptor encryptor) => {
        'webdav': webdav.toJson(encryptor),
        'downloadPath': downloadPath.toJson(),
        'useCustomFont': useCustomFont,
        'sendToMenuEnabled': sendToMenuEnabled,
        'profiles': profiles.map((p) => p.toJson(encryptor)).toList(),
        'activeProfileId': activeProfileId,
        'seedColor': seedColor,
        'themeMode': themeMode,
      };

  factory ConfigModel.fromJson(
      Map<String, dynamic> json, ConfigEncryptor encryptor) {
    return ConfigModel(
      webdav: json['webdav'] != null
          ? WebdavConfig.fromJson(
              json['webdav'] as Map<String, dynamic>, encryptor)
          : WebdavConfig.empty(),
      downloadPath: json['downloadPath'] != null
          ? DownloadPathConfig.fromJson(
              json['downloadPath'] as Map<String, dynamic>)
          : DownloadPathConfig.defaultPath(''),
      useCustomFont: json['useCustomFont'] as bool? ?? true,
      sendToMenuEnabled: json['sendToMenuEnabled'] as bool? ?? false,
      profiles: (json['profiles'] as List<dynamic>?)
              ?.map((e) =>
                  WebdavProfile.fromJson(e as Map<String, dynamic>, encryptor))
              .toList() ??
          [],
      activeProfileId: json['activeProfileId'] as String?,
      seedColor: json['seedColor'] as int? ?? ConfigModel.defaultSeedColor,
      themeMode: json['themeMode'] as String? ?? ConfigModel.defaultThemeMode,
    );
  }
}
