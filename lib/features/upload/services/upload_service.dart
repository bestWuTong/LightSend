import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as wc;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/remote_file_name_helper.dart';
import '../../config/data/models/webdav_config.dart';

typedef UploadProgressCallback = void Function(int count, int total);

class UploadResult {
  final String remoteFileName;

  const UploadResult({required this.remoteFileName});
}

class UploadService {
  wc.Client _createClient(WebdavConfig config, {int? transferSizeBytes}) {
    final client = wc.newClient(
      config.url,
      user: config.account,
      password: config.password,
      debug: false,
    );
    client.setConnectTimeout(AppConstants.webdavConnectTimeoutMs);
    final timeout = transferSizeBytes == null
        ? AppConstants.webdavReceiveTimeoutMs
        : AppConstants.webdavTransferTimeoutMsForBytes(transferSizeBytes);
    client.setSendTimeout(timeout);
    client.setReceiveTimeout(timeout);
    return client;
  }

  Future<UploadResult> upload({
    required String localPath,
    required String remoteFileName,
    required WebdavConfig config,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final localFile = io.File(localPath);
    if (!await localFile.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileSize = await localFile.length();
    final client = _createClient(config, transferSizeBytes: fileSize);
    await client.mkdirAll(AppConstants.remoteTransferDir);

    final finalDisplayName = await _resolveDisplayName(
      client,
      remoteFileName,
      RemoteFileNameHelper.remoteFileNameForUpload,
    );
    final finalRemoteName = RemoteFileNameHelper.remoteFileNameForUpload(
      finalDisplayName,
    );
    final remotePath = '${AppConstants.remoteTransferDir}/$finalRemoteName';
    final uploadPath = _temporaryUploadPath(remotePath);

    try {
      await client.writeFromFile(
        localPath,
        uploadPath,
        onProgress: (count, _) {
          onProgress?.call(count, fileSize);
        },
        cancelToken: cancelToken,
      );

      if (cancelToken?.isCancelled ?? false) {
        throw Exception('已取消');
      }

      await client.rename(uploadPath, remotePath, false);

      if (cancelToken?.isCancelled ?? false) {
        await _deleteRemoteIfExists(config, remotePath);
        throw Exception('已取消');
      }
    } catch (_) {
      await _deleteRemoteIfExists(config, uploadPath);
      rethrow;
    }

    return UploadResult(remoteFileName: finalDisplayName);
  }

  Future<UploadResult> uploadText({
    required String textContent,
    required String remoteFileName,
    required WebdavConfig config,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final bytes = utf8.encode(textContent);
    final fileSize = bytes.length;
    final client = _createClient(config, transferSizeBytes: fileSize);
    await client.mkdirAll(AppConstants.remoteTransferDir);

    final finalDisplayName = await _resolveDisplayName(
      client,
      remoteFileName,
      RemoteFileNameHelper.remoteTextFileNameForUpload,
    );
    final finalRemoteName = RemoteFileNameHelper.remoteTextFileNameForUpload(
      finalDisplayName,
    );
    final remotePath = '${AppConstants.remoteTransferDir}/$finalRemoteName';
    final uploadPath = _temporaryUploadPath(remotePath);

    const steps = 10;
    for (var i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress?.call((fileSize * i / steps).round(), fileSize);
    }

    try {
      await client.write(uploadPath, bytes, cancelToken: cancelToken);

      if (cancelToken?.isCancelled ?? false) {
        throw Exception('已取消');
      }

      await client.rename(uploadPath, remotePath, false);

      if (cancelToken?.isCancelled ?? false) {
        await _deleteRemoteIfExists(config, remotePath);
        throw Exception('已取消');
      }
    } catch (_) {
      await _deleteRemoteIfExists(config, uploadPath);
      rethrow;
    }

    return UploadResult(remoteFileName: finalDisplayName);
  }

  Future<String> _resolveDisplayName(
    wc.Client client,
    String displayName,
    String Function(String displayName) toRemoteName,
  ) async {
    final remoteName = toRemoteName(displayName);
    try {
      await client.readProps('${AppConstants.remoteTransferDir}/$remoteName');
      final duplicate = RemoteFileNameHelper.duplicateDisplayName(displayName);
      return duplicate;
    } catch (_) {
      return displayName;
    }
  }

  String _temporaryUploadPath(String remotePath) {
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '$remotePath.lightsend-uploading-$ts';
  }

  Future<void> _deleteRemoteIfExists(
    WebdavConfig config,
    String remotePath,
  ) async {
    const delays = [
      Duration.zero,
      Duration(milliseconds: 800),
      Duration(seconds: 2),
      Duration(seconds: 5),
    ];

    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future.delayed(delay);
      }

      try {
        final client = _createClient(config);
        await client.remove(remotePath);
      } catch (_) {}
    }
  }

  Future<int> getTotalSize(List<String> paths) async {
    var total = 0;
    for (final path in paths) {
      final file = io.File(path);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }
}
