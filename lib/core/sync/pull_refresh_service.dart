import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../data/local/auth/session_store.dart';
import '../../data/local/cache/box_cache_repo.dart';
import '../../data/local/settings/app_settings_repo.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/clinical_remote_sync_service.dart';
import '../config/app_config.dart';

class PullRefreshResult {
  final bool online;
  final bool storeRefreshed;
  final int boxesUpdated;
  final int childrenImported;
  final int childrenFailed;

  const PullRefreshResult({
    required this.online,
    required this.storeRefreshed,
    required this.boxesUpdated,
    required this.childrenImported,
    required this.childrenFailed,
  });

  static const offline = PullRefreshResult(
    online: false,
    storeRefreshed: false,
    boxesUpdated: 0,
    childrenImported: 0,
    childrenFailed: 0,
  );
}

/// Pulls the latest server-confirmed facility data into the local phone cache.
///
/// This is the second half of two-way sync:
/// - PUSH is handled by SyncService.
/// - PULL is handled here.
///
/// Important multi-device rule:
/// The server is the source of truth. A phone may show a local offline estimate,
/// but whenever internet is available it should refresh facility stock and recent
/// clinical activity entered by other devices in the same facility.
class PullRefreshService {
  final Connectivity _connectivity;
  final AppSettingsRepo _settingsRepo;
  final SessionStore _sessionStore;
  final BoxCacheRepo _boxRepo;
  final ClinicalRemoteSyncService _clinicalRemote;

  PullRefreshService({
    Connectivity? connectivity,
    AppSettingsRepo? settingsRepo,
    SessionStore? sessionStore,
    BoxCacheRepo? boxRepo,
    ClinicalRemoteSyncService? clinicalRemote,
  })  : _connectivity = connectivity ?? Connectivity(),
        _settingsRepo = settingsRepo ?? AppSettingsRepo(),
        _sessionStore = sessionStore ?? SessionStore(),
        _boxRepo = boxRepo ?? BoxCacheRepo(),
        _clinicalRemote = clinicalRemote ?? ClinicalRemoteSyncService();

  Future<bool> isOnline() async {
    final results = await _connectivity.checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  Future<PullRefreshResult> refreshFromServer({
    int recentChildrenTake = 500,
    bool includeAppointments = true,
  }) async {
    if (!await isOnline()) return PullRefreshResult.offline;

    final me = await _sessionStore.readUserJson();
    final facilityId = (me?['facilityId'] ?? '').toString().trim();
    if (facilityId.isEmpty) {
      return const PullRefreshResult(
        online: true,
        storeRefreshed: false,
        boxesUpdated: 0,
        childrenImported: 0,
        childrenFailed: 0,
      );
    }

    var storeRefreshed = false;
    var boxesUpdated = 0;
    var childrenImported = 0;
    var childrenFailed = 0;

    try {
      boxesUpdated = await _refreshFacilityStoreSummary(facilityId);
      storeRefreshed = true;
    } catch (_) {
      // Do not stop clinical pull because store refresh failed.
    }

    try {
      final imported = await _refreshRecentFacilityChildren(
        take: recentChildrenTake,
        includeAppointments: includeAppointments,
      );
      childrenImported += imported.imported;
      childrenFailed += imported.failed;
    } catch (_) {
      // Automatic pull should never block the user.
      childrenFailed += 1;
    }

    return PullRefreshResult(
      online: true,
      storeRefreshed: storeRefreshed,
      boxesUpdated: boxesUpdated,
      childrenImported: childrenImported,
      childrenFailed: childrenFailed,
    );
  }

  Future<int> _refreshFacilityStoreSummary(String facilityId) async {
    final baseUrl = await _settingsRepo.getBaseUrl();
    final api = ApiClient.create(baseUrl: baseUrl);

    final resp = await api.request(
      method: 'GET',
      path: AppConfig.facilityStoreSummaryPath,
    );

    final data = _asMap(resp.data);
    if (data == null) return 0;

    final boxesRaw = data['boxes'];
    final boxes = <Map<String, dynamic>>[];
    if (boxesRaw is List) {
      for (final row in boxesRaw.whereType<Map>()) {
        boxes.add(row.cast<String, dynamic>());
      }
    }

    final totalSachetsRemaining = (data['totalSachetsRemaining'] is num)
        ? (data['totalSachetsRemaining'] as num).round()
        : 0;
    final boxesInStore = (data['boxesInStore'] is num)
        ? (data['boxesInStore'] as num).round()
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

    return boxes.length;
  }

  Future<_ClinicalPullCounts> _refreshRecentFacilityChildren({
    required int take,
    required bool includeAppointments,
  }) async {
    final summaries = <String, Map<String, dynamic>>{};

    final recentRows = await _clinicalRemote.fetchRecentFacilityChildren(take: take);
    for (final row in recentRows) {
      final summary = _summaryFromFacilityRow(row);
      final id = (summary['id'] ?? '').toString().trim();
      if (id.isNotEmpty) summaries[id] = summary;
    }

    if (includeAppointments) {
      final today = DateTime.now();
      final appointmentRows = await _clinicalRemote.fetchFacilityAppointments(today);
      for (final row in appointmentRows) {
        final summary = _summaryFromFacilityRow(row);
        final id = (summary['id'] ?? '').toString().trim();
        if (id.isNotEmpty) {
          summaries.update(
            id,
            (existing) => _mergeSummary(existing, summary),
            ifAbsent: () => summary,
          );
        }
      }
    }

    var imported = 0;
    var failed = 0;

    for (final summary in summaries.values) {
      try {
        await _clinicalRemote.importChildSummaryMap(summary);
        imported += 1;
      } catch (_) {
        failed += 1;
      }
    }

    return _ClinicalPullCounts(imported: imported, failed: failed);
  }

  Map<String, dynamic> _summaryFromFacilityRow(Map<String, dynamic> row) {
    final child = (row['child'] is Map)
        ? (row['child'] as Map).cast<String, dynamic>()
        : row.cast<String, dynamic>();

    final summary = <String, dynamic>{...child};

    final caregiver = child['caregiver'];
    if (caregiver is Map) {
      summary['caregiver'] = caregiver.cast<String, dynamic>();
    }

    final visits = <Map<String, dynamic>>[];
    for (final key in ['visit', 'latestVisit', 'latestAppointmentVisit']) {
      final v = row[key];
      if (v is Map && v.isNotEmpty) {
        visits.add(v.cast<String, dynamic>());
      }
    }
    if (visits.isNotEmpty) {
      summary['visits'] = _uniqueByIdOrDate(visits);
    }

    final assessments = <Map<String, dynamic>>[];
    final assessment = row['assessment'];
    if (assessment is Map && assessment.isNotEmpty) {
      assessments.add(assessment.cast<String, dynamic>());
    }
    if (assessments.isNotEmpty) {
      summary['inDepthAssessments'] = _uniqueByIdOrDate(assessments);
    }

    return summary;
  }

  Map<String, dynamic> _mergeSummary(
    Map<String, dynamic> first,
    Map<String, dynamic> second,
  ) {
    final merged = <String, dynamic>{...first, ...second};

    final visits = <Map<String, dynamic>>[];
    for (final source in [first['visits'], second['visits']]) {
      if (source is List) {
        for (final v in source.whereType<Map>()) {
          visits.add(v.cast<String, dynamic>());
        }
      }
    }
    if (visits.isNotEmpty) merged['visits'] = _uniqueByIdOrDate(visits);

    final assessments = <Map<String, dynamic>>[];
    for (final source in [first['inDepthAssessments'], second['inDepthAssessments']]) {
      if (source is List) {
        for (final a in source.whereType<Map>()) {
          assessments.add(a.cast<String, dynamic>());
        }
      }
    }
    if (assessments.isNotEmpty) {
      merged['inDepthAssessments'] = _uniqueByIdOrDate(assessments);
    }

    return merged;
  }

  List<Map<String, dynamic>> _uniqueByIdOrDate(List<Map<String, dynamic>> rows) {
    final byKey = <String, Map<String, dynamic>>{};
    var idx = 0;
    for (final row in rows) {
      final id = (row['id'] ?? '').toString().trim();
      final date = (row['visitDate'] ?? row['assessmentDate'] ?? row['createdAt'] ?? '').toString().trim();
      final key = id.isNotEmpty ? 'id:$id' : 'row:${date.isNotEmpty ? date : idx++}';
      byKey[key] = row;
    }
    return byKey.values.toList();
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class _ClinicalPullCounts {
  final int imported;
  final int failed;

  const _ClinicalPullCounts({required this.imported, required this.failed});
}
