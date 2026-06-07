import '../../../../core/encryption/config_encryptor.dart';

import 'webdav_config.dart';
import 'cloud_profile.dart';
import 'download_path_config.dart';
import 'cloud_storage_type.dart';
import 'onedrive_config.dart';

/// Aggregate configuration model for LightSend.
class ConfigModel {
  final WebdavConfig webdav;
  final OneDriveConfig oneDrive;
  final CloudStorageType cloudStorageType;
  final DownloadPathConfig downloadPath;
  final bool sendToMenuEnabled;
  final List<CloudProfile> profiles;
  final String? activeProfileId;
  final int seedColor;
  final String themeMode;

  static const int defaultSeedColor = 0xFF00BCD4;
  static const String defaultThemeMode = 'system';

  const ConfigModel({
    required this.webdav,
    required this.oneDrive,
    required this.cloudStorageType,
    required this.downloadPath,
    this.sendToMenuEnabled = false,
    this.profiles = const [],
    this.activeProfileId,
    this.seedColor = defaultSeedColor,
    this.themeMode = defaultThemeMode,
  });

  factory ConfigModel.defaults() => ConfigModel(
    webdav: WebdavConfig.empty(),
    oneDrive: OneDriveConfig.empty(),
    cloudStorageType: CloudStorageType.webdav,
    downloadPath: DownloadPathConfig.defaultPath(''),
    sendToMenuEnabled: false,
    seedColor: defaultSeedColor,
    themeMode: defaultThemeMode,
  );

  ConfigModel copyWith({
    WebdavConfig? webdav,
    OneDriveConfig? oneDrive,
    CloudStorageType? cloudStorageType,
    DownloadPathConfig? downloadPath,
    bool? sendToMenuEnabled,
    List<CloudProfile>? profiles,
    String? activeProfileId,
    bool clearActiveProfile = false,
    int? seedColor,
    String? themeMode,
  }) {
    return ConfigModel(
      webdav: webdav ?? this.webdav,
      oneDrive: oneDrive ?? this.oneDrive,
      cloudStorageType: cloudStorageType ?? this.cloudStorageType,
      downloadPath: downloadPath ?? this.downloadPath,
      sendToMenuEnabled: sendToMenuEnabled ?? this.sendToMenuEnabled,
      profiles: profiles ?? this.profiles,
      activeProfileId: clearActiveProfile
          ? null
          : (activeProfileId ?? this.activeProfileId),
      seedColor: seedColor ?? this.seedColor,
      themeMode: themeMode ?? this.themeMode,
    );
  }

  Map<String, dynamic> toJson(ConfigEncryptor encryptor) => {
    'webdav': webdav.toJson(encryptor),
    'oneDrive': oneDrive.toJson(encryptor),
    'cloudStorageType': cloudStorageType.storageValue,
    'downloadPath': downloadPath.toJson(),
    'sendToMenuEnabled': sendToMenuEnabled,
    'profiles': profiles.map((p) => p.toJson(encryptor)).toList(),
    'activeProfileId': activeProfileId,
    'seedColor': seedColor,
    'themeMode': themeMode,
  };

  factory ConfigModel.fromJson(
    Map<String, dynamic> json,
    ConfigEncryptor encryptor,
  ) {
    return ConfigModel(
      webdav: json['webdav'] != null
          ? WebdavConfig.fromJson(
              json['webdav'] as Map<String, dynamic>,
              encryptor,
            )
          : WebdavConfig.empty(),
      oneDrive: json['oneDrive'] != null
          ? OneDriveConfig.fromJson(
              json['oneDrive'] as Map<String, dynamic>,
              encryptor,
            )
          : OneDriveConfig.empty(),
      cloudStorageType: CloudStorageType.fromStorageValue(
        json['cloudStorageType'] as String?,
      ),
      downloadPath: json['downloadPath'] != null
          ? DownloadPathConfig.fromJson(
              json['downloadPath'] as Map<String, dynamic>,
            )
          : DownloadPathConfig.defaultPath(''),
      sendToMenuEnabled: json['sendToMenuEnabled'] as bool? ?? false,
      profiles:
          (json['profiles'] as List<dynamic>?)
              ?.map(
                (e) =>
                    CloudProfile.fromJson(e as Map<String, dynamic>, encryptor),
              )
              .toList() ??
          [],
      activeProfileId: json['activeProfileId'] as String?,
      seedColor: json['seedColor'] as int? ?? ConfigModel.defaultSeedColor,
      themeMode: json['themeMode'] as String? ?? ConfigModel.defaultThemeMode,
    );
  }
}
