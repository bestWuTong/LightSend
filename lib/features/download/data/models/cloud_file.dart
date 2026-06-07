/// Represents a file discovered on the active cloud backend.
class CloudFile {
  /// Display/local filename. Managed remote suffixes are stripped before this
  /// value is stored.
  final String name;
  final int size;
  final String remotePath;
  final DateTime uploadTime;
  final bool isTextMessage;

  const CloudFile({
    required this.name,
    required this.size,
    required this.remotePath,
    required this.uploadTime,
    this.isTextMessage = false,
  });

  bool get isTextFile => isTextMessage;

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
