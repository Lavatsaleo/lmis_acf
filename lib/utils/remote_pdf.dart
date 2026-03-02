import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Downloads a PDF from the backend and returns bytes.
///
/// - [pathOrUrl] may be a full URL or a relative path like `/api/orders/123/print/a3`.
class RemotePdf {
  static Future<Uint8List> downloadPdfBytes({
    required String baseUrl,
    required String pathOrUrl,
    required String? accessToken,
  }) async {
    final url = _resolve(baseUrl, pathOrUrl);

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 40),
        sendTimeout: const Duration(seconds: 20),
        responseType: ResponseType.bytes,
        headers: const {
          'Accept': 'application/pdf',
        },
      ),
    );

    if (accessToken != null && accessToken.trim().isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer ${accessToken.trim()}';
    }

    final resp = await dio.get<List<int>>(url);
    final data = resp.data;
    if (data == null) {
      throw Exception('No PDF bytes returned');
    }
    return Uint8List.fromList(data);
  }

  static String _resolve(String baseUrl, String pathOrUrl) {
    final p = pathOrUrl.trim();
    if (p.startsWith('http://') || p.startsWith('https://')) return p;

    var b = baseUrl.trim();
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    final rel = p.startsWith('/') ? p : '/$p';
    return '$b$rel';
  }
}
