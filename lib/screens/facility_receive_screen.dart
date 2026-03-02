import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../commodity/multi_scan_page.dart';
import '../core/config/app_config.dart';
import '../core/sync/sync_service.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/cache/box_cache_repo.dart';
import '../data/local/cache/shipment_cache_store.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/shipment_api.dart';
import '../widgets/acf_brand.dart';

/// Facility Receive (Manifest-driven)
///
/// Requirements:
/// - Receiving facility is LOCKED to the logged-in user's facility (not editable).
/// - Boxes to receive are PRELOADED from a manifest/waybill.
/// - Works offline as long as the manifest was downloaded earlier.
/// - Receiving is queued for sync; when online, we attempt to sync immediately.
class FacilityReceiveScreen extends StatefulWidget {
  const FacilityReceiveScreen({super.key});

  @override
  State<FacilityReceiveScreen> createState() => _FacilityReceiveScreenState();
}

class _FacilityReceiveScreenState extends State<FacilityReceiveScreen> {
  final _uuid = const Uuid();

  final _sessionStore = SessionStore();
  final _settingsRepo = AppSettingsRepo();
  final _shipmentCache = ShipmentCacheStore();
  final _boxRepo = BoxCacheRepo();
  final _queueRepo = SyncQueueRepo();
  final _syncService = SyncService();

  final _noteCtl = TextEditingController();

  bool _loading = true;
  bool _refreshing = false;
  bool _receiving = false;

  Map<String, dynamic>? _me;

  List<Map<String, dynamic>> _shipments = const [];
  String? _shipmentId;
  Map<String, dynamic>? _shipmentDetail;

  Set<String> _expected = <String>{};
  Set<String> _received = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _noteCtl.dispose();
    super.dispose();
  }

  String? get _facilityId => (_me?['facilityId'] as String?)?.trim();

  String get _facilityLabel {
    final f = _me?['facility'];
    if (f is Map) {
      final m = f.cast<String, dynamic>();
      final name = (m['name'] ?? '').toString().trim();
      final code = (m['code'] ?? '').toString().trim();
      if (name.isNotEmpty && code.isNotEmpty) return '$name ($code)';
      if (name.isNotEmpty) return name;
      if (code.isNotEmpty) return code;
    }
    return _facilityId ?? '—';
  }

  Future<bool> _isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return !r.contains(ConnectivityResult.none);
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    final list = await _shipmentCache.readShipmentList();

    String? defaultShipment;
    if (list.isNotEmpty) {
      defaultShipment = (list.first['id'] ?? '').toString();
    }

    setState(() {
      _me = me;
      _shipments = list;
      _shipmentId = defaultShipment;
      _loading = false;
    });

    // Load detail from cache (if any)
    if (defaultShipment != null && defaultShipment.trim().isNotEmpty) {
      await _loadShipmentDetail(defaultShipment.trim(), allowNetwork: true);
    }
  }

  Future<void> _refreshShipments() async {
    if (_refreshing) return;
    final online = await _isOnline();
    if (!online) {
      _toast('You are offline. Cannot refresh manifests.');
      return;
    }

    setState(() => _refreshing = true);
    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final shipmentApi = ShipmentApi(api);

      final items = await shipmentApi.listOpenShipments();
      final listJson = items.map((e) => e.toCacheJson()).toList();

      await _shipmentCache.saveShipmentList(listJson);

      if (!mounted) return;
      setState(() {
        _shipments = listJson;
        _shipmentId = _shipmentId ?? (listJson.isNotEmpty ? (listJson.first['id'] ?? '').toString() : null);
      });

      if (_shipmentId != null && _shipmentId!.trim().isNotEmpty) {
        await _loadShipmentDetail(_shipmentId!.trim(), allowNetwork: true);
      }

      _toast('Manifests refreshed (${items.length}).');
    } catch (e) {
      _toast('Refresh failed: $e');
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadShipmentDetail(String shipmentId, {required bool allowNetwork}) async {
    // 1) try cache
    final cached = await _shipmentCache.readShipmentDetail(shipmentId);
    if (cached != null) {
      await _applyShipmentDetail(shipmentId, cached);
      return;
    }

    // 2) fetch online (if allowed)
    if (!allowNetwork) return;
    final online = await _isOnline();
    if (!online) return;

    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final shipmentApi = ShipmentApi(api);

      final detail = await shipmentApi.getShipment(shipmentId);
      if (detail == null) return;

      final detailJson = detail.toCacheJson();
      await _shipmentCache.saveShipmentDetail(shipmentId, detailJson);
      await _applyShipmentDetail(shipmentId, detailJson);

      // Also upsert expected boxes into local cache for offline validation.
      final facilityId = _facilityId;
      if (facilityId != null && facilityId.isNotEmpty) {
        await _boxRepo.upsertMinimalMany(
          boxUids: detail.boxes.map((b) => b.boxUid).where((u) => u.trim().isNotEmpty).toList(),
          status: 'IN_TRANSIT',
          currentFacilityId: null,
        );
      }
    } catch (_) {
      // silent; UI still usable
    }
  }

  Future<void> _applyShipmentDetail(String shipmentId, Map<String, dynamic> detail) async {
    final boxes = <String>[];
    final rawBoxes = detail['boxes'];
    if (rawBoxes is List) {
      for (final b in rawBoxes.whereType<Map>()) {
        final uid = (b['boxUid'] ?? '').toString().trim();
        if (uid.isNotEmpty) boxes.add(uid);
      }
    }

    final received = (await _shipmentCache.readReceivedBoxUids(shipmentId)).toSet();

    if (!mounted) return;
    setState(() {
      _shipmentDetail = detail;
      _expected = boxes.toSet();
      _received = received;
    });
  }

  Map<String, dynamic> _safeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  String _extractBoxUid(String raw) {
    // Our QR codes are JSON. But support a plain UID too.
    final parsed = _safeJson(raw);
    final uid = (parsed['boxUid'] as String?)?.trim();
    if (uid != null && uid.isNotEmpty) return uid;
    return raw.trim();
  }

  Future<void> _startReceive() async {
    final shipmentId = _shipmentId?.trim();
    final facilityId = _facilityId;

    if (facilityId == null || facilityId.isEmpty) {
      _toast('Your account has no facility. Assign a facility to this user.');
      return;
    }

    if (shipmentId == null || shipmentId.isEmpty) {
      _toast('Select a manifest');
      return;
    }

    final expected = _expected;
    if (expected.isEmpty) {
      _toast('This manifest has no boxes cached. Tap “Refresh manifests” (online) first.');
      return;
    }

    final remainingExpected = expected.difference(_received);
    if (remainingExpected.isEmpty) {
      _toast('All boxes for this manifest are already marked as received.');
      return;
    }

    setState(() => _receiving = true);

    try {
      final scans = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => MultiScanPage(
            title: 'Receive: Scan boxes',
            expectedCount: remainingExpected.length,
            helperText: 'Manifest: ${_shipmentDetail?['manifestNo'] ?? shipmentId}\nScan the expected boxes. Each scan will be checked against the manifest.',
          ),
        ),
      );

      if (scans == null || scans.isEmpty) {
        _toast('No scans captured');
        return;
      }

      final scanned = <String>[];
      final parsedScans = <Map<String, dynamic>>[];
      for (final raw in scans) {
        final parsed = _safeJson(raw);
        final uid = (parsed['boxUid'] as String?)?.trim();
        if (uid != null && uid.isNotEmpty) {
          scanned.add(uid);
          parsedScans.add(parsed);
        } else {
          final fallback = raw.trim();
          if (fallback.isNotEmpty) {
            scanned.add(fallback);
            parsedScans.add({'boxUid': fallback});
          }
        }
      }

      final unique = scanned.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
      if (unique.isEmpty) {
        _toast('No valid boxUid found in scans');
        return;
      }

      // Strict validation: every scanned box must be part of this manifest and not already received.
      final unexpected = unique.where((u) => !expected.contains(u)).toList();
      final already = unique.where((u) => _received.contains(u)).toList();

      if (unexpected.isNotEmpty || already.isNotEmpty) {
        await _showValidationIssues(unexpected: unexpected, alreadyReceived: already);
        return;
      }

      final boxUids = unique.toList();

      // Queue receive against manifest.
      final payload = {
        'shipmentId': shipmentId,
        'toFacilityId': facilityId, // server will lock to your facility; we send for transparency
        'boxUids': boxUids,
        'note': _noteCtl.text.trim(),
        'createdAt': DateTime.now().toIso8601String(),
      };

      final item = SyncQueueItem.build(
        queueId: _uuid.v4(),
        entityType: 'receive',
        localEntityId: _uuid.v4(),
        method: 'POST',
        endpoint: AppConfig.facilityReceivePath,
        operation: SyncOperation.create,
        payloadJson: jsonEncode(payload),
        idempotencyKey: _uuid.v4(),
      );

      await _queueRepo.enqueue(item);

      // Optimistic local update: show boxes in store immediately.
      // We also keep batch/expiry if present in the QR payload.
      await _boxRepo.upsertFromScans(
        scans: parsedScans.where((m) => boxUids.contains((m['boxUid'] ?? '').toString().trim())).toList(),
        status: 'IN_FACILITY',
        currentFacilityId: facilityId,
      );

      // Persist progress for this manifest so remaining count reduces immediately.
      await _shipmentCache.addReceivedBoxUids(shipmentId, boxUids);
      await _applyShipmentDetail(shipmentId, _shipmentDetail ?? <String, dynamic>{'boxes': expected.map((e) => {'boxUid': e}).toList()});

      // If all expected boxes are now received locally, the manifest is complete on-device.
      // We'll hide it from the picker once the server confirms (online sync succeeds).
      final completedLocally = _expected.difference(_received).isEmpty;

      // Try sync immediately when online.
      final r = await _syncService.syncNow(limit: 10);
      if (!mounted) return;

      // When online and sync succeeded, refresh manifests so RECEIVED ones disappear.
      if (completedLocally && r.online && r.failed == 0) {
        await _shipmentCache.removeFromList(shipmentId);
        await _refreshShipments();
      }

      final msg = r.online
          ? 'Received queued (${boxUids.length}). Sync: sent ${r.sent}, failed ${r.failed}.'
          : 'Received queued (${boxUids.length}). Offline: will sync later.';
      _toast(msg);

      // Stay on screen so user can continue receiving remaining boxes.
    } catch (e) {
      _toast('Receive failed: $e');
    } finally {
      if (mounted) setState(() => _receiving = false);
    }
  }

  Future<void> _showValidationIssues({required List<String> unexpected, required List<String> alreadyReceived}) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cannot receive'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unexpected.isNotEmpty) ...[
                const Text('Unexpected (not in manifest):', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(unexpected.take(10).join('\n'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (unexpected.length > 10) Text('… +${unexpected.length - 10} more', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
              ],
              if (alreadyReceived.isNotEmpty) ...[
                const Text('Already marked received:', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(alreadyReceived.take(10).join('\n'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (alreadyReceived.length > 10) Text('… +${alreadyReceived.length - 10} more', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 10),
              Text(
                'Tip: Select the correct manifest. The server will also enforce that boxes can only be received into the intended facility.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
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
    final canUse = role == 'FACILITY_OFFICER' || role == 'CLINICIAN' || role == 'SUPER_ADMIN';

    final selected = _shipmentId;
    final detail = _shipmentDetail;
    final manifestNo = (detail?['manifestNo'] ?? '').toString().trim();

    final expectedCount = _expected.length;
    final receivedCount = _received.length;
    final remainingCount = _expected.difference(_received).length;

    return Scaffold(
      appBar: const AcfAppBar(title: 'Receive shipment'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: !canUse
            ? Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Your role ($role) cannot receive.', style: TextStyle(color: cs.onSurfaceVariant)),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Back'),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Receiving facility (locked)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surfaceVariant,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.apartment, color: cs.primary),
                                const SizedBox(width: 10),
                                Expanded(child: Text(_facilityLabel, style: const TextStyle(fontWeight: FontWeight.w900))),
                              ],
                            ),
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
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Manifest / Waybill', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              ),
                              TextButton.icon(
                                onPressed: _refreshing ? null : _refreshShipments,
                                icon: _refreshing
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.refresh),
                                label: const Text('Refresh'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<String>(
                            value: selected,
                            decoration: const InputDecoration(labelText: 'Select manifest'),
                            items: _shipments
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: (s['id'] ?? '').toString(),
                                    child: Text('${(s['manifestNo'] ?? '').toString()}  •  ${(s['itemCount'] ?? 0)} boxes'),
                                  ),
                                )
                                .toList(),
                            onChanged: _receiving
                                ? null
                                : (v) async {
                                    if (v == null || v.trim().isEmpty) return;
                                    setState(() {
                                      _shipmentId = v.trim();
                                      _shipmentDetail = null;
                                      _expected = <String>{};
                                      _received = <String>{};
                                    });
                                    await _loadShipmentDetail(v.trim(), allowNetwork: true);
                                  },
                          ),
                          const SizedBox(height: 10),
                          if (selected == null || selected.trim().isEmpty)
                            Text('No manifest cached. Tap Refresh (online).', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                          else
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: cs.outlineVariant),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    manifestNo.isNotEmpty ? 'Manifest: $manifestNo' : 'Manifest ID: $selected',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                  const SizedBox(height: 6),
                                  Text('Expected: $expectedCount  •  Received (local): $receivedCount  •  Remaining: $remainingCount',
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                ],
                              ),
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
                          const Text('Scan & receive', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _noteCtl,
                            decoration: const InputDecoration(
                              labelText: 'Note (optional)',
                              hintText: 'e.g. received by, condition...',
                            ),
                            enabled: !_receiving,
                          ),
                          const SizedBox(height: 12),
                          FilledButton.icon(
                            onPressed: _receiving ? null : _startReceive,
                            icon: _receiving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.qr_code_scanner),
                            label: const Text('Scan expected boxes → queue RECEIVE'),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'This is manifest-driven. The app blocks boxes that are not in the selected manifest, and the server also enforces the destination facility during sync.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
