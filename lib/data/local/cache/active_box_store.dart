import 'package:shared_preferences/shared_preferences.dart';

/// Stores the currently selected "active" box per facility.
///
/// Clinician scans/selects a box before dispensing.
class ActiveBoxStore {
  static const _kPrefix = 'facility.activeBoxUid.'; // + facilityId

  Future<String?> getActiveBoxUid(String facilityId) async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString('$_kPrefix$facilityId');
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  Future<void> setActiveBoxUid(String facilityId, String? boxUid) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kPrefix$facilityId';
    if (boxUid == null || boxUid.trim().isEmpty) {
      await prefs.remove(key);
    } else {
      await prefs.setString(key, boxUid.trim());
    }
  }
}
