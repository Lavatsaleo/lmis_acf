import 'dart:convert';

import 'package:dio/dio.dart';

import '../local/auth/token_store.dart';

/// Thin wrapper around Dio.
///
/// - Adds Authorization header when token exists
/// - Sends idempotency headers for queued requests
class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  static ApiClient create({required String baseUrl, TokenStore? tokenStore}) {
    final store = tokenStore ?? const TokenStore();

    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await store.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    return ApiClient(dio);
  }

  Future<Response<dynamic>> request({
    required String method,
    required String path,
    Map<String, dynamic>? headers,
    dynamic data,
  }) async {
    final upper = method.trim().toUpperCase();

    // Normalize JSON string payloads.
    dynamic body = data;
    if (data is String) {
      final raw = data.trim();
      if (raw.isNotEmpty) {
        try {
          body = jsonDecode(raw);
        } catch (_) {
          // keep as string
          body = raw;
        }
      }
    }

    final opts = Options(method: upper, headers: headers);
    return _dio.request<dynamic>(path, data: body, options: opts);
  }
}
