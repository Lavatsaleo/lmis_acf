import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/facility_cache.dart';

class FacilityCacheRepo {
  Isar get _db => IsarService.instance.isar;

  // Share one broadcast change stream so multiple widgets can listen safely.
  late final Stream<void> _changes = _db.facilityCaches.watchLazy().asBroadcastStream();

  Future<int> count() async {
    return _db.facilityCaches.count();
  }

  Stream<int> watchCount() {
    return _changes.asyncMap((_) => _db.facilityCaches.count());
  }

  Future<List<FacilityCache>> listAll() async {
    return _db.facilityCaches.where().sortByName().findAll();
  }

  Future<FacilityCache?> findById(String facilityId) async {
    final id = facilityId.trim();
    if (id.isEmpty) return null;
    return _db.facilityCaches.filter().facilityIdEqualTo(id).findFirst();
  }

  Future<void> upsertAll(List<FacilityCache> facilities) async {
    await _db.writeTxn(() async {
      await _db.facilityCaches.putAll(facilities);
    });
  }

  Future<void> clear() async {
    await _db.writeTxn(() async {
      await _db.facilityCaches.clear();
    });
  }
}
