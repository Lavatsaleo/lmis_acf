import 'dart:async';

import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/clinical_assessment.dart';
import 'clinical_child_repo.dart';

class ClinicalAssessmentRepo {
  Isar get _db => IsarService.instance.isar;
  final ClinicalChildRepo _childRepo = ClinicalChildRepo();

  Future<Set<String>> _childIdsForFacility(String? facilityCode) async {
    final fc = (facilityCode ?? '').trim();
    if (fc.isEmpty) return const <String>{};
    return _childRepo.localChildIdsForFacility(fc, limit: 10000);
  }

  Future<ClinicalAssessment?> findByLocalAssessmentId(String localAssessmentId) {
    return _db.clinicalAssessments.filter().localAssessmentIdEqualTo(localAssessmentId).findFirst();
  }

  /// Find an existing assessment by server (remote) ID.
  ///
  /// Used when importing data from server so we update the same local record
  /// instead of creating duplicates.
  Future<ClinicalAssessment?> findByRemoteAssessmentId(String remoteAssessmentId) {
    final id = remoteAssessmentId.trim();
    if (id.isEmpty) return Future.value(null);
    return _db.clinicalAssessments.filter().remoteAssessmentIdEqualTo(id).findFirst();
  }

  Future<void> upsert(ClinicalAssessment a) async {
    await _db.writeTxn(() async {
      a.updatedAt = DateTime.now();
      await _db.clinicalAssessments.put(a);
    });
  }

  Future<void> deleteByLocalAssessmentId(String localAssessmentId) async {
    final id = localAssessmentId.trim();
    if (id.isEmpty) return;
    final found = await findByLocalAssessmentId(id);
    if (found == null) return;
    await _db.writeTxn(() async {
      await _db.clinicalAssessments.delete(found.id);
    });
  }

  Future<List<ClinicalAssessment>> listForChild(String localChildId, {int limit = 50}) {
    return _db.clinicalAssessments
        .filter()
        .localChildIdEqualTo(localChildId)
        .sortByAssessmentDateDesc()
        .limit(limit)
        .findAll();
  }

  Stream<List<ClinicalAssessment>> watchForChild(String localChildId, {int limit = 50}) async* {
    // Emit immediately so screens show existing data after app restart.
    yield await listForChild(localChildId, limit: limit);

    // Then emit on any collection change.
    await for (final _ in _db.clinicalAssessments.watchLazy().asBroadcastStream()) {
      yield await listForChild(localChildId, limit: limit);
    }
  }

  Future<int> countDraftOrQueued({String? facilityCode}) async {
    // Isar query generator doesn't always produce `NotEqualTo` helpers for String fields.
    // Use `not().statusEqualTo(...)` which is supported.
    final all = await _db.clinicalAssessments.filter().not().statusEqualTo('SYNCED').findAll();
    final fc = (facilityCode ?? '').trim();
    if (fc.isEmpty) return all.length;
    final childIds = await _childIdsForFacility(fc);
    if (childIds.isEmpty) return 0;
    return all.where((a) => childIds.contains(a.localChildId)).length;
  }

  /// List all assessments (across all children unless [facilityCode] is supplied).
  ///
  /// Used to compute facility-level stock consumption when offline. When the phone
  /// has cached data from multiple facilities, always pass facilityCode so one
  /// facility's pending dispenses do not affect another facility's store view.
  Future<List<ClinicalAssessment>> listAll({int limit = 5000, String? facilityCode}) async {
    final all = await _db.clinicalAssessments
        .where()
        .sortByAssessmentDateDesc()
        .limit(limit)
        .findAll();

    final fc = (facilityCode ?? '').trim();
    if (fc.isEmpty) return all;
    final childIds = await _childIdsForFacility(fc);
    if (childIds.isEmpty) return const [];
    return all.where((a) => childIds.contains(a.localChildId)).toList();
  }

  Stream<List<ClinicalAssessment>> watchAll({int limit = 5000, String? facilityCode}) async* {
    yield await listAll(limit: limit, facilityCode: facilityCode);
    await for (final _ in _db.clinicalAssessments.watchLazy().asBroadcastStream()) {
      yield await listAll(limit: limit, facilityCode: facilityCode);
    }
  }
}
