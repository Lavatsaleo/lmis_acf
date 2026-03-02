import 'package:isar/isar.dart';

part 'clinical_assessment.g.dart';

/// Local in-depth assessment.
///
/// We keep the full form payload as JSON string for simplicity.
@collection
class ClinicalAssessment {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String localAssessmentId;

  @Index()
  late String localChildId;

  DateTime assessmentDate = DateTime.now();

  /// JSON string containing the full answers + derived fields + analysis notes.
  late String dataJson;

  // Quick fields for fast filtering.
  int? muacMm;
  double? weightKg;
  double? heightCm;
  int? householdHungerScore;
  String? householdHungerCategory;
  int? pssScore;
  String? pssCategory;

  String status = 'DRAFT'; // DRAFT | QUEUED | SYNCED | FAILED

  DateTime createdAt = DateTime.now();
  DateTime updatedAt = DateTime.now();

  // Server IDs
  String? remoteAssessmentId;
}
