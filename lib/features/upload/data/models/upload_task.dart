/// Upload task status.
enum UploadStatus {
  idle,
  uploading,
  completed,
  failed,
}

/// Represents a single file upload task.
class UploadTask {
  final String id;
  final String filePath;
  final String fileName;
  final int fileSize;
  final UploadStatus status;
  final int bytesUploaded;
  final double speed; // bytes per second
  final String? error;
  final DateTime createdAt;

  const UploadTask({
    required this.id,
    required this.filePath,
    required this.fileName,
    required this.fileSize,
    this.status = UploadStatus.idle,
    this.bytesUploaded = 0,
    this.speed = 0,
    this.error,
    required this.createdAt,
  });

  double get progress =>
      fileSize > 0 ? bytesUploaded / fileSize : 0;

  String get fileSizeFormatted => _formatSize(fileSize);

  String get speedFormatted => _formatSpeed(speed);

  UploadTask copyWith({
    String? id,
    String? filePath,
    String? fileName,
    int? fileSize,
    UploadStatus? status,
    int? bytesUploaded,
    double? speed,
    String? error,
    DateTime? createdAt,
  }) {
    return UploadTask(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      fileName: fileName ?? this.fileName,
      fileSize: fileSize ?? this.fileSize,
      status: status ?? this.status,
      bytesUploaded: bytesUploaded ?? this.bytesUploaded,
      speed: speed ?? this.speed,
      error: error,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  static String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec < 1024) return '${bytesPerSec.toStringAsFixed(0)} B/s';
    if (bytesPerSec < 1024 * 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }
}
