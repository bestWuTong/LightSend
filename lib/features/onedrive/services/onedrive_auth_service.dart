import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../config/data/models/onedrive_config.dart';

class OneDriveAuthException implements Exception {
  final String message;

  const OneDriveAuthException(this.message);

  @override
  String toString() => message;
}

class OneDriveAuthService {
  static const MethodChannel _androidChannel = MethodChannel(
    'lightsend/onedrive_auth',
  );
  static Completer<Uri>? _androidRedirectCompleter;
  static bool _androidRedirectHandlerInstalled = false;

  final Dio _dio;

  OneDriveAuthService({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 30),
              validateStatus: (status) => status != null && status < 500,
            ),
          );

  static void _ensureAndroidRedirectHandler() {
    if (_androidRedirectHandlerInstalled) return;
    _androidRedirectHandlerInstalled = true;
    _androidChannel.setMethodCallHandler((call) async {
      if (call.method != 'onAuthRedirect') return;
      _completeAndroidRedirect(call.arguments as String?);
    });
  }

  static void _completeAndroidRedirect(
    String? raw, {
    Completer<Uri>? completer,
  }) {
    final target = completer ?? _androidRedirectCompleter;
    if (raw == null || raw.isEmpty || target == null || target.isCompleted) {
      return;
    }

    try {
      target.complete(Uri.parse(raw));
    } catch (e, st) {
      target.completeError(e, st);
    }
  }

  Future<OneDriveConfig> signIn() async {
    if (io.Platform.isAndroid) {
      return _signInWithAndroidRedirect();
    }
    if (io.Platform.isWindows || io.Platform.isLinux) {
      return _signInWithLoopbackRedirect();
    }
    throw const OneDriveAuthException('当前平台暂不支持 OneDrive 登录');
  }

  Future<OneDriveConfig> refresh(OneDriveConfig config) async {
    if (config.refreshToken.isEmpty) {
      throw const OneDriveAuthException('OneDrive 登录已过期，请重新登录');
    }

    final token = await _requestToken({
      'client_id': AppConstants.oneDriveClientId,
      'scope': _scopeString,
      'grant_type': 'refresh_token',
      'refresh_token': config.refreshToken,
    });

    final refreshed = _configFromToken(token, existing: config);
    return _withProfile(refreshed);
  }

  Future<String> getValidAccessToken(
    OneDriveConfig config, {
    required Future<void> Function(OneDriveConfig updated) onRefresh,
  }) async {
    if (config.hasUsableAccessToken) return config.accessToken;

    final refreshed = await refresh(config);
    await onRefresh(refreshed);
    return refreshed.accessToken;
  }

  Future<OneDriveConfig> _signInWithLoopbackRedirect() async {
    final verifier = _randomBase64Url(64);
    final challenge = _pkceChallenge(verifier);
    final state = _randomBase64Url(32);
    final server = await io.HttpServer.bind(io.InternetAddress.loopbackIPv4, 0);
    final redirectUri =
        'http://127.0.0.1:${server.port}${AppConstants.oneDriveDesktopRedirectPath}';

    try {
      final authUri = _buildAuthorizeUri(
        redirectUri: redirectUri,
        state: state,
        codeChallenge: challenge,
      );
      await _launchAuthUrl(authUri);

      final request = await server.first.timeout(
        const Duration(seconds: AppConstants.oneDriveAuthTimeoutSeconds),
      );
      final callbackUri = request.uri;

      _writeDesktopCallbackResponse(request);
      return _completeAuthorization(
        callbackUri: callbackUri,
        expectedState: state,
        redirectUri: redirectUri,
        codeVerifier: verifier,
      );
    } on TimeoutException {
      throw const OneDriveAuthException('OneDrive 登录超时');
    } finally {
      await server.close(force: true);
    }
  }

  Future<OneDriveConfig> _signInWithAndroidRedirect() async {
    final verifier = _randomBase64Url(64);
    final challenge = _pkceChallenge(verifier);
    final state = _randomBase64Url(32);
    const redirectUri = AppConstants.oneDriveAndroidRedirectUri;

    final callbackUri = await _waitForAndroidRedirect(() async {
      final authUri = _buildAuthorizeUri(
        redirectUri: redirectUri,
        state: state,
        codeChallenge: challenge,
      );
      await _launchAuthUrl(authUri);
    });

    return _completeAuthorization(
      callbackUri: callbackUri,
      expectedState: state,
      redirectUri: redirectUri,
      codeVerifier: verifier,
    );
  }

  Future<Uri> _waitForAndroidRedirect(Future<void> Function() launch) async {
    _ensureAndroidRedirectHandler();

    final previousCompleter = _androidRedirectCompleter;
    if (previousCompleter != null && !previousCompleter.isCompleted) {
      throw const OneDriveAuthException('OneDrive 登录正在进行中');
    }

    Completer<Uri>? completer;
    try {
      await _clearPendingAndroidRedirect();

      completer = Completer<Uri>();
      _androidRedirectCompleter = completer;
      await launch();

      return await _waitForAndroidRedirectResult(completer);
    } on TimeoutException {
      throw const OneDriveAuthException('OneDrive 登录超时');
    } finally {
      if (completer != null && _androidRedirectCompleter == completer) {
        _androidRedirectCompleter = null;
      }
    }
  }

  Future<Uri> _waitForAndroidRedirectResult(Completer<Uri> completer) async {
    final deadline = DateTime.now().add(
      const Duration(seconds: AppConstants.oneDriveAuthTimeoutSeconds),
    );
    const pollInterval = Duration(milliseconds: 300);

    while (!completer.isCompleted && DateTime.now().isBefore(deadline)) {
      await _consumePendingAndroidRedirect(completer);
      if (completer.isCompleted) break;

      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) break;
      await Future<void>.delayed(
        remaining < pollInterval ? remaining : pollInterval,
      );
    }

    if (!completer.isCompleted) {
      throw TimeoutException('OneDrive Android redirect timeout');
    }

    return completer.future;
  }

  Future<void> _consumePendingAndroidRedirect(Completer<Uri> completer) async {
    final pending = await _androidChannel.invokeMethod<String>(
      'consumePendingAuthRedirect',
    );
    _completeAndroidRedirect(pending, completer: completer);
  }

  Future<void> _clearPendingAndroidRedirect() async {
    await _androidChannel.invokeMethod<void>('clearPendingAuthRedirect');
  }

  Uri _buildAuthorizeUri({
    required String redirectUri,
    required String state,
    required String codeChallenge,
  }) {
    return Uri.parse(AppConstants.oneDriveAuthorizeEndpoint).replace(
      queryParameters: {
        'client_id': AppConstants.oneDriveClientId,
        'response_type': 'code',
        'redirect_uri': redirectUri,
        'response_mode': 'query',
        'scope': _scopeString,
        'code_challenge': codeChallenge,
        'code_challenge_method': 'S256',
        'state': state,
        'prompt': 'select_account',
      },
    );
  }

  Future<void> _launchAuthUrl(Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw const OneDriveAuthException('无法打开浏览器进行 OneDrive 登录');
    }
  }

  Future<OneDriveConfig> _completeAuthorization({
    required Uri callbackUri,
    required String expectedState,
    required String redirectUri,
    required String codeVerifier,
  }) async {
    final params = callbackUri.queryParameters;
    final error = params['error'];
    if (error != null) {
      final description = params['error_description'] ?? error;
      throw OneDriveAuthException(description);
    }

    if (params['state'] != expectedState) {
      throw const OneDriveAuthException('OneDrive 登录状态校验失败');
    }

    final code = params['code'];
    if (code == null || code.isEmpty) {
      throw const OneDriveAuthException('OneDrive 登录未返回授权码');
    }

    final token = await _requestToken({
      'client_id': AppConstants.oneDriveClientId,
      'scope': _scopeString,
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': redirectUri,
      'code_verifier': codeVerifier,
    });

    final config = _configFromToken(token);
    return _withProfile(config);
  }

  Future<Map<String, dynamic>> _requestToken(Map<String, String> data) async {
    final response = await _dio.post<Map<String, dynamic>>(
      AppConstants.oneDriveTokenEndpoint,
      data: data,
      options: Options(contentType: Headers.formUrlEncodedContentType),
    );

    final body = response.data ?? const <String, dynamic>{};
    if ((response.statusCode ?? 0) >= 400) {
      final message =
          body['error_description'] as String? ??
          body['error'] as String? ??
          'OneDrive 令牌请求失败';
      throw OneDriveAuthException(message);
    }

    if (body['access_token'] is! String) {
      throw const OneDriveAuthException('OneDrive 令牌响应无效');
    }
    return body;
  }

  OneDriveConfig _configFromToken(
    Map<String, dynamic> token, {
    OneDriveConfig? existing,
  }) {
    final expiresIn = token['expires_in'] is int
        ? token['expires_in'] as int
        : int.tryParse('${token['expires_in']}') ?? 3600;
    return OneDriveConfig(
      accessToken: token['access_token'] as String,
      refreshToken:
          token['refresh_token'] as String? ?? existing?.refreshToken ?? '',
      expiresAt: DateTime.now().add(Duration(seconds: expiresIn)),
      displayName: existing?.displayName ?? '',
      account: existing?.account ?? '',
    );
  }

  Future<OneDriveConfig> _withProfile(OneDriveConfig config) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '${AppConstants.oneDriveGraphBaseUrl}/me',
        queryParameters: {r'$select': 'displayName,mail,userPrincipalName'},
        options: Options(headers: _authHeaders(config.accessToken)),
      );
      final body = response.data ?? const <String, dynamic>{};
      return config.copyWith(
        displayName: body['displayName'] as String? ?? config.displayName,
        account:
            body['mail'] as String? ??
            body['userPrincipalName'] as String? ??
            config.account,
      );
    } catch (e, st) {
      debugPrint('[LightSend] OneDrive profile load failed: $e\n$st');
      return config;
    }
  }

  Map<String, String> _authHeaders(String token) => {
    'Authorization': 'Bearer $token',
  };

  void _writeDesktopCallbackResponse(io.HttpRequest request) {
    request.response
      ..statusCode = 200
      ..headers.contentType = io.ContentType.html
      ..write('''
<!doctype html>
<html>
<head><meta charset="utf-8"><title>LightSend</title></head>
<body>
<h3>LightSend OneDrive sign-in is complete.</h3>
<p>You can close this window and return to LightSend.</p>
</body>
</html>
''');
    unawaited(request.response.close());
  }

  String get _scopeString => AppConstants.oneDriveScopes.join(' ');

  String _randomBase64Url(int byteCount) {
    final random = Random.secure();
    final bytes = List<int>.generate(byteCount, (_) => random.nextInt(256));
    return base64UrlEncode(bytes).replaceAll('=', '');
  }

  String _pkceChallenge(String verifier) {
    final digest = sha256.convert(ascii.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
