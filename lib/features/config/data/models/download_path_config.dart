/// Download path configuration.
class DownloadPathConfig {
  final String path;
  final bool isDefault;

  const DownloadPathConfig({
    required this.path,
    this.isDefault = false,
  });

  factory DownloadPathConfig.defaultPath(String path) => DownloadPathConfig(
        path: path,
        isDefault: true,
      );

  DownloadPathConfig copyWith({String? path, bool? isDefault}) {
    return DownloadPathConfig(
      path: path ?? this.path,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'isDefault': isDefault,
      };

  factory DownloadPathConfig.fromJson(Map<String, dynamic> json) {
    return DownloadPathConfig(
      path: json['path'] as String? ?? '',
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }
}
