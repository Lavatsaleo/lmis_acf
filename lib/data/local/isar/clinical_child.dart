import 'package:isar/isar.dart';

part 'clinical_child.g.dart';

/// Local draft/synced clinical child record.
///
/// We keep it local first, then push to backend through SyncQueue.
@collection
class ClinicalChild {
  Id id = Isar.autoIncrement;

  /// Stable local identifier used as localEntityId in the SyncQueue.
  @Index(unique: true)
  late String localChildId;

  // Enrollment / caregiver
  late String caregiverName;
  String caregiverContacts = '';
  String? village;

  // Child
  late String firstName;
  late String lastName;
  String sex = 'UNKNOWN'; // MALE / FEMALE / UNKNOWN
  DateTime? dateOfBirth;
  String? cwcNumber;

  // Optional (from form)
  DateTime enrollmentDate = DateTime.now();
  String? chpName;
  String? chpContacts;

  /// For SUPER_ADMIN acting on a different facility.
  String? facilityCode;

  // Sync bookkeeping
  String status = 'DRAFT'; // DRAFT | QUEUED | SYNCED | FAILED
  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  // Server IDs (when available)
  String? remoteChildId;
  String? uniqueChildNumber;
}
