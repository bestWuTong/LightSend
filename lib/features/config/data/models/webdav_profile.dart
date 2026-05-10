import '../../../../core/encryption/config_encryptor.dart';
import 'webdav_config.dart';

/// A named, saved WebDAV configuration profile.
class WebdavProfile {
  final String id;
  final String name;
  final WebdavConfig config;
  final DateTime createdAt;

  const WebdavProfile({
    required this.id,
    required this.name,
    required this.config,
    required this.createdAt,
  });

  WebdavProfile copyWith({
    String? name,
    WebdavConfig? config,
  }) {
    return WebdavProfile(
      id: id,
      name: name ?? this.name,
      config: config ?? this.config,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson(ConfigEncryptor encryptor) => {
        'id': id,
        'name': name,
        'config': config.toJson(encryptor),
        'createdAt': createdAt.toIso8601String(),
      };

  factory WebdavProfile.fromJson(
      Map<String, dynamic> json, ConfigEncryptor encryptor) {
    return WebdavProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      config: WebdavConfig.fromJson(
          json['config'] as Map<String, dynamic>, encryptor),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
