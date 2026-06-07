import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/local/sync/sync_queue_repo.dart';
import 'pull_refresh_service.dart';
import 'sync_service.dart';

/// Runs two-way sync automatically while the app is open.
///
/// Primary behaviour:
/// - PUSH pending local queue items automatically.
/// - PULL latest server-confirmed facility stock and recent clinical data.
/// - Run when internet returns, app opens/resumes, queue changes, and periodically.
///
/// The manual Sync button remains as a backup.
class AutoSyncService {
  AutoSyncService._();

  static final AutoSyncService instance = AutoSyncService._();

  final Connectivity _connectivity = Connectivity();
  final SyncQueueRepo _queueRepo = SyncQueueRepo();
  final SyncService _syncService = SyncService();
  final PullRefreshService _pullRefreshService = PullRefreshService();

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  StreamSubscription<SyncQueueCounts>? _queueSub;
  Timer? _periodicTimer;

  bool _started = false;
  bool _syncing = false;
  DateTime? _lastAutoAttemptAt;
  DateTime? _lastPullRefreshAt;

  static const Duration _normalAutoCooldown = Duration(seconds: 20);
  static const Duration _pullCooldown = Duration(minutes: 2);

  bool _networkLooksAvailable(List<ConnectivityResult> results) {
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      if (_networkLooksAvailable(results)) {
        // Internet came back: immediately push local data and pull latest server data.
        forceSync(reason: 'connectivity_restored');
      }
    });

    _queueSub = _queueRepo.watchCounts().listen((counts) {
      final unsynced = counts.pending + counts.failed;
      if (unsynced > 0) {
        // New data was queued, or an item moved state. Try push+pull if online.
        syncIfNeeded(reason: 'queue_changed');
      }
    });

    _periodicTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      // Even if this phone has nothing to push, it still needs to pull updates
      // entered by other devices in the same facility.
      syncIfNeeded(reason: 'periodic_two_way_check');
    });

    // On app open, run two-way sync once. This catches data entered while the app was closed.
    await forceSync(reason: 'app_started');
  }

  Future<void> stop() async {
    _started = false;
    await _connectivitySub?.cancel();
    await _queueSub?.cancel();
    _periodicTimer?.cancel();
    _connectivitySub = null;
    _queueSub = null;
    _periodicTimer = null;
  }

  /// Force sync is used when internet returns or the app resumes.
  /// It resets retry windows so previously failed items are not left waiting.
  Future<SyncRunResult?> forceSync({String reason = 'force'}) async {
    return _run(reason: reason, force: true);
  }

  /// Normal automatic sync is used after saves and periodic checks.
  /// It avoids hammering the backend if a server-side error keeps failing.
  Future<SyncRunResult?> syncIfNeeded({String reason = 'auto'}) async {
    return _run(reason: reason, force: false);
  }

  Future<SyncRunResult?> _run({required String reason, required bool force}) async {
    if (!_started || _syncing) return null;

    final now = DateTime.now();
    if (!force && _lastAutoAttemptAt != null) {
      final elapsed = now.difference(_lastAutoAttemptAt!);
      if (elapsed < _normalAutoCooldown) return null;
    }

    final online = await _syncService.isOnline();
    if (!online) return null;

    _syncing = true;
    _lastAutoAttemptAt = now;

    try {
      // If the app was killed mid-sync, some records may remain stuck in SENDING.
      await _queueRepo.recoverStaleSendingItems();

      if (force) {
        // Internet has come back, so do not wait for previous retry backoff.
        await _queueRepo.resetRetryWindowsForAllPendingAndFailed();
      }

      final counts = await _queueRepo.counts();
      final unsynced = counts.pending + counts.failed;

      SyncRunResult? pushResult;
      if (unsynced > 0) {
        pushResult = await _syncService.syncNow(
          limit: 100,
          ignoreBackoff: force,
          pullAfterPush: false,
        );
      }

      // Pull latest server data even when this phone has nothing to push.
      // This is what allows multiple users/devices in one facility to see each
      // other's server-synced stock and child updates automatically.
      final shouldPull = force || _lastPullRefreshAt == null || now.difference(_lastPullRefreshAt!) >= _pullCooldown;
      if (shouldPull) {
        await _pullRefreshService.refreshFromServer();
        _lastPullRefreshAt = DateTime.now();
      }

      return pushResult ?? const SyncRunResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        online: true,
      );
    } catch (_) {
      // Automatic sync must never block the user or crash the app.
      return null;
    } finally {
      _syncing = false;
    }
  }
}
