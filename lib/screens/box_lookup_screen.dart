import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../data/local/cache/box_cache_repo.dart';
import '../data/local/cache/facility_cache_repo.dart';
import '../data/local/isar/box_cache.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/remote/api_client.dart';
import '../data/remote/box_api.dart';
import '../commodity/multi_scan_page.dart';
import '../widgets/acf_brand.dart';

/// Step 7: Box lookup + timeline.
///
/// - Works offline using local cache (Isar)
/// - Shows pending offline actions that reference this boxUid
/// - Optionally refreshes from backend (GET /api/boxes/:boxUid)
class BoxLookupScreen extends StatefulWidget {
  const BoxLookupScreen({super.key});

  @override
  State<BoxLookupScreen> createState() => _BoxLookupScreenState();
}

class _BoxLookupScreenState extends State<BoxLookupScreen> {
  final TextEditingController _uidCtrl = TextEditingController();

  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final BoxCacheRepo _boxRepo = BoxCacheRepo();
  final FacilityCacheRepo _facilityRepo = FacilityCacheRepo();
  final SyncQueueRepo _queueRepo = SyncQueueRepo();

  bool _loading = false;
  String? _error;

  BoxCache? _local;
  BoxDetailDto? _server;
  List<_PendingAction> _pending = const [];
  Map<String, String> _facilityNames = const {};

  @override
  void initState() {
    super.initState();
    _loadFacilityNames();
  }

  @override
  void dispose() {
    _uidCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFacilityNames() async {
    final all = await _facilityRepo.listAll();
    final m = <String, String>{};
    for (final f in all) {
      if ((f.facilityId).trim().isEmpty) continue;
      m[f.facilityId] = f.name;
    }
    if (!mounted) return;
    setState(() => _facilityNames = m);
  }

  Future<void> _scan() async {
    final results = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const MultiScanPage(
          title: 'Scan a box QR',
          expectedCount: 1,
          helperText: 'Scan 1 box. We will lookup it in local cache and show pending actions.',
        ),
      ),
    );
    if (results == null || results.isEmpty) return;

    final raw = results.first;
    final parsed = _safeJson(raw);
    final uid = ((parsed['boxUid'] ?? parsed['box_uid'])?.toString() ?? raw).trim();
    if (uid.isEmpty) return;
    _uidCtrl.text = uid;
    await _lookup(fetchServer: false);
  }

  Map<String, dynamic> _safeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  Future<void> _lookup({required bool fetchServer}) async {
    final uid = _uidCtrl.text.trim();
    if (uid.isEmpty) {
      setState(() => _error = 'Enter or scan a box UID');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _server = null;
    });

    try {
      final local = await _boxRepo.findByUid(uid);
      final pending = await _pendingActionsFor(uid);

      BoxDetailDto? server;
      if (fetchServer) {
        final baseUrl = await _settingsRepo.getBaseUrl();
        final effective = baseUrl.trim().isEmpty ? AppConfig.defaultBaseUrl : baseUrl.trim();
        final api = ApiClient.create(baseUrl: effective);
        final boxApi = BoxApi(api);
        server = await boxApi.fetchBox(uid);

        // If server returned a box, upsert to local cache for offline use.
        if (server != null && server.boxUid.trim().isNotEmpty) {
          final record = BoxCache()
            ..boxUid = server.boxUid.trim()
            ..status = server.status
            ..currentFacilityId = server.currentFacilityId
            ..orderId = server.orderId
            ..productId = server.productId
            ..batchNo = server.batchNo
            ..expiryDate = server.expiryDate
            ..updatedAt = DateTime.now();
          await _boxRepo.upsertAll([record]);
        }
      }

      if (!mounted) return;
      setState(() {
        _local = local;
        _pending = pending;
        _server = server;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<_PendingAction>> _pendingActionsFor(String boxUid) async {
    // MVP approach: pull latest N queue items, filter by payload content.
    final latest = await _queueRepo.listLatest(limit: 250);
    final uid = boxUid.trim();
    if (uid.isEmpty) return const [];

    final matches = <_PendingAction>[];
    for (final item in latest) {
      // Only show not-yet-finalized items.
      if (item.status == SyncStatus.sent) continue;
      final payload = item.payloadJson ?? '';
      if (payload.isEmpty) continue;

      // Fast check first.
      if (!payload.contains(uid)) continue;

      // Parse payload (best effort) to extract from/to facility.
      String? fromId;
      String? toId;
      try {
        final decoded = jsonDecode(payload);
        if (decoded is Map) {
          final m = decoded.cast<String, dynamic>();
          fromId = m['fromFacilityId']?.toString();
          toId = m['toFacilityId']?.toString();
        }
      } catch (_) {}

      matches.add(
        _PendingAction(
          queueId: item.queueId,
          kind: item.entityType,
          status: item.status,
          endpoint: item.endpoint,
          createdAt: item.createdAt,
          lastError: item.lastError,
          fromFacilityId: fromId,
          toFacilityId: toId,
        ),
      );
    }

    // Newest first
    matches.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return matches;
  }

  String _facilityLabel(String? id) {
    if (id == null || id.trim().isEmpty) return '—';
    return _facilityNames[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Box lookup',
        actions: [
          IconButton(
            tooltip: 'Scan box',
            onPressed: _scan,
            icon: const Icon(Icons.qr_code_scanner),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Search', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _uidCtrl,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _lookup(fetchServer: false),
                          decoration: const InputDecoration(
                            labelText: 'Box UID',
                            hintText: 'Scan or type the box UID',
                            prefixIcon: Icon(Icons.inventory_2_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      FilledButton(
                        onPressed: _loading ? null : () => _lookup(fetchServer: false),
                        child: _loading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Lookup'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _loading ? null : () => _lookup(fetchServer: true),
                          icon: const Icon(Icons.cloud_download_outlined),
                          label: const Text('Refresh from server'),
                        ),
                      ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(color: cs.error, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _buildBoxSummary(cs),
          const SizedBox(height: 12),
          _buildPendingActions(cs),
          const SizedBox(height: 12),
          _buildServerTimeline(cs),
        ],
      ),
    );
  }

  Widget _buildBoxSummary(ColorScheme cs) {
    final uid = _uidCtrl.text.trim();
    if (uid.isEmpty && _local == null && _server == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Scan or type a Box UID to view details. Works offline using cached data.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
          ),
        ),
      );
    }

    final local = _local;
    final server = _server;

    final status = (server?.status.isNotEmpty == true)
        ? server!.status
        : (local?.status ?? 'UNKNOWN');
    final facilityId = server?.currentFacilityId ?? local?.currentFacilityId;
    final batchNo = server?.batchNo ?? local?.batchNo;
    final expiry = server?.expiryDate ?? local?.expiryDate;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(Icons.inventory_2, color: cs.onPrimaryContainer),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(uid.isEmpty ? (server?.boxUid ?? local?.boxUid ?? '—') : uid,
                          style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(
                        'Status: $status',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                if (server != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.secondaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Server', style: TextStyle(color: cs.onSecondaryContainer, fontSize: 12)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: cs.surfaceVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text('Local', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _kv('Current location', _facilityLabel(facilityId), cs),
            _kv('Batch', (batchNo ?? '—').toString().isEmpty ? '—' : (batchNo ?? '—'), cs),
            _kv('Expiry', expiry == null ? '—' : expiry.toIso8601String().split('T').first, cs),
            if (local == null && server == null) ...[
              const SizedBox(height: 8),
              Text(
                'Not found in local cache. Try “Refresh from server” (online).',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, ColorScheme cs) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(k, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ),
          Expanded(
            child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingActions(ColorScheme cs) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pending offline actions', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'These are queue items on the phone that reference this box. They may not be synced yet.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (_pending.isEmpty)
              Text('None', style: TextStyle(color: cs.onSurfaceVariant))
            else
              ..._pending.map((a) => _PendingTile(a: a, facilityLabel: _facilityLabel)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildServerTimeline(ColorScheme cs) {
    final events = _server?.events ?? const [];
    final sorted = [...events];
    sorted.sort(
      (a, b) => (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
          .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Box timeline', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'If you refresh from server (online), we display known historical events.',
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (_server == null)
              Text('No server data yet. Tap “Refresh from server”.', style: TextStyle(color: cs.onSurfaceVariant))
            else if (events.isEmpty)
              Text('No events returned by server for this box.', style: TextStyle(color: cs.onSurfaceVariant))
            else
              ...sorted.map((e) => _EventTile(e: e, facilityLabel: _facilityLabel)).toList(),
          ],
        ),
      ),
    );
  }
}

class _PendingAction {
  final String queueId;
  final String kind;
  final SyncStatus status;
  final String endpoint;
  final DateTime createdAt;
  final String? lastError;
  final String? fromFacilityId;
  final String? toFacilityId;

  const _PendingAction({
    required this.queueId,
    required this.kind,
    required this.status,
    required this.endpoint,
    required this.createdAt,
    this.lastError,
    this.fromFacilityId,
    this.toFacilityId,
  });
}

class _PendingTile extends StatelessWidget {
  final _PendingAction a;
  final String Function(String? id) facilityLabel;

  const _PendingTile({required this.a, required this.facilityLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final statusText = a.status.name.toUpperCase();
    final badgeColor = a.status == SyncStatus.failed ? cs.errorContainer : cs.tertiaryContainer;
    final badgeText = a.status == SyncStatus.failed ? cs.onErrorContainer : cs.onTertiaryContainer;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  a.kind.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(statusText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: badgeText)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(a.endpoint, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text('From: ${facilityLabel(a.fromFacilityId)}', style: const TextStyle(fontSize: 12)),
              ),
              Expanded(
                child: Text('To: ${facilityLabel(a.toFacilityId)}', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Created: ${a.createdAt.toIso8601String().replaceFirst('T', ' ').split('.').first}',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          if (a.lastError != null && a.lastError!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Error: ${a.lastError}',
              style: TextStyle(fontSize: 12, color: cs.error),
            ),
          ],
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  final BoxEventDto e;
  final String Function(String? id) facilityLabel;

  const _EventTile({required this.e, required this.facilityLabel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final at = e.createdAt;
    final atText = at == null ? '—' : at.toIso8601String().replaceFirst('T', ' ').split('.').first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  e.type.isEmpty ? 'EVENT' : e.type,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              Text(atText, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('From: ${facilityLabel(e.fromFacilityId)}', style: const TextStyle(fontSize: 12))),
              Expanded(child: Text('To: ${facilityLabel(e.toFacilityId)}', style: const TextStyle(fontSize: 12))),
            ],
          ),
          if (e.note != null && e.note!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              e.note!,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}
