import 'cloud_file.dart';

/// Status of a download task.
enum DownloadStatus { pending, downloading, completed, failed }

/// Tracks the state of a single file download from WebDAV to local storage.
class DownloadTask {
  final String id;
  final CloudFile cloudFile;
  final String localPath;
  final DownloadStatus status;
  final int bytesDownloaded;
  final double speed;
  final String? error;
  final bool? md5Verified;
  final DateTime createdAt;

  const DownloadTask({
    required this.id,
    required this.cloudFile,
    required this.localPath,
    this.status = DownloadStatus.pending,
    this.bytesDownloaded = 0,
    this.speed = 0,
    this.error,
    this.md5Verified,
    required this.createdAt,
  });

  double get progress {
    if (cloudFile.size <= 0) return 0;
    return (bytesDownloaded / cloudFile.size).clamp(0.0, 1.0);
  }

  String get fileSizeFormatted => cloudFile.sizeFormatted;

  String get speedFormatted {
    if (speed <= 0) return '--/s';
    if (speed < 1024) return '${speed.toStringAsFixed(0)} B/s';
    if (speed < 1024 * 1024) {
      return '${(speed / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${(speed / (1024 * 1024)).toStringAsFixed(1)} MB/s';
  }

  DownloadTask copyWith({
    DownloadStatus? status,
    int? bytesDownloaded,
    double? speed,
    String? error,
    bool? md5Verified,
    bool clearError = false,
  }) {
    return DownloadTask(
      id: id,
      cloudFile: cloudFile,
      localPath: localPath,
      status: status ?? this.status,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      speed: speed ?? this.speed,
      error: clearError ? null : (error ?? this.error),
      md5Verified: md5Verified ?? this.md5Verified,
      createdAt: createdAt,
    );
  }
}
