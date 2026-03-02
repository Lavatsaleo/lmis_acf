import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'sync_queue_item.dart';
import 'facility_cache.dart';
import 'box_cache.dart';
import 'clinical_child.dart';
import 'clinical_assessment.dart';

/// Opens and holds the single Isar instance used by the app.
///
/// Offline-first rule: everything is written locally first.
class IsarService {
  IsarService._();

  static final IsarService instance = IsarService._();

  Isar? _isar;

  Isar get isar {
    final db = _isar;
    if (db == null) {
      throw StateError(
        'Isar is not initialized. Call IsarService.instance.init() before runApp().',
      );
    }
    return db;
  }

  Future<void> init() async {
    if (_isar != null) return;

    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      [
        SyncQueueItemSchema,
        FacilityCacheSchema,
        BoxCacheSchema,
        ClinicalChildSchema,
        ClinicalAssessmentSchema,
      ],
      directory: dir.path,
      inspector: true,
    );
  }
}
