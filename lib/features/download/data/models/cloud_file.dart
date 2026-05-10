/// Represents a file discovered on the WebDAV shared directory.
class CloudFile {
  final String name;
  final int size;
  final String remotePath;
  final DateTime uploadTime;

  const CloudFile({
    required this.name,
    required this.size,
    required this.remotePath,
    required this.uploadTime,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
