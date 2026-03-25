import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../local/auth/token_store.dart';

/// Thin wrapper around Dio.
///
/// - Adds Authorization header when token exists
/// - Automatically refreshes token on 401
/// - Retries the failed request once after refresh
class ApiClient {
  final Dio _dio;
  final Dio _refreshDio;
  final TokenStore _store;

  Completer<String?>? _refreshCompleter;

  ApiClient(this._dio, this._refreshDio, this._store);

  static ApiClient create({required String baseUrl, TokenStore? tokenStore}) {
    final store = tokenStore ?? const TokenStore();

    final baseOptions = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      sendTimeout: const Duration(seconds: 15),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    final dio = Dio(baseOptions);
    final refreshDio = Dio(baseOptions);

    final client = ApiClient(dio, refreshDio, store);

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final skipAuth = options.extra['skipAuth'] == true;

          if (!skipAuth && options.headers['Authorization'] == null) {
            final token = await store.readAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }

          handler.next(options);
        },
        onError: client._handleError,
      ),
    );

    return client;
  }

  Future<void> _handleError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final requestOptions = err.requestOptions;
    final path = requestOptions.path.toLowerCase();

    final isAuthLogin = path.contains('/api/auth/login') || path.endsWith('api/auth/login');
    final isAuthRefresh = path.contains('/api/auth/refresh') || path.endsWith('api/auth/refresh');
    final alreadyRetried = requestOptions.extra['_retried'] == true;

    if (status != 401 || isAuthLogin || isAuthRefresh || alreadyRetried) {
      handler.next(err);
      return;
    }

    try {
      final newAccessToken = await _refreshAccessToken();
      if (newAccessToken == null || newAccessToken.trim().isEmpty) {
        handler.next(err);
        return;
      }

      final response = await _retryRequest(requestOptions, newAccessToken);
      handler.resolve(response);
    } catch (_) {
      handler.next(err);
    }
  }

  Future<String?> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String?>();

    try {
      final refreshToken = await _store.readRefreshToken();
      if (refreshToken == null || refreshToken.trim().isEmpty) {
        await _store.clear();
        _refreshCompleter!.complete(null);
        return _refreshCompleter!.future;
      }

      final resp = await _refreshDio.post<dynamic>(
        'api/auth/refresh',
        data: {
          'refreshToken': refreshToken,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      );

      final data = resp.data;
      if (data is! Map) {
        await _store.clear();
        _refreshCompleter!.complete(null);
        return _refreshCompleter!.future;
      }

      final m = data.cast<String, dynamic>();
      final newAccessToken = (m['accessToken'] ?? '').toString().trim();
      final newRefreshToken = (m['refreshToken'] ?? '').toString().trim();

      if (newAccessToken.isEmpty || newRefreshToken.isEmpty) {
        await _store.clear();
        _refreshCompleter!.complete(null);
        return _refreshCompleter!.future;
      }

      await _store.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );

      _refreshCompleter!.complete(newAccessToken);
      return _refreshCompleter!.future;
    } catch (_) {
      await _store.clear();
      _refreshCompleter!.complete(null);
      return _refreshCompleter!.future;
    } finally {
      final done = _refreshCompleter;
      if (done != null && done.isCompleted) {
        _refreshCompleter = null;
      }
    }
  }

  Future<Response<dynamic>> _retryRequest(
    RequestOptions requestOptions,
    String accessToken,
  ) {
    final headers = Map<String, dynamic>.from(requestOptions.headers);
    headers['Authorization'] = 'Bearer $accessToken';

    return _dio.request<dynamic>(
      requestOptions.path,
      data: requestOptions.data,
      queryParameters: requestOptions.queryParameters,
      cancelToken: requestOptions.cancelToken,
      options: Options(
        method: requestOptions.method,
        headers: headers,
        responseType: requestOptions.responseType,
        contentType: requestOptions.contentType,
        sendTimeout: requestOptions.sendTimeout,
        receiveTimeout: requestOptions.receiveTimeout,
        extra: {
          ...requestOptions.extra,
          '_retried': true,
        },
        followRedirects: requestOptions.followRedirects,
        validateStatus: requestOptions.validateStatus,
        receiveDataWhenStatusError: requestOptions.receiveDataWhenStatusError,
      ),
    );
  }

  Future<Response<dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic>? headers,
    dynamic data,
  }) async {
    final upper = method.trim().toUpperCase();

    dynamic body = data;
    if (data is String) {
      final raw = data.trim();
      if (raw.isNotEmpty) {
        try {
          body = jsonDecode(raw);
        } catch (_) {
          body = raw;
        }
      }
    }

    final normalizedPath = path.startsWith('/') ? path.substring(1) : path;

    final opts = Options(method: upper, headers: headers);
    return _dio.request<dynamic>(normalizedPath, data: body, options: opts);
  }
}