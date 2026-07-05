import '../../data/local/auth/session_store.dart';

/// Small helper for keeping local clinical data scoped to the currently
/// logged-in facility on shared phones.
class ActiveFacilityContext {
  final String facilityId;
  final String facilityCode;
  final String facilityName;
  final String userId;
  final String email;

  const ActiveFacilityContext({
    required this.facilityId,
    required this.facilityCode,
    required this.facilityName,
    required this.userId,
    required this.email,
  });

  bool get hasFacilityId => facilityId.trim().isNotEmpty;
  bool get hasFacilityCode => facilityCode.trim().isNotEmpty;

  bool matchesFacilityCode(String? value) {
    final expected = facilityCode.trim().toLowerCase();
    if (expected.isEmpty) return true;
    final actual = (value ?? '').trim().toLowerCase();
    if (actual.isEmpty) return false;
    return actual == expected;
  }
}

class ActiveFacilityScope {
  const ActiveFacilityScope._();

  static Future<ActiveFacilityContext> read({SessionStore? sessionStore}) async {
    final session = sessionStore ?? SessionStore();
    final user = await session.readUserJson();
    return fromUser(user);
  }

  static ActiveFacilityContext fromUser(Map<String, dynamic>? user) {
    final facility = user?['facility'];
    final facilityMap = facility is Map ? facility.cast<String, dynamic>() : const <String, dynamic>{};

    return ActiveFacilityContext(
      facilityId: _firstNonEmpty(user, const ['facilityId', 'facility_id'], fallback: facilityMap['id']),
      facilityCode: _firstNonEmpty(user, const ['facilityCode', 'facility_code'], fallback: facilityMap['code']),
      facilityName: _firstNonEmpty(user, const ['facilityName', 'facility_name'], fallback: facilityMap['name']),
      userId: _firstNonEmpty(user, const ['id', 'userId', 'user_id']),
      email: _firstNonEmpty(user, const ['email']),
    );
  }

  static String _firstNonEmpty(
    Map<String, dynamic>? source,
    List<String> keys, {
    dynamic fallback,
  }) {
    if (source != null) {
      for (final key in keys) {
        final value = source[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
    }
    if (fallback != null && fallback.toString().trim().isNotEmpty) {
      return fallback.toString().trim();
    }
    return '';
  }
}
