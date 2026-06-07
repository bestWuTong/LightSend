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

final downloadServiceProvider = Provider<DownloadService>(
  (ref) => DownloadService(),
);

Future<void> copyTextContent(WidgetRef ref, CloudFile file) async {
  final config = ref.read(configProvider).valueOrNull;
  if (config == null || !_isActiveStorageConfigured(config)) return;

  try {
    final text = await _readTextContent(ref, config, file);
    await Clipboard.setData(ClipboardData(text: text));
  } catch (_) {}
}

Future<String> readCloudTextContent(WidgetRef ref, CloudFile file) async {
  final config = ref.read(configProvider).valueOrNull;
  if (config == null || !_isActiveStorageConfigured(config)) {
    throw Exception('当前云端未配置');
  }
  return _readTextContent(ref, config, file);
}

Future<String> _readTextContent(
  WidgetRef ref,
  ConfigModel config,
  CloudFile file,
) async {
  if (config.cloudStorageType == CloudStorageType.oneDrive) {
    return ref
        .read(oneDriveFileServiceProvider)
        .readTextContent(
          config: config.oneDrive,
          file: file,
          onConfigUpdated: ref
              .read(configProvider.notifier)
              .updateOneDriveConfig,
        );
  }

  return ref.read(downloadServiceProvider).readTextContent(config.webdav, file);
}

bool _isActiveStorageConfigured(ConfigModel config) {
  switch (config.cloudStorageType) {
    case CloudStorageType.oneDrive:
      return config.oneDrive.isConnected;
    case CloudStorageType.webdav:
      return config.webdav.isConfigured;
  }
}

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

final downloadProvider = StateNotifierProvider<DownloadNotifier, DownloadState>(
  (ref) => DownloadNotifier(ref),
);

class DownloadNotifier extends StateNotifier<DownloadState> {
  final Ref _ref;
  CancelToken? _currentCancelToken;
  bool _isDownloading = false;

  DownloadNotifier(this._ref) : super(const DownloadState());

  Future<void> refreshCloudFiles() async {
    final config = _ref.read(configProvider).valueOrNull;
    if (config == null || !_isActiveStorageConfigured(config)) {
      state = state.copyWith(cloudFiles: [], clearError: true);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final files = config.cloudStorageType == CloudStorageType.oneDrive
          ? await _ref
                .read(oneDriveFileServiceProvider)
                .listCloudFiles(
                  config: config.oneDrive,
                  onConfigUpdated: _ref
                      .read(configProvider.notifier)
                      .updateOneDriveConfig,
                )
          : await _ref
                .read(downloadServiceProvider)
                .listCloudFiles(config.webdav);
      state = state.copyWith(cloudFiles: files, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: '$e');
    }
  }

  Future<void> startDownload(CloudFile file) async {
    final config = _ref.read(configProvider).valueOrNull;
    if (config == null || !_isActiveStorageConfigured(config)) return;

    final exists = state.tasks.any(
      (t) =>
          t.cloudFile.remotePath == file.remotePath &&
          t.status != DownloadStatus.failed,
    );
    if (exists) return;

    final localDir = config.downloadPath.path.isNotEmpty
        ? config.downloadPath.path
        : await PathUtils.getDefaultDownloadPath();

    final task = DownloadTask(
      id: const Uuid().v4(),
      cloudFile: file,
      localPath: PathUtils.joinPath(localDir, file.name),
      createdAt: DateTime.now(),
    );

    state = state.copyWith(tasks: [task, ...state.tasks]);
    _startNext();
  }

  Future<void> _startNext() async {
    if (_isDownloading) return;

    final index = state.tasks.indexWhere(
      (t) => t.status == DownloadStatus.pending,
    );
    if (index < 0) return;

    _isDownloading = true;
    final task = state.tasks[index];
    await _downloadTask(task);
  }

  Future<void> _downloadTask(DownloadTask task) async {
    final config = _ref.read(configProvider).valueOrNull;
    if (config == null || !_isActiveStorageConfigured(config)) {
      _markFailed(task.id, '当前云端未配置');
      _isDownloading = false;
      _startNext();
      return;
    }

    final cancelToken = CancelToken();
    _currentCancelToken = cancelToken;

    _updateStatus(task.id, DownloadStatus.downloading);

    try {
      final dir = io.File(task.localPath).parent.path;
      await io.Directory(dir).create(recursive: true);

      final result = config.cloudStorageType == CloudStorageType.oneDrive
          ? await _ref
                .read(oneDriveFileServiceProvider)
                .download(
                  config: config.oneDrive,
                  file: task.cloudFile,
                  localDir: dir,
                  onConfigUpdated: _ref
                      .read(configProvider.notifier)
                      .updateOneDriveConfig,
                  onProgress: (count, total) {
                    _updateProgress(task.id, count, total);
                  },
                  cancelToken: cancelToken,
                )
          : await _ref
                .read(downloadServiceProvider)
                .download(
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

  Future<void> deleteCloudFile(CloudFile file) async {
    final config = _ref.read(configProvider).valueOrNull;
    if (config == null || !_isActiveStorageConfigured(config)) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      if (config.cloudStorageType == CloudStorageType.oneDrive) {
        await _ref
            .read(oneDriveFileServiceProvider)
            .deleteCloudFile(
              config: config.oneDrive,
              itemId: file.remotePath,
              onConfigUpdated: _ref
                  .read(configProvider.notifier)
                  .updateOneDriveConfig,
            );
      } else {
        await _ref
            .read(downloadServiceProvider)
            .deleteCloudFile(config.webdav, file.remotePath);
      }

      state = state.copyWith(
        cloudFiles: state.cloudFiles
            .where((f) => f.remotePath != file.remotePath)
            .toList(),
        isLoading: false,
      );

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
    final config = _ref.read(configProvider).valueOrNull;
    if (config == null || !_isActiveStorageConfigured(config)) return;

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      for (final file in state.cloudFiles) {
        try {
          if (config.cloudStorageType == CloudStorageType.oneDrive) {
            await _ref
                .read(oneDriveFileServiceProvider)
                .deleteCloudFile(
                  config: config.oneDrive,
                  itemId: file.remotePath,
                  onConfigUpdated: _ref
                      .read(configProvider.notifier)
                      .updateOneDriveConfig,
                );
          } else {
            await _ref
                .read(downloadServiceProvider)
                .deleteCloudFile(config.webdav, file.remotePath);
          }
        } catch (_) {}
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
