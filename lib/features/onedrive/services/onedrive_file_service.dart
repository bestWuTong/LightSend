import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/path_utils.dart';
import '../../../core/utils/remote_file_name_helper.dart';
import '../../config/data/models/onedrive_config.dart';
import '../../download/data/models/cloud_file.dart';
import '../../download/services/download_service.dart';
import '../../upload/services/upload_service.dart';
import 'onedrive_auth_service.dart';

class OneDriveFileService {
  final OneDriveAuthService _authService;
  final Dio _dio;

  OneDriveFileService(this._authService, {Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(minutes: 30),
              sendTimeout: const Duration(minutes: 30),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  Future<List<CloudFile>> listCloudFiles({
    required OneDriveConfig config,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
  }) async {
    if (!config.isConnected) return [];

    final token = await _accessToken(config, onConfigUpdated);
    final files = <CloudFile>[];
    String? url =
        '${AppConstants.oneDriveGraphBaseUrl}/me/drive/special/approot/children';
    Map<String, dynamic>? query = {
      r'$select': 'id,name,size,lastModifiedDateTime,file,folder',
      r'$top': '200',
    };

    while (url != null) {
      final response = await _dio.get<Map<String, dynamic>>(
        url,
        queryParameters: query,
        options: Options(headers: _authHeaders(token)),
      );
      _throwIfGraphError(response);

      final body = response.data ?? const <String, dynamic>{};
      final values = body['value'] as List<dynamic>? ?? const [];
      for (final item in values) {
        if (item is! Map<String, dynamic>) continue;
        if (item['folder'] != null) continue;
        final id = item['id'] as String?;
        final name = item['name'] as String?;
        if (id == null || id.isEmpty || name == null || name.isEmpty) {
          continue;
        }
        files.add(
          CloudFile(
            name: RemoteFileNameHelper.displayName(name),
            size: _asInt(item['size']),
            remotePath: id,
            uploadTime: _parseGraphDate(item['lastModifiedDateTime']),
            isTextMessage: RemoteFileNameHelper.isRemoteTextFileName(name),
          ),
        );
      }

      url = body['@odata.nextLink'] as String?;
      query = null;
    }

    files.sort((a, b) => b.uploadTime.compareTo(a.uploadTime));
    return files;
  }

  Future<void> testConnection({
    required OneDriveConfig config,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
  }) async {
    final token = await _accessToken(config, onConfigUpdated);
    final response = await _dio.get<Map<String, dynamic>>(
      '${AppConstants.oneDriveGraphBaseUrl}/me/drive/special/approot',
      queryParameters: {r'$select': 'id,name'},
      options: Options(headers: _authHeaders(token)),
    );
    _throwIfGraphError(response);
  }

  Future<String> readTextContent({
    required OneDriveConfig config,
    required CloudFile file,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
  }) async {
    final token = await _accessToken(config, onConfigUpdated);
    final response = await _dio.get<List<int>>(
      _itemContentUrl(file.remotePath),
      options: Options(
        headers: _authHeaders(token),
        responseType: ResponseType.bytes,
      ),
    );
    _throwIfGraphError(response);
    return utf8.decode(response.data ?? const []);
  }

  Future<DownloadResult> download({
    required OneDriveConfig config,
    required CloudFile file,
    required String localDir,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
    void Function(int count, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final token = await _accessToken(config, onConfigUpdated);
    final localPath = _resolveLocalPath(localDir, file.name);

    try {
      await _dio.download(
        _itemContentUrl(file.remotePath),
        localPath,
        options: Options(headers: _authHeaders(token)),
        onReceiveProgress: (count, total) {
          onProgress?.call(count, total > 0 ? total : file.size);
        },
        cancelToken: cancelToken,
      );
    } catch (_) {
      await _deleteLocalIfExists(localPath);
      rethrow;
    }

    return DownloadResult(localPath: localPath);
  }

  Future<void> deleteCloudFile({
    required OneDriveConfig config,
    required String itemId,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
  }) async {
    final token = await _accessToken(config, onConfigUpdated);
    final response = await _dio.delete<void>(
      _itemUrl(itemId),
      options: Options(headers: _authHeaders(token)),
    );
    _throwIfGraphError(response);
  }

  Future<UploadResult> upload({
    required String localPath,
    required String remoteFileName,
    required OneDriveConfig config,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final localFile = io.File(localPath);
    if (!await localFile.exists()) {
      throw Exception('文件不存在: $localPath');
    }

    final fileSize = await localFile.length();
    final token = await _accessToken(config, onConfigUpdated);
    final finalDisplayName = await _resolveRemoteName(
      token,
      remoteFileName,
      RemoteFileNameHelper.remoteFileNameForUpload,
    );
    final finalName = RemoteFileNameHelper.remoteFileNameForUpload(
      finalDisplayName,
    );

    if (fileSize <= 4 * 1024 * 1024) {
      final bytes = await localFile.readAsBytes();
      final uploadedName = await _simpleUpload(
        token: token,
        remoteFileName: finalName,
        bytes: bytes,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );
      return UploadResult(
        remoteFileName: RemoteFileNameHelper.displayName(uploadedName),
      );
    }

    final uploadedName = await _sessionUploadFile(
      token: token,
      localFile: localFile,
      remoteFileName: finalName,
      fileSize: fileSize,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return UploadResult(
      remoteFileName: RemoteFileNameHelper.displayName(uploadedName),
    );
  }

  Future<UploadResult> uploadText({
    required String textContent,
    required String remoteFileName,
    required OneDriveConfig config,
    required Future<void> Function(OneDriveConfig updated) onConfigUpdated,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final bytes = Uint8List.fromList(utf8.encode(textContent));
    final token = await _accessToken(config, onConfigUpdated);
    final finalDisplayName = await _resolveRemoteName(
      token,
      remoteFileName,
      RemoteFileNameHelper.remoteTextFileNameForUpload,
    );
    final finalName = RemoteFileNameHelper.remoteTextFileNameForUpload(
      finalDisplayName,
    );
    final uploadedName = await _simpleUpload(
      token: token,
      remoteFileName: finalName,
      bytes: bytes,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return UploadResult(
      remoteFileName: RemoteFileNameHelper.displayName(uploadedName),
    );
  }

  Future<String> _simpleUpload({
    required String token,
    required String remoteFileName,
    required Uint8List bytes,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final response = await _dio.put<Map<String, dynamic>>(
      _approotContentPathUrl(remoteFileName),
      data: bytes,
      options: Options(
        headers: {
          ..._authHeaders(token),
          Headers.contentLengthHeader: bytes.length,
        },
        contentType: 'application/octet-stream',
      ),
      onSendProgress: (count, total) {
        onProgress?.call(count, total > 0 ? total : bytes.length);
      },
      cancelToken: cancelToken,
    );
    _throwIfGraphError(response);
    onProgress?.call(bytes.length, bytes.length);
    return response.data?['name'] as String? ?? remoteFileName;
  }

  Future<String> _sessionUploadFile({
    required String token,
    required io.File localFile,
    required String remoteFileName,
    required int fileSize,
    UploadProgressCallback? onProgress,
    CancelToken? cancelToken,
  }) async {
    final sessionResponse = await _dio.post<Map<String, dynamic>>(
      _approotCreateSessionUrl(remoteFileName),
      data: {
        'item': {
          '@microsoft.graph.conflictBehavior': 'replace',
          'name': remoteFileName,
        },
      },
      options: Options(headers: _authHeaders(token)),
      cancelToken: cancelToken,
    );
    _throwIfGraphError(sessionResponse);

    final uploadUrl = sessionResponse.data?['uploadUrl'] as String?;
    if (uploadUrl == null || uploadUrl.isEmpty) {
      throw Exception('OneDrive 上传会话创建失败');
    }

    final file = await localFile.open();
    Map<String, dynamic>? finalItem;
    try {
      var offset = 0;
      while (offset < fileSize) {
        if (cancelToken?.isCancelled ?? false) {
          throw Exception('已取消');
        }

        final remaining = fileSize - offset;
        final chunkSize = remaining < AppConstants.oneDriveChunkSizeBytes
            ? remaining
            : AppConstants.oneDriveChunkSizeBytes;
        await file.setPosition(offset);
        final chunk = await file.read(chunkSize);
        final end = offset + chunk.length - 1;

        final response = await _dio.put<Map<String, dynamic>>(
          uploadUrl,
          data: chunk,
          options: Options(
            headers: {
              Headers.contentLengthHeader: chunk.length,
              'Content-Range': 'bytes $offset-$end/$fileSize',
            },
            contentType: 'application/octet-stream',
          ),
          onSendProgress: (count, _) {
            onProgress?.call(offset + count, fileSize);
          },
          cancelToken: cancelToken,
        );
        _throwIfGraphError(response);

        if ((response.statusCode ?? 0) == 200 ||
            (response.statusCode ?? 0) == 201) {
          finalItem = response.data;
        }

        offset += chunk.length;
        onProgress?.call(offset, fileSize);
      }
    } catch (_) {
      await _cancelUploadSession(uploadUrl);
      rethrow;
    } finally {
      await file.close();
    }

    return finalItem?['name'] as String? ?? remoteFileName;
  }

  Future<String> _resolveRemoteName(
    String token,
    String displayName,
    String Function(String displayName) toRemoteName,
  ) async {
    final remoteFileName = toRemoteName(displayName);
    final exists = await _remoteFileExists(token, remoteFileName);
    if (!exists) return displayName;

    return RemoteFileNameHelper.duplicateDisplayName(displayName);
  }

  Future<bool> _remoteFileExists(String token, String remoteFileName) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _approotItemPathUrl(remoteFileName),
      options: Options(headers: _authHeaders(token)),
    );
    final code = response.statusCode ?? 0;
    if (code == 404) return false;
    _throwIfGraphError(response);
    return code >= 200 && code < 300;
  }

  Future<void> _cancelUploadSession(String uploadUrl) async {
    try {
      await _dio.delete<void>(uploadUrl);
    } catch (_) {}
  }

  Future<String> _accessToken(
    OneDriveConfig config,
    Future<void> Function(OneDriveConfig updated) onConfigUpdated,
  ) {
    return _authService.getValidAccessToken(config, onRefresh: onConfigUpdated);
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
  };

  String _itemUrl(String itemId) {
    return '${AppConstants.oneDriveGraphBaseUrl}/me/drive/items/$itemId';
  }

  String _itemContentUrl(String itemId) {
    return '${_itemUrl(itemId)}/content';
  }

  String _approotItemPathUrl(String fileName) {
    return '${AppConstants.oneDriveGraphBaseUrl}/me/drive/special/approot:/${Uri.encodeComponent(fileName)}';
  }

  String _approotContentPathUrl(String fileName) {
    return '${_approotItemPathUrl(fileName)}:/content';
  }

  String _approotCreateSessionUrl(String fileName) {
    return '${_approotItemPathUrl(fileName)}:/createUploadSession';
  }

  void _throwIfGraphError(Response<dynamic> response) {
    final code = response.statusCode ?? 0;
    if (code < 400) return;

    final data = response.data;
    if (data is Map<String, dynamic>) {
      final error = data['error'];
      if (error is Map<String, dynamic>) {
        throw Exception(error['message'] as String? ?? 'OneDrive 请求失败');
      }
    }
    throw Exception('OneDrive 请求失败 (HTTP $code)');
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  DateTime _parseGraphDate(dynamic value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
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

  Future<void> _deleteLocalIfExists(String localPath) async {
    try {
      final file = io.File(localPath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
