import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores non-sensitive session/profile information.
///
/// Token is stored separately in [TokenStore] (secure storage).
class SessionStore {
  static const _kUserJson = 'auth.userJson';

  Future<void> saveUserJson(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserJson, jsonEncode(user));
  }

  Future<Map<String, dynamic>?> readUserJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUserJson);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserJson);
  }
}
