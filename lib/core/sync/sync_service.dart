import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';

import 'pull_refresh_service.dart';
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
  final PullRefreshService _pullRefreshService;

  SyncService({
    SyncQueueRepo? queueRepo,
    AppSettingsRepo? settingsRepo,
    Connectivity? connectivity,
    ClinicalChildRepo? childRepo,
    ClinicalAssessmentRepo? assessRepo,
    BoxCacheRepo? boxRepo,
    SessionStore? sessionStore,
    PullRefreshService? pullRefreshService,
  })  : _queueRepo = queueRepo ?? SyncQueueRepo(),
        _settingsRepo = settingsRepo ?? AppSettingsRepo(),
        _connectivity = connectivity ?? Connectivity(),
        _childRepo = childRepo ?? ClinicalChildRepo(),
        _assessRepo = assessRepo ?? ClinicalAssessmentRepo(),
        _boxRepo = boxRepo ?? BoxCacheRepo(),
        _sessionStore = sessionStore ?? SessionStore(),
        _pullRefreshService = pullRefreshService ?? PullRefreshService();

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
  Future<SyncRunResult> syncNow({
    int limit = 25,
    bool ignoreBackoff = true,
    bool pullAfterPush = true,
  }) async {
    final online = await isOnline();
    if (!online) {
      return const SyncRunResult(
        attempted: 0,
        sent: 0,
        failed: 0,
        online: false,
      );
    }

    // Recover items that may have been left in SENDING if the app was closed
    // or crashed during a previous sync attempt.
    await _queueRepo.recoverStaleSendingItems();

    final baseUrl = await _settingsRepo.getBaseUrl();
    final api = ApiClient.create(baseUrl: baseUrl);

    final items = await _queueRepo.listForSync(limit: limit);
    int attempted = 0;
    int sent = 0;
    int failed = 0;

    for (final item in items) {
      // Respect backoff window only for background/automatic sync calls.
      // Manual/user-triggered sync uses ignoreBackoff=true so failed items never get
      // stuck behind long retry windows.
      if (!ignoreBackoff && !_canAttemptNow(item)) continue;

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
      } on DioException catch (e) {
        final statusCode = e.response?.statusCode ?? 0;
        final responseJson = _safeStringify(e.response?.data);

        // Important offline/idempotency fix:
        // Sometimes the server successfully saves a record but the phone loses the
        // response. On retry, the backend may return 409 duplicate. For clinical
        // enrollments/follow-ups, a duplicate with the existing server record means
        // the local item can safely be considered synced instead of being stuck forever.
        if (_shouldTreatHttpErrorAsAlreadySynced(item, e)) {
          await _applySuccessSideEffects(item, e.response?.data);
          sent += 1;
          await _queueRepo.markAsSent(
            queueId: item.queueId,
            httpStatus: statusCode,
            responseJson: responseJson,
          );
          await _refreshFacilityStoreSummaryCache(api, item: item);
          continue;
        }

        failed += 1;
        await _maybeRefreshStoreSummaryAfterError(api, e);
        await _queueRepo.markAsFailed(
          queueId: item.queueId,
          error: _friendlySyncError(e),
        );
      } catch (e) {
        failed += 1;
        await _maybeRefreshStoreSummaryAfterError(api, e);
        await _queueRepo.markAsFailed(
          queueId: item.queueId,
          error: e.toString(),
        );
      }
    }

    if (pullAfterPush) {
      try {
        // Two-way sync: after pushing local queue items, pull latest server-confirmed
        // stock and recent facility clinical records so other devices' updates appear locally.
        await _pullRefreshService.refreshFromServer();
      } catch (_) {
        // Pull refresh must never make a successful push look failed.
      }
    }

    return SyncRunResult(
      attempted: attempted,
      sent: sent,
      failed: failed,
      online: true,
    );
  }

  Future<PullRefreshResult> pullLatestFromServer({
    int recentChildrenTake = 200,
    bool includeAppointments = true,
  }) {
    return _pullRefreshService.refreshFromServer(
      recentChildrenTake: recentChildrenTake,
      includeAppointments: includeAppointments,
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


  bool _shouldTreatHttpErrorAsAlreadySynced(
    SyncQueueItem item,
    DioException error,
  ) {
    final statusCode = error.response?.statusCode ?? 0;
    if (statusCode != 409) return false;

    final data = error.response?.data;
    Map<String, dynamic>? m;
    if (data is Map) {
      m = data.cast<String, dynamic>();
    } else if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) m = decoded.cast<String, dynamic>();
      } catch (_) {
        m = null;
      }
    }
    if (m == null) return false;

    if (item.entityType == 'clinical_enroll') {
      return m['child'] is Map;
    }

    if (item.entityType == 'clinical_followup') {
      return m['existingVisit'] is Map || m['visit'] is Map;
    }

    return false;
  }

  String _friendlySyncError(DioException error) {
    final statusCode = error.response?.statusCode;
    final dataText = _truncate(_safeStringify(error.response?.data), 600);

    if (statusCode == 401) {
      return 'LOGIN_REQUIRED: Your session expired. Log in again, then tap Sync now. Your unsynced data is still saved on this device.';
    }

    if (statusCode == 403) {
      return 'FORBIDDEN: Your account does not have permission to sync this record. Contact the system administrator.';
    }

    if (statusCode != null) {
      return 'HTTP $statusCode: $dataText';
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'NETWORK_TIMEOUT: The server took too long to respond. The record will retry.';
      case DioExceptionType.connectionError:
        return 'NETWORK_ERROR: Could not reach the server. Check internet connection and retry.';
      default:
        return error.message ?? error.toString();
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
        item.entityType != 'clinical_visit_update' &&
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

    // --- ENROLLMENT: map local child -> remote child and mark enrollment visit synced ---
    if (item.entityType == 'clinical_enroll') {
      final childJson = (m['child'] is Map)
          ? (m['child'] as Map).cast<String, dynamic>()
          : null;
      final assessmentJson = (m['assessment'] is Map)
          ? (m['assessment'] as Map).cast<String, dynamic>()
          : null;
      final visitJson = (m['visit'] is Map)
          ? (m['visit'] as Map).cast<String, dynamic>()
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

      var localAssessment = await _assessRepo.findByLocalAssessmentId(item.queueId);
      if (localAssessment == null) {
        final candidates = await _assessRepo.listForChild(item.localEntityId, limit: 20);
        for (final candidate in candidates) {
          if (candidate.status != 'SYNCED') {
            localAssessment = candidate;
            break;
          }
        }
      }

      if (localAssessment != null) {
        final visitId = visitJson?['id']?.toString().trim();
        final assessmentId = assessmentJson?['id']?.toString().trim();
        if (visitId != null && visitId.isNotEmpty) {
          localAssessment.remoteAssessmentId = 'visit:$visitId';
        } else if (assessmentId != null && assessmentId.isNotEmpty) {
          localAssessment.remoteAssessmentId = assessmentId;
        }
        localAssessment.status = 'SYNCED';
        if (AppConfig.purgeSensitiveAfterSync) {
          localAssessment.dataJson = _purgeAssessmentJson(localAssessment.dataJson);
        }
        await _assessRepo.upsert(localAssessment);
      }
      return;
    }

    // --- FOLLOW-UP / VISIT UPDATE: map local visit record -> remote ChildVisit id ---
    if (item.entityType == 'clinical_followup' || item.entityType == 'clinical_visit_update') {
      final visitJson = (m['visit'] is Map)
          ? (m['visit'] as Map).cast<String, dynamic>()
          : (m['existingVisit'] is Map)
              ? (m['existingVisit'] as Map).cast<String, dynamic>()
              : null;
      final local = await _assessRepo.findByLocalAssessmentId(item.localEntityId);
      if (local != null) {
        final remoteVisitId = visitJson?['id']?.toString().trim();
        if (remoteVisitId != null && remoteVisitId.isNotEmpty) {
          local.remoteAssessmentId = 'visit:$remoteVisitId';
        }
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
    var endpoint = item.endpoint;

    // Replace `{childId}` with the server-side child id.
    if (endpoint.contains('{childId}')) {
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
        return endpoint;
      }

      final child = await _childRepo.findByLocalId(localChildId.trim());
      final remote = child?.remoteChildId;
      if (remote == null || remote.trim().isEmpty) return endpoint;
      endpoint = endpoint.replaceAll('{childId}', remote.trim());
    }

    // Replace `{visitId}` with the server-side ChildVisit id.
    if (endpoint.contains('{visitId}')) {
      String? remoteVisitId;
      try {
        final p = item.payloadJson == null ? null : jsonDecode(item.payloadJson!);
        if (p is Map && p['remoteVisitId'] != null) {
          remoteVisitId = p['remoteVisitId'].toString();
        }
      } catch (_) {
        // ignore
      }

      remoteVisitId ??= await _remoteVisitIdForLocalAssessment(item.localEntityId);
      if (remoteVisitId == null || remoteVisitId.trim().isEmpty) return endpoint;
      endpoint = endpoint.replaceAll('{visitId}', remoteVisitId.trim());
    }

    return endpoint;
  }

  Future<String?> _remoteVisitIdForLocalAssessment(String localAssessmentId) async {
    final local = await _assessRepo.findByLocalAssessmentId(localAssessmentId);
    final raw = local?.remoteAssessmentId?.trim();
    if (raw == null || raw.isEmpty) return null;
    return raw.startsWith('visit:') ? raw.substring('visit:'.length) : raw;
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