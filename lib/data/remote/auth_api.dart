import '../../core/config/app_config.dart';
import 'api_client.dart';

class LoginResponse {
  final String accessToken;
  final String refreshToken;
  final Map<String, dynamic> user;

  LoginResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });
}

class RefreshResponse {
  final String accessToken;
  final String refreshToken;

  RefreshResponse({
    required this.accessToken,
    required this.refreshToken,
  });
}

/// Auth-related API calls.
class AuthApi {
  final ApiClient _api;

  AuthApi(this._api);

  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final resp = await _api.request(
      method: 'POST',
      path: AppConfig.defaultLoginPath,
      data: {
        'email': email.trim(),
        'password': password,
      },
    );

    final data = resp.data;
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final accessToken = (m['accessToken'] ?? '').toString();
      final refreshToken = (m['refreshToken'] ?? '').toString();
      final user = (m['user'] is Map)
          ? (m['user'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      return LoginResponse(
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: user,
      );
    }

    throw Exception('Unexpected login response');
  }

  Future<RefreshResponse> refresh(String refreshToken) async {
    final resp = await _api.request(
      method: 'POST',
      path: '/api/auth/refresh',
      data: {
        'refreshToken': refreshToken,
      },
    );

    final data = resp.data;
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final accessToken = (m['accessToken'] ?? '').toString();
      final newRefreshToken = (m['refreshToken'] ?? '').toString();

      return RefreshResponse(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
    }

    throw Exception('Unexpected refresh response');
  }

  /// Fetch enriched session info from backend.
  ///
  /// Backend: GET /api/me => { user: { ...facilityType, warehouseId, ... } }
  ///
  /// If [accessToken] is provided, we pass it explicitly. Otherwise, ApiClient
  /// will attach the token from secure storage.
  Future<Map<String, dynamic>> fetchMe({String? accessToken}) async {
    final resp = await _api.request(
      method: 'GET',
      path: '/api/me',
      headers: accessToken == null ? null : {'Authorization': 'Bearer $accessToken'},
    );

    final data = resp.data;
    if (data is Map) {
      final m = data.cast<String, dynamic>();
      final user = (m['user'] is Map)
          ? (m['user'] as Map).cast<String, dynamic>()
          : <String, dynamic>{};
      return user;
    }

    return <String, dynamic>{};
  }
}