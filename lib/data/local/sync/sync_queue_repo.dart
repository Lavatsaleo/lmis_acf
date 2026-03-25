import 'dart:async';

import 'package:isar/isar.dart';

import '../isar/isar_service.dart';
import '../isar/sync_queue_item.dart';

class SyncQueueCounts {
  final int pending;
  final int failed;
  final int sent;

  const SyncQueueCounts({
    required this.pending,
    required this.failed,
    required this.sent,
  });
}

/// Small repository for managing the sync queue locally.
///
/// No networking happens here (Step 1). We only queue and inspect items.
class SyncQueueRepo {
  Isar get _isar => IsarService.instance.isar;

  // Isar change streams may be single-subscription depending on platform/build.
  // We create ONE broadcast stream and share it across the app (MainShell + HomeScreen
  // can both listen without "Bad state: Stream has already been listened to".
  late final Stream<void> _changes = _isar.syncQueueItems.watchLazy().asBroadcastStream();

  Future<void> enqueue(SyncQueueItem item) async {
    await _isar.writeTxn(() async {
      await _isar.syncQueueItems.put(item);
    });
  }

  /// Insert a queue item OR replace an existing one with the same `queueId`.
  ///
  /// We use this for "Edit after save" workflows: if a clinician edits a record
  /// that has not synced yet, we update the already-queued payload instead of
  /// adding a duplicate queue item.
  Future<void> enqueueOrReplace(SyncQueueItem item) async {
    final existing = await _isar.syncQueueItems.filter().queueIdEqualTo(item.queueId).findFirst();
    await _isar.writeTxn(() async {
      if (existing != null) {
        // Preserve internal Isar primary key so this becomes an UPDATE.
        item.id = existing.id;
      }
      await _isar.syncQueueItems.put(item);
    });
  }

  Future<SyncQueueCounts> counts() async {
    final pending = await _isar.syncQueueItems.filter().statusEqualTo(SyncStatus.pending).count();
    final failed = await _isar.syncQueueItems.filter().statusEqualTo(SyncStatus.failed).count();
    final sent = await _isar.syncQueueItems.filter().statusEqualTo(SyncStatus.sent).count();
    return SyncQueueCounts(pending: pending, failed: failed, sent: sent);
  }

  Stream<SyncQueueCounts> watchCounts() async* {
    // Emit immediately
    yield await counts();

    // Any change to the collection triggers a refresh.
    await for (final _ in _changes) {
      yield await counts();
    }
  }

  Future<List<SyncQueueItem>> listLatest({int limit = 50}) async {
    return _isar.syncQueueItems.where().sortByCreatedAtDesc().limit(limit).findAll();
  }

  /// Find the most recent queue item for a given entity type + local entity id.
  ///
  /// Useful for "edit after save" flows where we need to update an already queued
  /// payload (e.g., editing an enrollment form before it has synced).
  Future<SyncQueueItem?> findLatestForEntity(String entityType, String localEntityId) {
    return _isar.syncQueueItems
        .filter()
        .entityTypeEqualTo(entityType)
        .localEntityIdEqualTo(localEntityId)
        .sortByCreatedAtDesc()
        .findFirst();
  }

  Stream<List<SyncQueueItem>> watchLatest({int limit = 50}) async* {
    yield await listLatest(limit: limit);
    await for (final _ in _changes) {
      yield await listLatest(limit: limit);
    }
  }

  /// Items eligible to be synced (pending/failed), oldest-first.
  Future<List<SyncQueueItem>> listForSync({int limit = 25}) async {
    // NOTE: Isar doesn't have an "in" filter for enums in the generated API,
    // so we query pending and failed separately and merge.
    final pending = await _isar.syncQueueItems
        .filter()
        .statusEqualTo(SyncStatus.pending)
        .sortByCreatedAt()
        .limit(limit)
        .findAll();

    if (pending.length >= limit) return pending;

    final remaining = limit - pending.length;
    final failed = await _isar.syncQueueItems
        .filter()
        .statusEqualTo(SyncStatus.failed)
        .sortByCreatedAt()
        .limit(remaining)
        .findAll();

    return [...pending, ...failed];
  }

  Future<bool> isLocalEntitySynced(String localEntityId) async {
    final found = await _isar.syncQueueItems
        .filter()
        .localEntityIdEqualTo(localEntityId)
        .statusEqualTo(SyncStatus.sent)
        .findFirst();
    return found != null;
  }

  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.syncQueueItems.clear();
    });
  }

  Future<void> deleteByQueueId(String queueId) async {
    final q = queueId.trim();
    if (q.isEmpty) return;
    final item = await _isar.syncQueueItems.filter().queueIdEqualTo(q).findFirst();
    if (item == null) return;
    await _isar.writeTxn(() async {
      await _isar.syncQueueItems.delete(item.id);
    });
  }

  /// Delete the most recent item for an entity type + localEntityId.
  /// Used for enrollment edits/deletes where queueId is random.
  Future<void> deleteLatestForEntity(String entityType, String localEntityId) async {
    final et = entityType.trim();
    final id = localEntityId.trim();
    if (et.isEmpty || id.isEmpty) return;
    final item = await _isar.syncQueueItems
        .filter()
        .entityTypeEqualTo(et)
        .localEntityIdEqualTo(id)
        .sortByCreatedAtDesc()
        .findFirst();
    if (item == null) return;
    await _isar.writeTxn(() async {
      await _isar.syncQueueItems.delete(item.id);
    });
  }

  Future<void> markAsSending(String queueId) async {
    final item = await _isar.syncQueueItems.filter().queueIdEqualTo(queueId).findFirst();
    if (item == null) return;
    await _isar.writeTxn(() async {
      item.status = SyncStatus.sending;
      item.lastAttemptAt = DateTime.now();
      await _isar.syncQueueItems.put(item);
    });
  }

  Future<void> markAsSent({
    required String queueId,
    int? httpStatus,
    String? responseJson,
  }) async {
    final item = await _isar.syncQueueItems.filter().queueIdEqualTo(queueId).findFirst();
    if (item == null) return;
    await _isar.writeTxn(() async {
      item.status = SyncStatus.sent;
      item.httpStatus = httpStatus;
      item.responseJson = responseJson;
      item.sentAt = DateTime.now();
      await _isar.syncQueueItems.put(item);
    });
  }

  Future<void> markAsFailed({required String queueId, required String error}) async {
    final item = await _isar.syncQueueItems.filter().queueIdEqualTo(queueId).findFirst();
    if (item == null) return;

    await _isar.writeTxn(() async {
      item.status = SyncStatus.failed;
      item.lastError = error;
      item.lastAttemptAt = DateTime.now();
      item.attempts += 1;
      await _isar.syncQueueItems.put(item);
    });
  }

  Future<void> retryAllFailed() async {
    final failed = await _isar.syncQueueItems.filter().statusEqualTo(SyncStatus.failed).findAll();
    if (failed.isEmpty) return;

    await _isar.writeTxn(() async {
      for (final item in failed) {
        item.status = SyncStatus.pending;
        item.attempts = 0;
        item.lastAttemptAt = null;
        item.lastError = null;
        await _isar.syncQueueItems.put(item);
      }
    });
  }

  Future<void> resetRetryWindowsForAllPendingAndFailed() async {
    final pending = await _isar.syncQueueItems.filter().statusEqualTo(SyncStatus.pending).findAll();
    final failed = await _isar.syncQueueItems.filter().statusEqualTo(SyncStatus.failed).findAll();

    await _isar.writeTxn(() async {
      for (final item in [...pending, ...failed]) {
        item.attempts = 0;
        item.lastAttemptAt = null;
        item.lastError = null;

        if (item.status == SyncStatus.failed) {
          item.status = SyncStatus.pending;
        }

        await _isar.syncQueueItems.put(item);
      }
    });
  }
}