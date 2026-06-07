import '../../../../core/encryption/config_encryptor.dart';
import 'cloud_storage_type.dart';
import 'onedrive_config.dart';
import 'webdav_config.dart';

/// A named cloud storage configuration profile.
class CloudProfile {
  final String id;
  final String name;
  final CloudStorageType type;
  final WebdavConfig webdav;
  final OneDriveConfig oneDrive;
  final DateTime createdAt;

  const CloudProfile({
    required this.id,
    required this.name,
    required this.type,
    required this.webdav,
    required this.oneDrive,
    required this.createdAt,
  });

  factory CloudProfile.webdav({
    required String id,
    required String name,
    required WebdavConfig config,
    required DateTime createdAt,
  }) {
    return CloudProfile(
      id: id,
      name: name,
      type: CloudStorageType.webdav,
      webdav: config,
      oneDrive: OneDriveConfig.empty(),
      createdAt: createdAt,
    );
  }

  factory CloudProfile.oneDrive({
    required String id,
    required String name,
    required OneDriveConfig config,
    required DateTime createdAt,
  }) {
    return CloudProfile(
      id: id,
      name: name,
      type: CloudStorageType.oneDrive,
      webdav: WebdavConfig.empty(),
      oneDrive: config,
      createdAt: createdAt,
    );
  }

  bool get isConfigured {
    switch (type) {
      case CloudStorageType.webdav:
        return webdav.isConfigured;
      case CloudStorageType.oneDrive:
        return oneDrive.isConnected;
    }
  }

  CloudProfile copyWith({
    String? name,
    CloudStorageType? type,
    WebdavConfig? webdav,
    OneDriveConfig? oneDrive,
  }) {
    return CloudProfile(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      webdav: webdav ?? this.webdav,
      oneDrive: oneDrive ?? this.oneDrive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson(ConfigEncryptor encryptor) => {
    'id': id,
    'name': name,
    'type': type.storageValue,
    'webdav': webdav.toJson(encryptor),
    'oneDrive': oneDrive.toJson(encryptor),
    'createdAt': createdAt.toIso8601String(),
  };

  factory CloudProfile.fromJson(
    Map<String, dynamic> json,
    ConfigEncryptor encryptor,
  ) {
    final type = CloudStorageType.fromStorageValue(json['type'] as String?);
    final legacyConfig = json['config'];

    return CloudProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      type: type,
      webdav: json['webdav'] != null
          ? WebdavConfig.fromJson(
              json['webdav'] as Map<String, dynamic>,
              encryptor,
            )
          : legacyConfig is Map<String, dynamic>
          ? WebdavConfig.fromJson(legacyConfig, encryptor)
          : WebdavConfig.empty(),
      oneDrive: json['oneDrive'] != null
          ? OneDriveConfig.fromJson(
              json['oneDrive'] as Map<String, dynamic>,
              encryptor,
            )
          : OneDriveConfig.empty(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
