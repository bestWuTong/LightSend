import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/cache_cleaner.dart';
import '../../../config/config.dart';
import '../../data/models/upload_task.dart';
import '../../services/upload_service.dart';

final uploadServiceProvider = Provider<UploadService>((ref) => UploadService());

/// Manages the list of upload tasks.
final uploadProvider = StateNotifierProvider<UploadNotifier, List<UploadTask>>(
  (ref) => UploadNotifier(ref),
);

class UploadNotifier extends StateNotifier<List<UploadTask>> {
  final Ref _ref;
  CancelToken? _currentCancelToken;
  bool _isUploading = false;

  UploadNotifier(this._ref) : super([]);

  Future<void> addFiles(List<String> paths, {bool autoStart = true}) async {
    final uuid = const Uuid();
    final tasks = <UploadTask>[];

    for (final path in paths) {
      final file = File(path);
      final exists = await file.exists();
      if (!exists) continue;

      final size = await file.length();
      final name = path.split(RegExp(r'[/\\]')).last;
      tasks.add(
        UploadTask(
          id: uuid.v4(),
          type: UploadType.file,
          filePath: path,
          fileName: name,
          fileSize: size,
          createdAt: DateTime.now(),
        ),
      );
    }

    if (tasks.isEmpty) return;

    state = [...state, ...tasks];

    if (autoStart) {
      _startNext();
    }
  }

  Future<void> addText(String text, {bool autoStart = true}) async {
    final uuid = const Uuid();
    final ts = DateTime.now().millisecondsSinceEpoch;
    final fileName =
        '${AppConstants.textFilePrefix}$ts${AppConstants.textFileSuffix}';
    final bytes = utf8.encode(text);

    final task = UploadTask(
      id: uuid.v4(),
      type: UploadType.text,
      textContent: text,
      fileName: fileName,
      fileSize: bytes.length,
      createdAt: DateTime.now(),
    );

    state = [...state, task];

    if (autoStart) {
      _startNext();
    }
  }

  Future<void> _startNext() async {
    if (_isUploading) return;

    final index = state.indexWhere((t) => t.status == UploadStatus.idle);
    if (index < 0) return;

    _isUploading = true;
    final task = state[index];

    await _uploadTask(task);
  }

  Future<void> _uploadTask(UploadTask task) async {
    var config = _ref.read(configProvider).valueOrNull;
    if (config == null) {
      for (var i = 0; i < 30; i++) {
        await Future.delayed(const Duration(milliseconds: 200));
        config = _ref.read(configProvider).valueOrNull;
        if (config != null) break;
      }
    }

    if (config == null || !_isActiveStorageConfigured(config)) {
      _markFailed(task.id, '请先在设置中配置当前云端连接');
      _isUploading = false;
      _startNext();
      return;
    }

    final cancelToken = CancelToken();
    _currentCancelToken = cancelToken;

    _updateStatus(task.id, UploadStatus.uploading);

    try {
      if (config.cloudStorageType == CloudStorageType.oneDrive) {
        await _uploadToOneDrive(task, config, cancelToken);
      } else {
        await _uploadToWebdav(task, config, cancelToken);
      }

      if (cancelToken.isCancelled) return;
      _markCompleted(task.id);
    } catch (e) {
      if (cancelToken.isCancelled) return;
      _markFailed(task.id, '$e');
    } finally {
      _currentCancelToken = null;
      _isUploading = false;
      _startNext();
    }
  }

  bool _isActiveStorageConfigured(ConfigModel config) {
    switch (config.cloudStorageType) {
      case CloudStorageType.oneDrive:
        return config.oneDrive.isConnected;
      case CloudStorageType.webdav:
        return config.webdav.isConfigured;
    }
  }

  Future<void> _uploadToWebdav(
    UploadTask task,
    ConfigModel config,
    CancelToken cancelToken,
  ) async {
    final service = _ref.read(uploadServiceProvider);
    if (task.type == UploadType.file) {
      await service.upload(
        localPath: task.filePath!,
        remoteFileName: task.fileName,
        config: config.webdav,
        onProgress: (count, total) {
          _updateProgress(task.id, count, total);
        },
        cancelToken: cancelToken,
      );
    } else {
      await service.uploadText(
        textContent: task.textContent!,
        remoteFileName: task.fileName,
        config: config.webdav,
        onProgress: (count, total) {
          _updateProgress(task.id, count, total);
        },
        cancelToken: cancelToken,
      );
    }
  }

  Future<void> _uploadToOneDrive(
    UploadTask task,
    ConfigModel config,
    CancelToken cancelToken,
  ) async {
    final service = _ref.read(oneDriveFileServiceProvider);
    final notifier = _ref.read(configProvider.notifier);
    if (task.type == UploadType.file) {
      await service.upload(
        localPath: task.filePath!,
        remoteFileName: task.fileName,
        config: config.oneDrive,
        onConfigUpdated: notifier.updateOneDriveConfig,
        onProgress: (count, total) {
          _updateProgress(task.id, count, total);
        },
        cancelToken: cancelToken,
      );
    } else {
      await service.uploadText(
        textContent: task.textContent!,
        remoteFileName: task.fileName,
        config: config.oneDrive,
        onConfigUpdated: notifier.updateOneDriveConfig,
        onProgress: (count, total) {
          _updateProgress(task.id, count, total);
        },
        cancelToken: cancelToken,
      );
    }
  }

  void _updateStatus(String id, UploadStatus status) {
    state = state
        .map((t) => t.id == id ? t.copyWith(status: status) : t)
        .toList();
  }

  void _updateProgress(String id, int bytesUploaded, int total) {
    final now = DateTime.now();
    state = state.map((t) {
      if (t.id != id) return t;
      final elapsed = now.difference(t.createdAt).inMilliseconds / 1000;
      final speed = elapsed > 0 ? (bytesUploaded / elapsed).toDouble() : 0.0;
      return t.copyWith(
        status: UploadStatus.uploading,
        bytesUploaded: bytesUploaded,
        speed: speed,
      );
    }).toList();
  }

  void _markCompleted(String id) {
    final task = state.firstWhere((t) => t.id == id);
    if (task.type == UploadType.file && task.filePath != null) {
      unawaited(CacheCleaner.deleteIfInCache(task.filePath!));
    }
    state = state.map((t) {
      if (t.id != id) return t;
      return t.copyWith(
        status: UploadStatus.completed,
        bytesUploaded: t.fileSize,
        speed: 0,
      );
    }).toList();
  }

  void _markFailed(String id, String error) {
    state = state.map((t) {
      if (t.id != id) return t;
      return t.copyWith(status: UploadStatus.failed, error: error, speed: 0);
    }).toList();
  }

  void cancelCurrent() {
    UploadTask? activeTask;
    for (final task in state) {
      if (task.status == UploadStatus.uploading) {
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
    final index = state.indexWhere((t) => t.id == id);
    if (index < 0) return;

    state = state.map((t) {
      if (t.id != id) return t;
      return t.copyWith(
        status: UploadStatus.idle,
        bytesUploaded: 0,
        speed: 0,
        error: null,
      );
    }).toList();

    _startNext();
  }

  void remove(String id) {
    if (state.any((t) => t.id == id && t.status == UploadStatus.uploading)) {
      cancelCurrent();
    }
    state = state.where((t) => t.id != id).toList();
    _startNext();
  }

  void clearCompleted() {
    state = state
        .where(
          (t) =>
              t.status != UploadStatus.completed &&
              t.status != UploadStatus.failed,
        )
        .toList();
  }

  void clearAll() {
    cancelCurrent();
    state = [];
  }
}
