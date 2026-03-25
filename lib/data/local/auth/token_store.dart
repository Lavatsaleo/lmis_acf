import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores auth tokens securely.
class TokenStore {
  static const _kAccessToken = 'auth.accessToken';
  static const _kRefreshToken = 'auth.refreshToken';

  final FlutterSecureStorage _storage;

  const TokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken.trim());
    await _storage.write(key: _kRefreshToken, value: refreshToken.trim());
  }

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _kAccessToken, value: token.trim());
  }

  Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _kRefreshToken, value: token.trim());
  }

  Future<String?> readAccessToken() async {
    final token = await _storage.read(key: _kAccessToken);
    if (token == null) return null;
    final t = token.trim();
    return t.isEmpty ? null : t;
  }

  Future<String?> readRefreshToken() async {
    final token = await _storage.read(key: _kRefreshToken);
    if (token == null) return null;
    final t = token.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
  }
}