import 'dart:io' as io;

import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/utils/path_utils.dart';
import '../../../../features/config/config.dart';
import '../../data/models/cloud_file.dart';
import '../../data/models/download_task.dart';
import '../../services/download_service.dart';

// ─── Infrastructure providers ─────────────────────────────────────────────

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(),
);

/// Reads text content and copies to clipboard
Future<void> copyTextContent(WidgetRef ref, CloudFile file) async {
  final configAsync = ref.read(configProvider);
  final config = configAsync.valueOrNull;
  if (config == null || !config.webdav.isConfigured) return;

  try {
    final service = ref.read(downloadServiceProvider);
    final text = await service.readTextContent(config.webdav, file);
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {
    // Ignore errors
  }
}

// ─── State ────────────────────────────────────────────────────────────────

class DownloadState {
  final List<CloudFile> cloudFiles;
  final List<DownloadTask> tasks;
  final bool isLoading;
  final String? error;

  const DownloadState({
    this.cloudFiles = const [],
    this.tasks = const [],
    this.isLoading = false,
    this.error,
  });

  DownloadState copyWith({
    List<CloudFile>? cloudFiles,
    List<DownloadTask>? tasks,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return DownloadState(
      cloudFiles: cloudFiles ?? this.cloudFiles,
      tasks: tasks ?? this.tasks,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>(
  (ref) => DownloadNotifier(ref),
);

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;
  CancelToken? _currentCancelToken;
  bool _isDownloading = false;

  DownloadNotifier(this._ref) : super(const DownloadState());

  // ─── Cloud file listing ────────────────────────────────────────────────

  Future<void> refreshCloudFiles() async {
    final configAsync = _ref.read(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null || !config.webdav.isConfigured) {
      state = state.copyWith(cloudFiles: [], clearError: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = _ref.read(downloadServiceProvider);
      final files = await service.listCloudFiles(config.webdav);
      state = state.copyWith(cloudFiles: files, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  // ─── Download queue ────────────────────────────────────────────────────

  Future<void> startDownload(CloudFile file) async {
    final configAsync = _ref.read(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null || !config.webdav.isConfigured) return;

    // Check if already queued/downloaded
    final exists = state.tasks.any(
      (t) =>
          t.cloudFile.remotePath == file.remotePath &&
          t.status != DownloadStatus.failed,
    );
    if (exists) return;

    // Resolve local directory
    final localDir = config.downloadPath.path.isNotEmpty
        ? config.downloadPath.path
        : await _defaultDownloadDir();

    final task = DownloadTask(
      id: const Uuid().v4(),
      cloudFile: file,
      localPath: PathUtils.joinPath(localDir, file.name),
      createdAt: DateTime.now(),
    );

    state = state.copyWith(tasks: [task, ...state.tasks]);
    _startNext();
  }

  Future<String> _defaultDownloadDir() async {
    return PathUtils.getDefaultDownloadPath();
  }

  Future<void> _startNext() async {
    if (_isDownloading) return;

    final index = state.tasks.indexWhere(
      (t) => t.status == DownloadStatus.pending,
    );
    if (index < 0) return;

    _isDownloading = true;
    final task = state.tasks[index];
    await _downloadTask(task, index);
  }

  Future<void> _downloadTask(DownloadTask task, int index) async {
    final configAsync = _ref.read(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null || !config.webdav.isConfigured) {
      _markFailed(task.id, 'WebDAV 未配置');
      _isDownloading = false;
      _startNext();
      return;
    }

    final cancelToken = CancelToken();
    _currentCancelToken = cancelToken;

    _updateStatus(task.id, DownloadStatus.downloading);

    final service = _ref.read(downloadServiceProvider);
    try {
      final dir = io.File(task.localPath).parent.path;
      await io.Directory(dir).create(recursive: true);

      final result = await service.download(
        config: config.webdav,
        file: task.cloudFile,
        localDir: dir,
        onProgress: (count, total) {
          _updateProgress(task.id, count, total);
        },
        cancelToken: cancelToken,
      );

      if (cancelToken.isCancelled) return;

      _markCompleted(task.id, result.localPath);
    } catch (e) {
      if (cancelToken.isCancelled) return;
      _markFailed(task.id, '$e');
    } finally {
      _currentCancelToken = null;
      _isDownloading = false;
      _startNext();
    }
  }

  void _updateStatus(String id, DownloadStatus status) {
    state = state.copyWith(
      tasks: state.tasks
          .map((t) => t.id == id ? t.copyWith(status: status) : t)
          .toList(),
    );
  }

  void _updateProgress(String id, int bytesDownloaded, int total) {
    final now = DateTime.now();
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id) return t;
        final elapsed = now.difference(t.createdAt).inMilliseconds / 1000;
        final speed = elapsed > 0
            ? (bytesDownloaded / elapsed).toDouble()
            : 0.0;
        return t.copyWith(
          status: DownloadStatus.downloading,
          bytesDownloaded: bytesDownloaded,
          speed: speed,
        );
      }).toList(),
    );
  }

  void _markCompleted(String id, String localPath) {
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id) return t;
        return t.copyWith(
          localPath: localPath,
          status: DownloadStatus.completed,
          bytesDownloaded: t.cloudFile.size,
          speed: 0,
        );
      }).toList(),
    );
  }

  void _markFailed(String id, String error) {
    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id) return t;
        return t.copyWith(
          status: DownloadStatus.failed,
          error: error,
          speed: 0,
        );
      }).toList(),
    );
  }

  void cancelCurrent() {
    DownloadTask? activeTask;
    for (final task in state.tasks) {
      if (task.status == DownloadStatus.downloading) {
        activeTask = task;
        break;
      }
    }

    _currentCancelToken?.cancel('已取消');

    if (activeTask != null) {
      _markFailed(activeTask.id, '已取消');
    }
  }

  Future<void> retry(String id) async {
    final index = state.tasks.indexWhere((t) => t.id == id);
    if (index < 0) return;

    state = state.copyWith(
      tasks: state.tasks.map((t) {
        if (t.id != id) return t;
        return t.copyWith(
          status: DownloadStatus.pending,
          bytesDownloaded: 0,
          speed: 0,
          error: null,
          clearError: true,
        );
      }).toList(),
    );

    _startNext();
  }

  void remove(String id) {
    if (state.tasks.any(
      (t) => t.id == id && t.status == DownloadStatus.downloading,
    )) {
      cancelCurrent();
    }
    state = state.copyWith(
      tasks: state.tasks.where((t) => t.id != id).toList(),
    );
    _startNext();
  }

  void clearCompleted() {
    state = state.copyWith(
      tasks: state.tasks
          .where(
            (t) =>
                t.status != DownloadStatus.completed &&
                t.status != DownloadStatus.failed,
          )
          .toList(),
    );
  }

  // ─── Cloud file cleanup ──────────────────────────────────────────────

  Future<void> deleteCloudFile(CloudFile file) async {
    final configAsync = _ref.read(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null || !config.webdav.isConfigured) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = _ref.read(downloadServiceProvider);
      await service.deleteCloudFile(config.webdav, file.remotePath);

      // Remove from cloud files list
      state = state.copyWith(
        cloudFiles: state.cloudFiles
            .where((f) => f.remotePath != file.remotePath)
            .toList(),
        isLoading: false,
      );

      // Also remove related download tasks
      state = state.copyWith(
        tasks: state.tasks
            .where((t) => t.cloudFile.remotePath != file.remotePath)
            .toList(),
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '删除失败: $e');
    }
  }

  Future<void> clearAllCloudFiles() async {
    final configAsync = _ref.read(configProvider);
    final config = configAsync.valueOrNull;
    if (config == null || !config.webdav.isConfigured) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = _ref.read(downloadServiceProvider);
      for (final file in state.cloudFiles) {
        try {
          await service.deleteCloudFile(config.webdav, file.remotePath);
        } catch (_) {
          // Continue deleting remaining files even if one fails
        }
      }

      state = state.copyWith(cloudFiles: [], tasks: [], isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '清空失败: $e');
    }
  }

  void clearAll() {
    cancelCurrent();
    state = state.copyWith(tasks: []);
  }
}
