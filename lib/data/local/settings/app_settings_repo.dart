import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// Lightweight storage for app-level settings.
///
/// We keep this in SharedPreferences because it's small and not sensitive.
class AppSettingsRepo {
  static const _kBaseUrl = 'settings.baseUrl';

  Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kBaseUrl) ?? AppConfig.defaultBaseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBaseUrl, value.trim());
  }
}
