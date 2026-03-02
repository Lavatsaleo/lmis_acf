import 'dart:async';

import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/clinical_assessment.dart';

class ClinicalAssessmentRepo {
  Isar get _db => IsarService.instance.isar;

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

  Future<int> countDraftOrQueued() async {
    // Isar query generator doesn't always produce `NotEqualTo` helpers for String fields.
    // Use `not().statusEqualTo(...)` which is supported.
    return _db.clinicalAssessments.filter().not().statusEqualTo('SYNCED').count();
  }

  /// List all assessments (across all children).
  ///
  /// Used to compute facility-level stock consumption when offline.
  Future<List<ClinicalAssessment>> listAll({int limit = 5000}) {
    return _db.clinicalAssessments
        .where()
        .sortByAssessmentDateDesc()
        .limit(limit)
        .findAll();
  }

  Stream<List<ClinicalAssessment>> watchAll({int limit = 5000}) async* {
    yield await listAll(limit: limit);
    await for (final _ in _db.clinicalAssessments.watchLazy().asBroadcastStream()) {
      yield await listAll(limit: limit);
    }
  }
}
