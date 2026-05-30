import 'dart:convert';
import 'dart:io' as io;

import 'package:dio/dio.dart';
import 'package:webdav_client/webdav_client.dart' as wc;

import '../../config/data/models/webdav_config.dart';
import '../../../core/constants/app_constants.dart';

/// Upload progress callback.
typedef UploadProgressCallback = void Function(int count, int total);

/// Result returned after a successful upload.
class UploadResult {
  final String remoteFileName;

  const UploadResult({required this.remoteFileName});
}

/// Service for uploading files or text to WebDAV shared directory.
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

  /// Uploads a local file to the WebDAV server under the shared directory.
  /// Returns the final remote file name.
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

    // Check for duplicate filename on server
    String finalName = remoteFileName;
    try {
      // Try to read props — if it succeeds, file exists, add timestamp
      await client.readProps(
        '${AppConstants.remoteTransferDir}/$remoteFileName',
      );
      final dot = remoteFileName.lastIndexOf('.');
      final name = dot > 0 ? remoteFileName.substring(0, dot) : remoteFileName;
      final ext = dot > 0 ? remoteFileName.substring(dot) : '';
      final ts = DateTime.now().millisecondsSinceEpoch;
      finalName = '${name}_$ts$ext';
    } catch (_) {
      // File doesn't exist — use original name
    }

    final remotePath = '${AppConstants.remoteTransferDir}/$finalName';
    final totalSize = fileSize;

    // Upload file
    await client.writeFromFile(
      localPath,
      remotePath,
      onProgress: (count, _) {
        onProgress?.call(count, totalSize);
      },
      cancelToken: cancelToken,
    );

    return UploadResult(remoteFileName: finalName);
  }

  /// Uploads text content to the WebDAV server under the shared directory.
  /// Returns the final remote file name.
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

    // Check for duplicate filename on server
    String finalName = remoteFileName;
    try {
      // Try to read props — if it succeeds, file exists, add timestamp
      await client.readProps(
        '${AppConstants.remoteTransferDir}/$remoteFileName',
      );
      final dot = remoteFileName.lastIndexOf('.');
      final name = dot > 0 ? remoteFileName.substring(0, dot) : remoteFileName;
      final ext = dot > 0 ? remoteFileName.substring(dot) : '';
      final ts = DateTime.now().millisecondsSinceEpoch;
      finalName = '${name}_$ts$ext';
    } catch (_) {
      // File doesn't exist — use original name
    }

    final remotePath = '${AppConstants.remoteTransferDir}/$finalName';
    final totalSize = fileSize;

    // Simulate progress steps for text upload
    const steps = 10;
    for (int i = 1; i <= steps; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
      onProgress?.call((totalSize * i / steps).round(), totalSize);
    }

    // Upload text content
    await client.write(remotePath, bytes, cancelToken: cancelToken);

    return UploadResult(remoteFileName: finalName);
  }

  Future<int> getTotalSize(List<String> paths) async {
    int total = 0;
    for (final path in paths) {
      final file = io.File(path);
      if (await file.exists()) {
        total += await file.length();
      }
    }
    return total;
  }
}
