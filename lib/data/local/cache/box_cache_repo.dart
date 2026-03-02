import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/box_cache.dart';

class BoxCacheRepo {
  Isar get _db => IsarService.instance.isar;

  // Share one broadcast change stream so multiple widgets can listen safely.
  late final Stream<void> _changes = _db.boxCaches.watchLazy().asBroadcastStream();

  Future<int> count() async {
    return _db.boxCaches.count();
  }

  Stream<int> watchCount() {
    return _changes.asyncMap((_) => _db.boxCaches.count());
  }

  Future<BoxCache?> findByUid(String boxUid) async {
    final uid = boxUid.trim();
    if (uid.isEmpty) return null;
    return _db.boxCaches.filter().boxUidEqualTo(uid).findFirst();
  }

  Future<List<BoxCache>> findManyByUids(List<String> boxUids) async {
    final cleaned = boxUids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) return const [];

    // Efficient Isar query: anyOf
    return _db.boxCaches
        .filter()
        .anyOf(cleaned, (q, uid) => q.boxUidEqualTo(uid))
        .findAll();
  }

  Future<void> upsertAll(List<BoxCache> boxes) async {
    await _db.writeTxn(() async {
      await _db.boxCaches.putAll(boxes);
    });
  }

  /// Upsert minimal box records by UID (creates missing ones).
  ///
  /// Useful for receiving: we may only have QR scans (boxUid) and still want the
  /// box to appear in local "store" immediately, even before a full download.
  Future<void> upsertMinimalMany({
    required List<String> boxUids,
    required String status,
    String? currentFacilityId,
    String? batchNo,
    DateTime? expiryDate,
  }) async {
    final cleaned = boxUids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) return;

    await _db.writeTxn(() async {
      final existing = await _db.boxCaches
          .filter()
          .anyOf(cleaned, (q, uid) => q.boxUidEqualTo(uid))
          .findAll();

      final byUid = {for (final b in existing) b.boxUid: b};

      final upserts = <BoxCache>[];
      for (final uid in cleaned) {
        final b = byUid[uid] ?? BoxCache()..boxUid = uid;
        b.status = status;
        b.currentFacilityId = currentFacilityId;
        if (batchNo != null && batchNo.trim().isNotEmpty) b.batchNo = batchNo.trim();
        if (expiryDate != null) b.expiryDate = expiryDate;
        b.updatedAt = DateTime.now();
        upserts.add(b);
      }
      await _db.boxCaches.putAll(upserts);
    });
  }

  /// Upsert from parsed QR scan payloads.
  ///
  /// Expected scan JSON shape includes at least { boxUid: "..." } and may include
  /// batchNo + expiryDate.
  Future<void> upsertFromScans({
    required List<Map<String, dynamic>> scans,
    required String status,
    String? currentFacilityId,
  }) async {
    final uids = scans
        .map((m) => (m['boxUid'] ?? '').toString().trim())
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();
    if (uids.isEmpty) return;

    await _db.writeTxn(() async {
      final existing = await _db.boxCaches
          .filter()
          .anyOf(uids, (q, uid) => q.boxUidEqualTo(uid))
          .findAll();
      final byUid = {for (final b in existing) b.boxUid: b};

      final upserts = <BoxCache>[];
      for (final scan in scans) {
        final uid = (scan['boxUid'] ?? '').toString().trim();
        if (uid.isEmpty) continue;

        final b = byUid[uid] ?? BoxCache()..boxUid = uid;
        b.status = status;
        b.currentFacilityId = currentFacilityId;

        final batch = (scan['batchNo'] ?? scan['batch'] ?? '').toString().trim();
        if (batch.isNotEmpty) b.batchNo = batch;

        final expRaw = (scan['expiryDate'] ?? scan['expiry'] ?? '').toString().trim();
        if (expRaw.isNotEmpty) {
          final parsed = DateTime.tryParse(expRaw);
          if (parsed != null) b.expiryDate = parsed;
        }

        b.updatedAt = DateTime.now();
        upserts.add(b);
      }

      if (upserts.isNotEmpty) {
        await _db.boxCaches.putAll(upserts);
      }
    });
  }

  Future<List<BoxCache>> listByFacility({
    required String facilityId,
    required String status,
    int limit = 5000,
  }) async {
    return _db.boxCaches
        .filter()
        .currentFacilityIdEqualTo(facilityId)
        .and()
        .statusEqualTo(status)
        .limit(limit)
        .findAll();
  }

  Stream<List<BoxCache>> watchByFacility({
    required String facilityId,
    required String status,
    int limit = 5000,
  }) async* {
    yield await listByFacility(facilityId: facilityId, status: status, limit: limit);
    await for (final _ in _changes) {
      yield await listByFacility(facilityId: facilityId, status: status, limit: limit);
    }
  }

  Future<void> updateStatusMany({
    required List<String> boxUids,
    required String status,
    String? currentFacilityId,
  }) async {
    final cleaned = boxUids
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
    if (cleaned.isEmpty) return;

    await _db.writeTxn(() async {
      final matches = await _db.boxCaches
          .filter()
          .anyOf(cleaned, (q, uid) => q.boxUidEqualTo(uid))
          .findAll();

      for (final b in matches) {
        b.status = status;
        b.currentFacilityId = currentFacilityId;
        b.updatedAt = DateTime.now();
      }
      await _db.boxCaches.putAll(matches);
    });
  }

  Future<void> clear() async {
    await _db.writeTxn(() async {
      await _db.boxCaches.clear();
    });
  }
}
