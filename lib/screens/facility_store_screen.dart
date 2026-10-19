import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../core/session/active_facility_context.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/cache/box_cache_repo.dart';
import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';

/// Facility Store (Boxes + Sachets)
///
/// Shared-stock behaviour:
/// - server summary is the confirmed facility truth
/// - this screen overlays ONLY this phone's unsynced local dispenses
/// - totals therefore stay aligned across multiple users once sync happens
class FacilityStoreScreen extends StatefulWidget {
  const FacilityStoreScreen({super.key});

  @override
  State<FacilityStoreScreen> createState() => _FacilityStoreScreenState();
}

class _FacilityStoreScreenState extends State<FacilityStoreScreen> {
  final _sessionStore = SessionStore();
  final _boxRepo = BoxCacheRepo();
  final _assessRepo = ClinicalAssessmentRepo();
  final _settingsRepo = AppSettingsRepo();

  Map<String, dynamic>? _me;
  String? _facilityId;
  String _facilityCode = '';
  String _facilityLabel = '—';

  bool _loading = true;
  bool _refreshing = false;

  int? _serverTotalSachetsRemaining;
  int? _serverBoxesInStore;
  DateTime? _lastServerRefreshAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    final ctx = ActiveFacilityScope.fromUser(me);
    final facilityId = ctx.facilityId.trim().isNotEmpty ? ctx.facilityId.trim() : null;
    final facilityCode = ctx.facilityCode;

    String label = facilityId ?? '—';
    final f = me?['facility'];
    if (f is Map) {
      final m = f.cast<String, dynamic>();
      final name = (m['name'] ?? '').toString().trim();
      final code = (m['code'] ?? '').toString().trim();
      if (name.isNotEmpty && code.isNotEmpty) label = '$name ($code)';
      else if (name.isNotEmpty) label = name;
      else if (code.isNotEmpty) label = code;
    }

    int? serverTotal;
    int? serverBoxes;
    DateTime? refreshedAt;
    if (facilityId != null && facilityId.isNotEmpty) {
      serverTotal = await _settingsRepo.getCachedFacilityStoreSachetsRemaining(facilityId);
      serverBoxes = await _settingsRepo.getCachedFacilityStoreBoxesInStore(facilityId);
      refreshedAt = await _settingsRepo.getCachedFacilityStoreUpdatedAt(facilityId);
    }

    if (!mounted) return;
    setState(() {
      _me = me;
      _facilityId = facilityId;
      _facilityCode = facilityCode;
      _facilityLabel = label;
      _serverTotalSachetsRemaining = serverTotal;
      _serverBoxesInStore = serverBoxes;
      _lastServerRefreshAt = refreshedAt;
      _loading = false;
    });
  }

  Future<bool> _isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  int _sumPendingDispensedSachets(List<dynamic> assessmentsJson) {
    int total = 0;

    for (final a in assessmentsJson) {
      if (a is! Map<String, dynamic>) continue;
      final status = (a['status'] ?? '').toString().toUpperCase();
      if (status == 'SYNCED') continue;

      final raw = (a['dataJson'] ?? '').toString();
      if (raw.trim().isEmpty) continue;

      try {
        final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
        final t = (m['encounterType'] ?? '').toString().toUpperCase();
        if (t != 'FOLLOWUP' && t != 'ENROLLMENT') continue;

        final visit = (m['visit'] is Map) ? (m['visit'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
        final qty = visit['sachetsDispensed'] ?? visit['quantitySachets'] ?? visit['sachetsGiven'];
        final sachets = (qty is int) ? qty : int.tryParse('$qty') ?? 0;
        if (sachets > 0) total += sachets;
      } catch (_) {
        // ignore malformed JSON
      }
    }

    return total;
  }

  List<_StoreRow> _simulateRemainingPerBox({
    required List<dynamic> boxes,
    required int baseSachetsRemaining,
    required int pendingLocalDispensed,
  }) {
    final rows = boxes
        .whereType<dynamic>()
        .map((b) {
          final uid = (b.boxUid ?? '').toString();
          final batchNo = (b.batchNo ?? '').toString().trim().isEmpty ? null : b.batchNo;
          final exp = b.expiryDate as DateTime?;
          final capacity = (b.sachetsPerBox as int?) ?? _legacyPackSize;
          return _StoreRow(
            boxUid: uid,
            batchNo: batchNo,
            expiryDate: exp,
            capacity: capacity,
            serverRemaining: b.sachetsRemaining as int?,
          );
        })
        .where((r) => r.boxUid.trim().isNotEmpty)
        .toList();

    rows.sort((a, b) {
      final da = a.expiryDate ?? DateTime(2100, 1, 1);
      final db = b.expiryDate ?? DateTime(2100, 1, 1);
      final cmp = da.compareTo(db);
      if (cmp != 0) return cmp;
      return a.boxUid.compareTo(b.boxUid);
    });

    if (rows.every((r) => r.serverRemaining != null)) {
      // Each box's balance from the last server refresh.
      for (final r in rows) {
        r.remaining = r.serverRemaining!.clamp(0, r.capacity).toInt();
      }
    } else {
      // Boxes cached by an older build have no per-box balance: spread the
      // server total over the boxes, consuming earliest-expiring first.
      final totalCapacity = rows.fold<int>(0, (sum, r) => sum + r.capacity);
      final safeBaseRemaining = baseSachetsRemaining.clamp(0, totalCapacity).toInt();
      int consumed = totalCapacity - safeBaseRemaining;
      for (final r in rows) {
        final take = consumed < r.capacity ? consumed : r.capacity;
        r.remaining = r.capacity - take;
        consumed -= take;
      }
    }

    // Then take out dispenses recorded on this phone that have not synced yet
    // (FEFO, same order the server allocates in).
    int pending = pendingLocalDispensed;
    for (final r in rows) {
      if (pending <= 0) break;
      final take = pending < r.remaining ? pending : r.remaining;
      r.remaining -= take;
      pending -= take;
    }

    return rows;
  }



  Future<_CachedStoreSnapshot> _readCachedStoreSnapshot(String facilityId) async {
    final total = await _settingsRepo.getCachedFacilityStoreSachetsRemaining(facilityId);
    final boxes = await _settingsRepo.getCachedFacilityStoreBoxesInStore(facilityId);
    final refreshedAt = await _settingsRepo.getCachedFacilityStoreUpdatedAt(facilityId);
    return _CachedStoreSnapshot(
      totalSachetsRemaining: total,
      boxesInStore: boxes,
      refreshedAt: refreshedAt,
    );
  }
  Future<void> _refreshFromServer() async {
    if (_refreshing) return;
    final online = await _isOnline();
    if (!online) {
      _toast('Offline: cannot refresh from server');
      return;
    }

    final facilityId = _facilityId;
    if (facilityId == null || facilityId.isEmpty) {
      _toast('No facility assigned');
      return;
    }

    setState(() => _refreshing = true);
    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final resp = await api.request(method: 'GET', path: AppConfig.facilityStoreSummaryPath);
      final data = resp.data;
      if (data is Map) {
        final m = data.cast<String, dynamic>();
        final boxesRaw = m['boxes'];
        final boxes = <Map<String, dynamic>>[];
        if (boxesRaw is List) {
          for (final row in boxesRaw.whereType<Map>()) {
            boxes.add(row.cast<String, dynamic>());
          }
        }

        final totalSachetsRemaining =
            (m['totalSachetsRemaining'] is num) ? (m['totalSachetsRemaining'] as num).round() : 0;
        final boxesInStore = (m['boxesInStore'] is num) ? (m['boxesInStore'] as num).round() : boxes.length;

        await _settingsRepo.cacheFacilityStoreSummary(
          facilityId: facilityId,
          totalSachetsRemaining: totalSachetsRemaining,
          boxesInStore: boxesInStore,
        );
        await _boxRepo.upsertFromStoreSummary(boxes: boxes, facilityId: facilityId);

        if (!mounted) return;
        setState(() {
          _serverTotalSachetsRemaining = totalSachetsRemaining;
          _serverBoxesInStore = boxesInStore;
          _lastServerRefreshAt = DateTime.now();
        });
      }
      _toast('Store refreshed from server');
    } catch (e) {
      _toast('Could not refresh: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final role = (_me?['role'] ?? '').toString();
    final canUse = role == 'CLINICIAN' || role == 'FACILITY_OFFICER' || role == 'SUPER_ADMIN';
    final facilityId = _facilityId;

    return Scaffold(
      appBar: const AnchorAppBar(title: 'Store'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !canUse
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Your account does not have a facility store.', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            : (facilityId == null || facilityId.isEmpty)
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Your account is not linked to a facility yet. Ask your administrator.', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                : StreamBuilder(
                    stream: _boxRepo.watchByFacility(facilityId: facilityId, status: 'IN_FACILITY'),
                    builder: (context, snapshot) {
                      final boxes = snapshot.data ?? const [];

                      return FutureBuilder<_CachedStoreSnapshot>(
                        future: _readCachedStoreSnapshot(facilityId),
                        builder: (context, storeSnap) {
                          final cachedStore = storeSnap.data;
                          final effectiveServerTotal = cachedStore?.totalSachetsRemaining ??
                              _serverTotalSachetsRemaining ??
                              boxes.fold<int>(
                                0,
                                (sum, b) => sum + (b.sachetsRemaining ?? b.sachetsPerBox ?? _legacyPackSize),
                              );
                          final effectiveServerBoxes =
                              cachedStore?.boxesInStore ?? _serverBoxesInStore ?? boxes.length;
                          final effectiveRefreshAt = cachedStore?.refreshedAt ?? _lastServerRefreshAt;

                          return StreamBuilder(
                            stream: _assessRepo.watchAll(limit: 5000, facilityCode: _facilityCode),
                            builder: (context, assessSnap) {
                              final assessments = assessSnap.data ?? const [];
                              final assessJson = assessments
                                  .map((a) => {'dataJson': a.dataJson, 'status': a.status})
                                  .toList();
                              final pendingLocalDispensed = _sumPendingDispensedSachets(assessJson);

                              final rows = _simulateRemainingPerBox(
                                boxes: boxes,
                                baseSachetsRemaining: effectiveServerTotal,
                                pendingLocalDispensed: pendingLocalDispensed,
                              );
                              final boxesRemaining = rows.where((r) => r.remaining > 0).length;
                              final projectedSachetsRemaining = rows.fold<int>(0, (acc, r) => acc + r.remaining);
                              final lastRefreshText = effectiveRefreshAt == null
                                  ? 'No server refresh yet'
                                  : 'Server refreshed: ${_fmtDateTime(effectiveRefreshAt)}';

                              return ListView(
                            children: [
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.apartment, color: cs.primary),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              _facilityLabel,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          TextButton.icon(
                                            onPressed: _refreshing ? null : _refreshFromServer,
                                            icon: _refreshing
                                                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                                : const Icon(Icons.cloud_sync),
                                            label: const Text('Refresh'),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: _MetricCard(
                                              title: 'Boxes remaining',
                                              value: '$boxesRemaining',
                                              icon: Icons.inventory_2_outlined,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: _MetricCard(
                                              title: 'Sachets remaining',
                                              value: '$projectedSachetsRemaining',
                                              icon: Icons.medication_outlined,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Text(
                                        'Confirmed by server: $effectiveServerTotal sachets • Pending on this phone: $pendingLocalDispensed',
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$effectiveServerBoxes boxes in store • $lastRefreshText',
                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      const Text('Boxes · earliest expiry first', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 10),
                                      if (rows.isEmpty)
                                        Text('No boxes in the store yet. Receive a shipment to add boxes.', style: TextStyle(color: cs.onSurfaceVariant))
                                      else
                                        ...rows.map((r) {
                                          return Container(
                                            margin: const EdgeInsets.only(bottom: 8),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(14),
                                              border: Border.all(color: cs.outlineVariant),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.inventory_2_outlined, color: cs.onSurfaceVariant),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(r.boxUid, style: const TextStyle(fontWeight: FontWeight.w900), overflow: TextOverflow.ellipsis),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Projected remaining: ${r.remaining} sachets'
                                                        '${r.batchNo == null ? '' : '  •  Batch ${r.batchNo}'}'
                                                        '${r.expiryDate == null ? '' : '  •  Exp ${_fmtYmd(r.expiryDate!)}'}',
                                                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );
                                        }),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'This screen uses server-confirmed facility stock, then subtracts only unsynced dispenses on this phone. That keeps multiple users aligned once sync happens.',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
      ),
    );
  }

  static String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static String _fmtDateTime(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$y-$m-$day $hh:$mm';
  }
}

class _CachedStoreSnapshot {
  final int? totalSachetsRemaining;
  final int? boxesInStore;
  final DateTime? refreshedAt;

  const _CachedStoreSnapshot({
    required this.totalSachetsRemaining,
    required this.boxesInStore,
    required this.refreshedAt,
  });
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _MetricCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Pack size assumed only for boxes cached by app builds that did not store it
// (the original Kenya SQ-LNS box).
const int _legacyPackSize = 600;

class _StoreRow {
  final String boxUid;
  final String? batchNo;
  final DateTime? expiryDate;
  final int capacity;
  final int? serverRemaining;
  int remaining;

  _StoreRow({
    required this.boxUid,
    this.batchNo,
    this.expiryDate,
    required this.capacity,
    this.serverRemaining,
  }) : remaining = capacity;
}
