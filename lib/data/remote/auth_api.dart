import '../../core/config/app_config.dart';
import 'api_client.dart';

class LoginResponse {
  final String token;
  final Map<String, dynamic> user;

  LoginResponse({required this.token, required this.user});
}

/// Auth-related API calls.
class AuthApi {
  final ApiClient _api;

  AuthApi(this._api);

  Future<LoginResponse> login({required String email, required String password}) async {
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
      final token = (m['token'] ?? '').toString();
      final user = (m['user'] is Map) ? (m['user'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      return LoginResponse(token: token, user: user);
    }
    throw Exception('Unexpected login response');
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
      final user = (m['user'] is Map) ? (m['user'] as Map).cast<String, dynamic>() : <String, dynamic>{};
      return user;
    }
    return <String, dynamic>{};
  }
}
