import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Stores auth tokens securely.
///
/// In Step 2 we only store a single access token. Later you can add
/// refresh tokens, expiry, user profile, etc.
class TokenStore {
  static const _kAccessToken = 'auth.accessToken';

  final FlutterSecureStorage _storage;

  const TokenStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _kAccessToken, value: token.trim());
  }

  Future<String?> readAccessToken() async {
    final token = await _storage.read(key: _kAccessToken);
    if (token == null) return null;
    final t = token.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
  }
}
