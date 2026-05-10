import 'dart:convert';

import 'package:dio/dio.dart';

import '../data/models/webdav_config.dart';
import '../../../core/constants/app_constants.dart';

/// Result of a WebDAV connection test.
class WebdavTestResult {
  final bool isSuccess;
  final String? message;

  const WebdavTestResult({required this.isSuccess, this.message});

  factory WebdavTestResult.success() =>
      const WebdavTestResult(isSuccess: true);

  factory WebdavTestResult.failure(String msg) =>
      WebdavTestResult(isSuccess: false, message: msg);
}

/// Service for testing WebDAV connectivity.
///
/// Sends PROPFIND with explicit Basic Auth directly via Dio, bypassing
/// webdav_client's NoAuth→BasicAuth upgrade mechanism which is incompatible
/// with 坚果云 (the server returns 503 instead of 401 for unauthenticated
/// OPTIONS requests).
class WebdavService {
  /// Tests a WebDAV connection using the given [config].
  Future<WebdavTestResult> testConnection(WebdavConfig config) async {
    if (!config.isConfigured) {
      return WebdavTestResult.failure('请先填写完整的WebDAV配置');
    }

    try {
      final credentials = base64.encode(
        utf8.encode('${config.account}:${config.password}'),
      );

      final dio = Dio(BaseOptions(
        connectTimeout:
            const Duration(milliseconds: AppConstants.webdavConnectTimeoutMs),
        receiveTimeout:
            const Duration(milliseconds: AppConstants.webdavReceiveTimeoutMs),
        validateStatus: (status) => true,
      ));

      final response = await dio.request(
        config.url,
        options: Options(
          method: 'PROPFIND',
          headers: {
            'Authorization': 'Basic $credentials',
            'Depth': '0',
            'Content-Type': 'application/xml; charset=utf-8',
          },
        ),
      );

      final code = response.statusCode ?? 0;

      // Check for 坚果云 rate-limiting response
      if (code == 503) {
        final body = response.data?.toString() ?? '';
        if (body.contains('BlockedTemporarily') ||
            body.contains('Too many requests')) {
          return WebdavTestResult.failure(
            '坚果云临时限流，请稍等几分钟后重试\n(Too many requests)',
          );
        }
        return WebdavTestResult.failure('服务器返回 503\n$body');
      }

      if (code == 207 || code == 200) {
        return WebdavTestResult.success();
      }

      if (code == 401 || code == 403) {
        return WebdavTestResult.failure('认证失败，请检查账号和密码');
      }

      if (code == 404) {
        return WebdavTestResult.failure('地址不存在(404)\n请检查URL路径是否正确');
      }

      return WebdavTestResult.failure('服务器返回 HTTP $code');
    } on DioException catch (e) {
      return WebdavTestResult.failure(_mapDioError(e));
    } catch (e) {
      return WebdavTestResult.failure('连接失败: $e');
    }
  }

  String _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return '连接超时，请检查地址和网络';
      case DioExceptionType.receiveTimeout:
        return '服务器响应超时，请检查网络';
      case DioExceptionType.connectionError:
        return '无法连接到服务器\n请检查地址格式和网络';
      case DioExceptionType.badResponse:
        final code = e.response?.statusCode;
        if (code == 401 || code == 403) {
          return '认证失败，请检查账号和密码';
        }
        return '服务器返回错误 (HTTP $code)';
      default:
        return '连接失败: ${e.message}';
    }
  }
}
