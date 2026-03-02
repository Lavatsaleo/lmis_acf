import 'package:isar/isar.dart';

part 'facility_cache.g.dart';

/// Local cache of facilities.
///
/// This enables facility selection even when the phone is offline.
@collection
class FacilityCache {
  Id id = Isar.autoIncrement;

  /// Server-side Facility ID (Prisma `Facility.id`).
  @Index(unique: true)
  late String facilityId;

  late String name;

  /// Optional: facility code / MOH code, if you have one.
  String? code;

  DateTime updatedAt = DateTime.now();
}
