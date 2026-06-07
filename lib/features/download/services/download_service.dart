import 'dart:convert';
import 'dart:io' as io;

import 'package:webdav_client/webdav_client.dart' as wc;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/path_utils.dart';
import '../../../core/utils/remote_file_name_helper.dart';
import '../../../features/config/config.dart';
import '../data/models/cloud_file.dart';

/// Result of a download operation.
class DownloadResult {
  final String localPath;

  const DownloadResult({required this.localPath});
}

/// Lists and downloads files from WebDAV shared directory.
class DownloadService {
  wc.Client _createClient(WebdavConfig config, {int? transferSizeBytes}) {
    final client = wc.newClient(
      config.url,
      user: config.account,
      password: config.password,
      debug: false,
    );
    client.setConnectTimeout(AppConstants.webdavConnectTimeoutMs);
    client.setReceiveTimeout(
      transferSizeBytes == null
          ? AppConstants.webdavReceiveTimeoutMs
          : AppConstants.webdavTransferTimeoutMsForBytes(transferSizeBytes),
    );
    return client;
  }

  /// Lists all files in the shared WebDAV directory.
  Future<List<CloudFile>> listCloudFiles(WebdavConfig config) async {
    if (!config.isConfigured) return [];

    final client = _createClient(config);
    await client.mkdirAll(AppConstants.remoteTransferDir);
    final entries = await client.readDir(AppConstants.remoteTransferDir);

    final files = entries
        .where((e) => !(e.isDir ?? false))
        .map((e) {
          final remoteName = e.name ?? '';
          return CloudFile(
            name: RemoteFileNameHelper.displayName(remoteName),
            size: e.size ?? 0,
            remotePath: e.path ?? remoteName,
            uploadTime: e.mTime ?? DateTime.now(),
            isTextMessage: RemoteFileNameHelper.isRemoteTextFileName(
              remoteName,
            ),
          );
        })
        .where((f) => f.name.isNotEmpty)
        .toList();

    files.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    return files;
  }

  /// Reads text content from a file on WebDAV.
  Future<String> readTextContent(WebdavConfig config, CloudFile file) async {
    final client = _createClient(config, transferSizeBytes: file.size);
    final bytes = await client.read(file.remotePath);
    return utf8.decode(bytes);
  }

  /// Downloads a file from WebDAV.
  Future<DownloadResult> download({
    required WebdavConfig config,
    required CloudFile file,
    required String localDir,
    void Function(int count, int total)? onProgress,
    dynamic cancelToken,
  }) async {
    final client = _createClient(config, transferSizeBytes: file.size);

    final baseName = file.name;
    final localPath = _resolveLocalPath(localDir, baseName);

    try {
      await client.read2File(
        file.remotePath,
        localPath,
        onProgress: (count, total) => onProgress?.call(count, total),
        cancelToken: cancelToken,
      );
    } catch (_) {
      await _deleteLocalIfExists(localPath);
      rethrow;
    }

    return DownloadResult(localPath: localPath);
  }

  String _resolveLocalPath(String dir, String fileName) {
    final path = PathUtils.joinPath(dir, fileName);
    if (!io.File(path).existsSync()) return path;

    final dot = fileName.lastIndexOf('.');
    final name = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return PathUtils.joinPath(dir, '${name}_$ts$ext');
  }

  /// Deletes a file from the WebDAV server.
  Future<void> deleteCloudFile(WebdavConfig config, String remotePath) async {
    if (!config.isConfigured) return;
    final client = _createClient(config);
    await client.remove(remotePath);
  }

  Future<void> _deleteLocalIfExists(String localPath) async {
    try {
      final file = io.File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
