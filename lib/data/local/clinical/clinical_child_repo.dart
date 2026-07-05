import 'dart:async';

import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/clinical_child.dart';

class ClinicalChildRepo {
  Isar get _db => IsarService.instance.isar;

  bool _matchesFacility(ClinicalChild child, String? facilityCode) {
    final fc = (facilityCode ?? '').trim().toLowerCase();
    if (fc.isEmpty) return true;
    return (child.facilityCode ?? '').trim().toLowerCase() == fc;
  }

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
  Future<ClinicalChild?> findByRemoteChildId(String remoteChildId, {String? facilityCode}) async {
    final id = remoteChildId.trim();
    if (id.isEmpty) return null;
    final found = await _db.clinicalChilds.filter().remoteChildIdEqualTo(id).findAll();
    for (final child in found) {
      if (_matchesFacility(child, facilityCode)) return child;
    }
    return null;
  }

  /// Find an existing child by registration number.
  Future<ClinicalChild?> findByUniqueChildNumber(String uniqueChildNumber, {String? facilityCode}) async {
    final u = uniqueChildNumber.trim();
    if (u.isEmpty) return null;
    final found = await _db.clinicalChilds.filter().uniqueChildNumberEqualTo(u).findAll();
    for (final child in found) {
      if (_matchesFacility(child, facilityCode)) return child;
    }
    return null;
  }

  /// Find an existing child by CWC number.
  ///
  /// When [facilityCode] is supplied, only match within that facility. This prevents
  /// a shared phone from treating Facility X's child as a duplicate while logged
  /// into Facility Y.
  Future<ClinicalChild?> findByCwcNumber(String cwcNumber, {String? facilityCode}) async {
    final c = cwcNumber.trim();
    if (c.isEmpty) return null;
    final found = await _db.clinicalChilds.filter().cwcNumberEqualTo(c).findAll();
    for (final child in found) {
      if (_matchesFacility(child, facilityCode)) return child;
    }
    return null;
  }

  Future<List<ClinicalChild>> listAll({int limit = 200, String? facilityCode}) async {
    final fc = (facilityCode ?? '').trim();
    final fetchLimit = fc.isEmpty ? limit : limit * 5;
    final all = await _db.clinicalChilds.where().sortByCreatedAtDesc().limit(fetchLimit).findAll();
    if (fc.isEmpty) return all.take(limit).toList();
    return all.where((child) => _matchesFacility(child, fc)).take(limit).toList();
  }

  Stream<List<ClinicalChild>> watchAll({int limit = 200, String? facilityCode}) async* {
    // Emit immediately so screens show existing data after app restart.
    yield await listAll(limit: limit, facilityCode: facilityCode);

    // watchLazy() is single-subscription; make it broadcast-safe.
    await for (final _ in _db.clinicalChilds.watchLazy().asBroadcastStream()) {
      yield await listAll(limit: limit, facilityCode: facilityCode);
    }
  }

  Future<List<ClinicalChild>> search(String query, {int limit = 50, String? facilityCode}) async {
    final q = query.trim();
    final fc = (facilityCode ?? '').trim();
    if (q.isEmpty) {
      return listAll(limit: limit, facilityCode: fc);
    }

    final fetchLimit = fc.isEmpty ? limit : limit * 5;
    final found = await _db.clinicalChilds
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
        .limit(fetchLimit)
        .findAll();

    if (fc.isEmpty) return found.take(limit).toList();
    return found.where((child) => _matchesFacility(child, fc)).take(limit).toList();
  }

  Future<Set<String>> localChildIdsForFacility(String? facilityCode, {int limit = 10000}) async {
    final children = await listAll(limit: limit, facilityCode: facilityCode);
    return children.map((c) => c.localChildId).toSet();
  }

  Future<int> countDraftOrQueued({String? facilityCode}) async {
    // Isar query generator doesn't always produce `NotEqualTo` helpers for String fields.
    // Use `not().statusEqualTo(...)` which is supported.
    final found = await _db.clinicalChilds.filter().not().statusEqualTo('SYNCED').findAll();
    return found.where((child) => _matchesFacility(child, facilityCode)).length;
  }
}
