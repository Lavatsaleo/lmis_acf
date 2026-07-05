import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';

/// Lightweight storage for app-level settings.
///
/// The backend base URL is fixed in code for security, but we still keep cached
/// facility store summary values and per-facility sync cursors here because they
/// are small and device-local.
class AppSettingsRepo {
  static const _kBaseUrl = 'settings.baseUrl';
  static const _kStoreSachetsPrefix = 'settings.storeSummary.totalSachets.';
  static const _kStoreBoxesPrefix = 'settings.storeSummary.boxesInStore.';
  static const _kStoreUpdatedAtPrefix = 'settings.storeSummary.updatedAt.';
  static const _kClinicalPullAtPrefix = 'settings.clinical.lastPullAt.';
  static const _kClinicalPullOkAtPrefix = 'settings.clinical.lastPullOkAt.';

  Future<String> getBaseUrl() async {
    return AppConfig.defaultBaseUrl;
  }

  Future<void> setBaseUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBaseUrl);
  }

  String _storeSachetsKey(String facilityId) => '$_kStoreSachetsPrefix${facilityId.trim()}';
  String _storeBoxesKey(String facilityId) => '$_kStoreBoxesPrefix${facilityId.trim()}';
  String _storeUpdatedAtKey(String facilityId) => '$_kStoreUpdatedAtPrefix${facilityId.trim()}';
  String _clinicalPullAtKey(String facilityId) => '$_kClinicalPullAtPrefix${facilityId.trim()}';
  String _clinicalPullOkAtKey(String facilityId) => '$_kClinicalPullOkAtPrefix${facilityId.trim()}';

  Future<void> cacheFacilityStoreSummary({
    required String facilityId,
    required int totalSachetsRemaining,
    required int boxesInStore,
  }) async {
    final id = facilityId.trim();
    if (id.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_storeSachetsKey(id), totalSachetsRemaining);
    await prefs.setInt(_storeBoxesKey(id), boxesInStore);
    await prefs.setString(_storeUpdatedAtKey(id), DateTime.now().toIso8601String());
  }

  Future<int?> getCachedFacilityStoreSachetsRemaining(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_storeSachetsKey(id));
  }

  Future<int?> getCachedFacilityStoreBoxesInStore(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_storeBoxesKey(id));
  }

  Future<DateTime?> getCachedFacilityStoreUpdatedAt(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storeUpdatedAtKey(id));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  /// Last successful clinical pull cursor for this facility.
  ///
  /// Used by /api/clinical/facility/sync-delta so phones can pull children and
  /// visits entered or edited by other devices without downloading everything.
  Future<DateTime?> getClinicalLastPullAt(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clinicalPullAtKey(id));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  Future<void> setClinicalLastPullAt(String facilityId, DateTime value) async {
    final id = facilityId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_clinicalPullAtKey(id), value.toUtc().toIso8601String());
    await prefs.setString(_clinicalPullOkAtKey(id), DateTime.now().toUtc().toIso8601String());
  }

  Future<DateTime?> getClinicalLastSuccessfulPullRecordedAt(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return null;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_clinicalPullOkAtKey(id));
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  Future<void> clearClinicalLastPullAt(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clinicalPullAtKey(id));
    await prefs.remove(_clinicalPullOkAtKey(id));
  }
}
