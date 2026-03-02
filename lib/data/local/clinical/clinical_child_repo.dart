import 'dart:async';

import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/clinical_child.dart';

class ClinicalChildRepo {
  Isar get _db => IsarService.instance.isar;

  Future<void> upsert(ClinicalChild child) async {
    await _db.writeTxn(() async {
      child.updatedAt = DateTime.now();
      await _db.clinicalChilds.put(child);
    });
  }

  Future<ClinicalChild?> findByLocalId(String localChildId) {
    return _db.clinicalChilds.filter().localChildIdEqualTo(localChildId).findFirst();
  }

  /// Find an existing child by the server (remote) ID.
  ///
  /// Used when importing / refreshing data from server so we update the same local record
  /// instead of creating a duplicate local child.
  Future<ClinicalChild?> findByRemoteChildId(String remoteChildId) {
    final id = remoteChildId.trim();
    if (id.isEmpty) return Future.value(null);
    return _db.clinicalChilds.filter().remoteChildIdEqualTo(id).findFirst();
  }

  /// Find an existing child by registration number.
  Future<ClinicalChild?> findByUniqueChildNumber(String uniqueChildNumber) {
    final u = uniqueChildNumber.trim();
    if (u.isEmpty) return Future.value(null);
    return _db.clinicalChilds.filter().uniqueChildNumberEqualTo(u).findFirst();
  }

  /// Find an existing child by CWC number (used to prevent duplicate registrations).
  Future<ClinicalChild?> findByCwcNumber(String cwcNumber) {
    final c = cwcNumber.trim();
    if (c.isEmpty) return Future.value(null);
    return _db.clinicalChilds.filter().cwcNumberEqualTo(c).findFirst();
  }

  Future<List<ClinicalChild>> listAll({int limit = 200}) {
    return _db.clinicalChilds.where().sortByCreatedAtDesc().limit(limit).findAll();
  }

  Stream<List<ClinicalChild>> watchAll({int limit = 200}) async* {
    // Emit immediately so screens show existing data after app restart.
    yield await listAll(limit: limit);

    // watchLazy() is single-subscription; make it broadcast-safe.
    await for (final _ in _db.clinicalChilds.watchLazy().asBroadcastStream()) {
      yield await listAll(limit: limit);
    }
  }

  Future<List<ClinicalChild>> search(String query, {int limit = 50}) async {
    final q = query.trim();
    if (q.isEmpty) {
      return listAll(limit: limit);
    }

    return _db.clinicalChilds
        .filter()
        .group(
          (f) => f
              .firstNameContains(q, caseSensitive: false)
              .or()
              .lastNameContains(q, caseSensitive: false)
              .or()
              .cwcNumberContains(q, caseSensitive: false)
              .or()
              .uniqueChildNumberContains(q, caseSensitive: false)
              .or()
              .caregiverNameContains(q, caseSensitive: false)
              .or()
              .caregiverContactsContains(q, caseSensitive: false),
        )
        .sortByCreatedAtDesc()
        .limit(limit)
        .findAll();
  }

  Future<int> countDraftOrQueued() async {
    // Isar query generator doesn't always produce `NotEqualTo` helpers for String fields.
    // Use `not().statusEqualTo(...)` which is supported.
    return _db.clinicalChilds.filter().not().statusEqualTo('SYNCED').count();
  }
}
