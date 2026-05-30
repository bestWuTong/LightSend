import 'dart:convert';
import 'dart:io' as io;

import 'package:webdav_client/webdav_client.dart' as wc;

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/checksum_utils.dart';
import '../../../features/config/config.dart';
import '../data/models/cloud_file.dart';

/// Result of a download operation.
class DownloadResult {
  final String localPath;
  final bool md5Verified;

  const DownloadResult({required this.localPath, required this.md5Verified});
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

  /// Lists all files in the shared WebDAV directory (excludes .md5 files).
  Future<List<CloudFile>> listCloudFiles(WebdavConfig config) async {
    if (!config.isConfigured) return [];

    final client = _createClient(config);
    await client.mkdirAll(AppConstants.remoteTransferDir);
    final entries = await client.readDir(AppConstants.remoteTransferDir);

    final files = entries
        .where((e) => !(e.isDir ?? false) && !(e.name ?? '').endsWith('.md5'))
        .map(
          (e) => CloudFile(
            name: e.name ?? '',
            size: e.size ?? 0,
            remotePath: e.path ?? (e.name ?? ''),
            uploadTime: e.mTime ?? DateTime.now(),
          ),
        )
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

  /// Downloads a file from WebDAV and verifies its MD5 checksum.
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

    await client.read2File(
      file.remotePath,
      localPath,
      onProgress: (count, total) => onProgress?.call(count, total),
      cancelToken: cancelToken,
    );

    // Verify MD5 if companion file exists
    bool md5Match = false;
    try {
      final md5Bytes = await client.read('${file.remotePath}.md5');
      final expectedMd5 = utf8.decode(md5Bytes).trim();
      final actualMd5 = await ChecksumUtils.md5File(localPath);
      md5Match = expectedMd5 == actualMd5;
    } catch (_) {
      // No .md5 file or read error — skip verification
      md5Match = false;
    }

    return DownloadResult(localPath: localPath, md5Verified: md5Match);
  }

  String _resolveLocalPath(String dir, String fileName) {
    final path = '$dir/$fileName';
    if (!io.File(path).existsSync()) return path;

    final dot = fileName.lastIndexOf('.');
    final name = dot > 0 ? fileName.substring(0, dot) : fileName;
    final ext = dot > 0 ? fileName.substring(dot) : '';
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '$dir/${name}_$ts$ext';
  }

  /// Deletes a file from the WebDAV server.
  Future<void> deleteCloudFile(WebdavConfig config, String remotePath) async {
    if (!config.isConfigured) return;
    final client = _createClient(config);
    await client.remove(remotePath);
    // Also delete the .md5 companion file
    try {
      await client.remove('$remotePath.md5');
    } catch (_) {}
  }
}
