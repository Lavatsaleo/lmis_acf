import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/local/settings/app_settings_repo.dart';
import '../../data/local/sync/sync_queue_repo.dart';
import '../../data/local/isar/sync_queue_item.dart';
import '../../data/local/clinical/clinical_child_repo.dart';
import '../../data/local/clinical/clinical_assessment_repo.dart';
import '../../data/local/cache/box_cache_repo.dart';
import '../../data/local/auth/session_store.dart';
import '../../data/remote/api_client.dart';
import '../config/app_config.dart';

class SyncRunResult {
  final int attempted;
  final int sent;
  final int failed;
  final bool online;

  const SyncRunResult({
    required this.attempted,
    required this.sent,
    required this.failed,
    required this.online,
  });
}

/// Step 2: Sends queued items to your backend when online.
///
/// - Offline-first: never blocks the user; always write locally first.
/// - Safe retries with backoff.
class SyncService {
  final SyncQueueRepo _queueRepo;
  final AppSettingsRepo _settingsRepo;
  final Connectivity _connectivity;
  final ClinicalChildRepo _childRepo;
  final ClinicalAssessmentRepo _assessRepo;
  final BoxCacheRepo _boxRepo;
  final SessionStore _sessionStore;

  SyncService({
    SyncQueueRepo? queueRepo,
    AppSettingsRepo? settingsRepo,
    Connectivity? connectivity,
    ClinicalChildRepo? childRepo,
    ClinicalAssessmentRepo? assessRepo,
    BoxCacheRepo? boxRepo,
    SessionStore? sessionStore,
  })  : _queueRepo = queueRepo ?? SyncQueueRepo(),
        _settingsRepo = settingsRepo ?? AppSettingsRepo(),
        _connectivity = connectivity ?? Connectivity(),
        _childRepo = childRepo ?? ClinicalChildRepo(),
        _assessRepo = assessRepo ?? ClinicalAssessmentRepo(),
        _boxRepo = boxRepo ?? BoxCacheRepo(),
        _sessionStore = sessionStore ?? SessionStore();

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  Duration _backoffForAttempts(int attempts) {
    // attempts starts at 0; after a failure we increment to 1,2,...
    if (attempts <= 0) return Duration.zero;
    const scheduleMinutes = [1, 5, 15, 60, 240];
    final idx = (attempts - 1).clamp(0, scheduleMinutes.length - 1);
    return Duration(minutes: scheduleMinutes[idx]);
  }

  bool _canAttemptNow(SyncQueueItem item) {
    if (item.lastAttemptAt == null) return true;
    final wait = _backoffForAttempts(item.attempts);
    return DateTime.now().isAfter(item.lastAttemptAt!.add(wait));
  }

  Future<bool> _dependencyIsReady(SyncQueueItem item) async {
    final dep = item.dependsOnLocalEntityId?.trim();
    if (dep == null || dep.isEmpty) return true;

    // Case 1: dependency was created locally and already synced through queue
    final queuedDepSynced = await _queueRepo.isLocalEntitySynced(dep);
    if (queuedDepSynced) return true;

    // Case 2: dependency is a child that already exists on the server
    // and was downloaded/imported locally, so it has a remoteChildId.
    final child = await _childRepo.findByLocalId(dep);
    final remoteChildId = child?.remoteChildId?.trim();
    if (remoteChildId != null && remoteChildId.isNotEmpty) return true;

    return false;
  }

  /// Sync queued items now.
  ///
  /// Returns counts for UI.
  Future<SyncRunResult> syncNow({int limit = 25}) async {
    final online = await isOnline();
    if (!online) {
      return const SyncRunResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        online: false,
      );
    }

    final baseUrl = await _settingsRepo.getBaseUrl();
    final api = ApiClient.create(baseUrl: baseUrl);

    final items = await _queueRepo.listForSync(limit: limit);
    int attempted = 0;
    int sent = 0;
    int failed = 0;

    for (final item in items) {
      // Hard stop: too many attempts.
      if (item.attempts >= AppConfig.maxSyncAttempts) continue;

      // Respect backoff window.
      if (!_canAttemptNow(item)) continue;

      // Do not send if the dependency is not yet ready.
      if (!await _dependencyIsReady(item)) {
        continue;
      }

      attempted += 1;
      await _queueRepo.markAsSending(item.queueId);

      try {
        final path = await _resolveEndpoint(item);
        final headers = <String, dynamic>{
          'X-Queue-Id': item.queueId,
          if (item.idempotencyKey != null &&
              item.idempotencyKey!.trim().isNotEmpty)
            'X-Idempotency-Key': item.idempotencyKey!.trim(),
        };

        final resp = await api.request(
          method: item.method,
          path: path,
          headers: headers,
          data: item.payloadJson,
        );

        final statusCode = resp.statusCode ?? 0;
        final responseJson = _safeStringify(resp.data);

        if (statusCode >= 200 && statusCode < 300) {
          await _applySuccessSideEffects(item, resp.data);

          sent += 1;
          await _queueRepo.markAsSent(
            queueId: item.queueId,
            httpStatus: statusCode,
            responseJson: responseJson,
          );
          await _refreshFacilityStoreSummaryCache(api, item: item);
        } else {
          failed += 1;
          await _queueRepo.markAsFailed(
            queueId: item.queueId,
            error: 'HTTP $statusCode: ${_truncate(responseJson, 600)}',
          );
        }
      } catch (e) {
        failed += 1;
        await _maybeRefreshStoreSummaryAfterError(api, e);
        await _queueRepo.markAsFailed(
          queueId: item.queueId,
          error: e.toString(),
        );
      }
    }

    return SyncRunResult(
      attempted: attempted,
      sent: sent,
      failed: failed,
      online: true,
    );
  }

  Future<void> _maybeRefreshStoreSummaryAfterError(
    ApiClient api,
    Object error,
  ) async {
    final text = error.toString();
    if (!text.contains('409')) return;
    try {
      await _refreshFacilityStoreSummaryCache(api);
    } catch (_) {
      // ignore secondary refresh errors
    }
  }

  Future<void> _refreshFacilityStoreSummaryCache(
    ApiClient api, {
    SyncQueueItem? item,
  }) async {
    try {
      final me = await _sessionStore.readUserJson();
      final facilityId = (me?['facilityId'] ?? '').toString().trim();
      if (facilityId.isEmpty) return;

      final resp = await api.request(
        method: 'GET',
        path: AppConfig.facilityStoreSummaryPath,
      );
      final data = resp.data;
      if (data is! Map) return;

      final m = data.cast<String, dynamic>();
      final boxesRaw = m['boxes'];
      final boxes = <Map<String, dynamic>>[];
      if (boxesRaw is List) {
        for (final row in boxesRaw.whereType<Map>()) {
          boxes.add(row.cast<String, dynamic>());
        }
      }

      final totalSachetsRemaining = (m['totalSachetsRemaining'] is num)
          ? (m['totalSachetsRemaining'] as num).round()
          : 0;
      final boxesInStore = (m['boxesInStore'] is num)
          ? (m['boxesInStore'] as num).round()
          : boxes.length;

      await _settingsRepo.cacheFacilityStoreSummary(
        facilityId: facilityId,
        totalSachetsRemaining: totalSachetsRemaining,
        boxesInStore: boxesInStore,
      );
      await _boxRepo.upsertFromStoreSummary(
        boxes: boxes,
        facilityId: facilityId,
      );
    } catch (_) {
      // Do not fail sync because store refresh failed.
    }
  }

  Future<void> _applySuccessSideEffects(
    SyncQueueItem item,
    dynamic responseData,
  ) async {
    // Handle receive transactions (update local store cache).
    if (item.entityType == 'receive') {
      try {
        final payload = item.payloadJson == null
            ? null
            : jsonDecode(item.payloadJson!);
        if (payload is Map) {
          final boxUidsRaw = payload['boxUids'];
          final toFacilityId = payload['toFacilityId']?.toString();
          if (boxUidsRaw is List) {
            final boxUids = boxUidsRaw.map((e) => e.toString()).toList();
            await _boxRepo.upsertMinimalMany(
              boxUids: boxUids,
              status: 'IN_FACILITY',
              currentFacilityId:
                  (toFacilityId != null && toFacilityId.trim().isNotEmpty)
                  ? toFacilityId.trim()
                  : null,
            );
          }
        }
      } catch (_) {
        // ignore
      }
      return;
    }

    if (item.entityType != 'clinical_enroll' &&
        item.entityType != 'clinical_followup' &&
        item.entityType != 'clinical_discharge') {
      return;
    }

    Map<String, dynamic>? m;
    try {
      if (responseData is Map) {
        m = responseData.cast<String, dynamic>();
      } else if (responseData is String && responseData.trim().isNotEmpty) {
        m = jsonDecode(responseData) as Map<String, dynamic>;
      }
    } catch (_) {
      m = null;
    }
    if (m == null) return;

    // --- ENROLLMENT: map local child -> remote child and mark enrollment assessment synced ---
    if (item.entityType == 'clinical_enroll') {
      final childJson = (m['child'] is Map)
          ? (m['child'] as Map).cast<String, dynamic>()
          : null;
      final assessmentJson = (m['assessment'] is Map)
          ? (m['assessment'] as Map).cast<String, dynamic>()
          : null;

      if (childJson != null) {
        final local = await _childRepo.findByLocalId(item.localEntityId);
        if (local != null) {
          local.remoteChildId = childJson['id']?.toString();
          local.uniqueChildNumber =
              childJson['uniqueChildNumber']?.toString() ??
              local.uniqueChildNumber;
          local.status = 'SYNCED';
          await _childRepo.upsert(local);
        }
      }

      if (assessmentJson != null) {
        final list = await _assessRepo.listForChild(item.localEntityId, limit: 20);
        for (final a in list) {
          if (a.status != 'SYNCED') {
            a.remoteAssessmentId = assessmentJson['id']?.toString();
            a.status = 'SYNCED';
            if (AppConfig.purgeSensitiveAfterSync) {
              a.dataJson = _purgeAssessmentJson(a.dataJson);
            }
            await _assessRepo.upsert(a);
            break;
          }
        }
      }
      return;
    }

    // --- FOLLOW-UP VISIT: map local follow-up record -> remote ChildVisit id ---
    if (item.entityType == 'clinical_followup') {
      final visitJson = (m['visit'] is Map)
          ? (m['visit'] as Map).cast<String, dynamic>()
          : null;
      final local = await _assessRepo.findByLocalAssessmentId(item.localEntityId);
      if (local != null) {
        local.remoteAssessmentId =
            visitJson?['id']?.toString() ?? local.remoteAssessmentId;
        local.status = 'SYNCED';
        await _assessRepo.upsert(local);
      }
      return;
    }

    // --- DISCHARGE ASSESSMENT: map local discharge -> remote InDepthAssessment id ---
    if (item.entityType == 'clinical_discharge') {
      final assessmentJson = (m['assessment'] is Map)
          ? (m['assessment'] as Map).cast<String, dynamic>()
          : null;
      final local = await _assessRepo.findByLocalAssessmentId(item.localEntityId);
      if (local != null) {
        local.remoteAssessmentId =
            assessmentJson?['id']?.toString() ?? local.remoteAssessmentId;
        local.status = 'SYNCED';
        if (AppConfig.purgeSensitiveAfterSync) {
          local.dataJson = _purgeAssessmentJson(local.dataJson);
        }
        await _assessRepo.upsert(local);
      }
      return;
    }
  }

  Future<String> _resolveEndpoint(SyncQueueItem item) async {
    // Replace `{childId}` with the server-side child id.
    if (!item.endpoint.contains('{childId}')) return item.endpoint;

    // For follow-up/discharge we always set dependsOnLocalEntityId = localChildId.
    String? localChildId = item.dependsOnLocalEntityId;
    if (localChildId == null || localChildId.trim().isEmpty) {
      try {
        final p = item.payloadJson == null ? null : jsonDecode(item.payloadJson!);
        if (p is Map && p['localChildId'] != null) {
          localChildId = p['localChildId'].toString();
        }
      } catch (_) {
        // ignore
      }
    }

    if (localChildId == null || localChildId.trim().isEmpty) {
      return item.endpoint;
    }

    final child = await _childRepo.findByLocalId(localChildId.trim());
    final remote = child?.remoteChildId;
    if (remote == null || remote.trim().isEmpty) return item.endpoint;

    return item.endpoint.replaceAll('{childId}', remote.trim());
  }

  String _purgeAssessmentJson(String raw) {
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      final minimal = <String, dynamic>{
        '_purged': true,
        'encounterType': m['encounterType'],
        'anthropometry': m['anthropometry'],
        'visit': m['visit'],
        'exit': m['exit'],
        'derived': m['derived'],
      };
      return jsonEncode(minimal);
    } catch (_) {
      return jsonEncode({'_purged': true});
    }
  }

  String _safeStringify(dynamic data) {
    if (data == null) return '';
    if (data is String) return data;
    try {
      return jsonEncode(data);
    } catch (_) {
      return data.toString();
    }
  }

  String _truncate(String s, int max) {
    final t = s.trim();
    if (t.length <= max) return t;
    return '${t.substring(0, max)}…';
  }
}