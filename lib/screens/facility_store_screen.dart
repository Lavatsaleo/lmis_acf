import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/cache/box_cache_repo.dart';
import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../widgets/acf_brand.dart';

/// Facility Store (Boxes + Sachets)
///
/// Updated behaviour (as requested):
/// - Show ONLY facility totals: boxes remaining + sachets remaining
/// - NO active box selection and NO scanning before dispensing
/// - Stock reduces locally based on locally saved enrollment/follow-up records
/// - Server is updated during sync (SyncService) and can be refreshed from server
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
  String _facilityLabel = '—';

  bool _loading = true;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    final facilityId = (me?['facilityId'] as String?)?.trim();

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

    if (!mounted) return;
    setState(() {
      _me = me;
      _facilityId = facilityId;
      _facilityLabel = label;
      _loading = false;
    });
  }

  Future<bool> _isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  /// Sum sachets dispensed across all local assessments that contain a `visit` section.
  /// Includes enrollment + follow-up.
  int _sumDispensedSachets(List<dynamic> assessmentsJson) {
    int total = 0;

    for (final a in assessmentsJson) {
      if (a is! Map<String, dynamic>) continue;
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

  /// Compute remaining per box using a simple FEFO simulation.
  ///
  /// This lets totals reduce locally even without scanning boxes.
  /// Assumption: sachets are consumed sequentially from the earliest-expiring boxes.
  List<_StoreRow> _simulateRemainingPerBox(List<dynamic> boxes, int totalDispensed) {
    // Normalize and sort boxes by expiry (null -> far future), then boxUid.
    final rows = boxes
        .whereType<dynamic>()
        .map((b) {
          // b is BoxCache
          final uid = (b.boxUid ?? '').toString();
          final batchNo = (b.batchNo ?? '').toString().trim().isEmpty ? null : b.batchNo;
          final exp = b.expiryDate as DateTime?;
          return _StoreRow(boxUid: uid, batchNo: batchNo, expiryDate: exp);
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

    int remainingToAllocate = totalDispensed;
    for (final r in rows) {
      int remaining = 600;
      if (remainingToAllocate > 0) {
        final take = remainingToAllocate >= 600 ? 600 : remainingToAllocate;
        remaining -= take;
        remainingToAllocate -= take;
      }
      r.remaining = remaining.clamp(0, 600);
    }

    return rows;
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
        final boxes = m['boxes'];
        if (boxes is List) {
          final uids = <String>[];
          for (final b in boxes.whereType<Map>()) {
            final uid = (b['boxUid'] ?? '').toString().trim();
            if (uid.isNotEmpty) uids.add(uid);
          }
          await _boxRepo.upsertMinimalMany(
            boxUids: uids,
            status: 'IN_FACILITY',
            currentFacilityId: facilityId,
          );
        }
      }
      _toast('Store refreshed from server');
    } catch (e) {
      _toast('Refresh failed: $e');
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
      appBar: const AcfAppBar(title: 'Facility store'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !canUse
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Your role ($role) cannot access store.', style: TextStyle(color: cs.onSurfaceVariant)),
                ),
              )
            : (facilityId == null || facilityId.isEmpty)
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('No facility assigned to this user.', style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  )
                : StreamBuilder(
                    stream: _boxRepo.watchByFacility(facilityId: facilityId, status: 'IN_FACILITY'),
                    builder: (context, snapshot) {
                      final boxes = snapshot.data ?? const [];

                      return StreamBuilder(
                        stream: _assessRepo.watchAll(limit: 5000),
                        builder: (context, assessSnap) {
                          final assessments = assessSnap.data ?? const [];

                          final assessJson = assessments.map((a) => {'dataJson': a.dataJson}).toList();
                          final totalDispensed = _sumDispensedSachets(assessJson);

                          final rows = _simulateRemainingPerBox(boxes, totalDispensed);
                          final boxesRemaining = rows.where((r) => r.remaining > 0).length;
                          final sachetsRemaining = rows.fold<int>(0, (acc, r) => acc + r.remaining);

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
                                              value: '$sachetsRemaining',
                                              icon: Icons.medication_outlined,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 10),
                                      Text(
                                        'Received boxes (cached): ${boxes.length} • Dispensed (local): $totalDispensed',
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
                                      const Text('Boxes (FEFO view)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                      const SizedBox(height: 10),
                                      if (rows.isEmpty)
                                        Text('No boxes in store. Receive from manifest first.', style: TextStyle(color: cs.onSurfaceVariant))
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
                                                        'Remaining: ${r.remaining} sachets'
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
                                'Note: Clinicians do not scan boxes while dispensing. The server auto-allocates sachets from the earliest-expiring boxes during sync.',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                textAlign: TextAlign.center,
                              ),
                            ],
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

class _StoreRow {
  final String boxUid;
  final String? batchNo;
  final DateTime? expiryDate;
  int remaining;

  _StoreRow({required this.boxUid, this.batchNo, this.expiryDate, this.remaining = 600});
}
