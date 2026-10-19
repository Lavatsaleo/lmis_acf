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
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';

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

  /// A field base warehouse officer receiving a transfer from the main warehouse.
  bool get _isFieldBaseReceiver {
    final f = _me?['facility'];
    return (_me?['role'] ?? '').toString() == 'WAREHOUSE_OFFICER' &&
        f is Map &&
        (f['stockLocationType'] ?? '').toString() == 'FIELD_BASE_WAREHOUSE';
  }

  /// Status received boxes take locally: warehouse stock at a field base,
  /// facility stock everywhere else (mirrors the server).
  String get _receivedBoxStatus => _isFieldBaseReceiver ? 'IN_WAREHOUSE' : 'IN_FACILITY';

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

      final items = await shipmentApi.listOpenShipments(incoming: _isFieldBaseReceiver);
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
      _toast('Could not refresh: ${friendlyError(e)}');
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
            title: 'Scan received boxes',
            expectedCount: remainingExpected.length,
            helperText: 'Waybill ${_shipmentDetail?['manifestNo'] ?? ''}: scan each box. Boxes not on this waybill are refused.',
          ),
        ),
      );

      if (scans == null || scans.isEmpty) {
        _toast('No boxes were scanned. Nothing was saved.');
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
        _toast('Those QR codes are not Anchor box labels.');
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
        // Local cache only (ignored by the server): status the boxes take here.
        'localStatus': _receivedBoxStatus,
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
        status: _receivedBoxStatus,
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

      final msg = !r.online
          ? '${boxUids.length} boxes received. Saved on this phone; they will sync when you are online.'
          : r.failed > 0
              ? '${boxUids.length} boxes received. Some records did not sync yet; see Sync.'
              : '${boxUids.length} boxes received and synced.';
      _toast(msg);

      // Stay on screen so user can continue receiving remaining boxes.
    } catch (e) {
      _toast(friendlyError(e, action: 'Receiving'));
    } finally {
      if (mounted) setState(() => _receiving = false);
    }
  }

  Future<void> _showValidationIssues({required List<String> unexpected, required List<String> alreadyReceived}) {
    final cs = Theme.of(context).colorScheme;
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('These boxes cannot be received'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (unexpected.isNotEmpty) ...[
                const Text('Not on this waybill:', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(unexpected.take(10).join('\n'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (unexpected.length > 10) Text('… +${unexpected.length - 10} more', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 12),
              ],
              if (alreadyReceived.isNotEmpty) ...[
                const Text('Already received:', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 6),
                Text(alreadyReceived.take(10).join('\n'), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                if (alreadyReceived.length > 10) Text('… +${alreadyReceived.length - 10} more', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
              const SizedBox(height: 10),
              Text(
                'Check that you chose the right waybill. Nothing was saved; scan again when ready.',
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
    final canUse = role == 'FACILITY_OFFICER' || role == 'CLINICIAN' || role == 'SUPER_ADMIN' || _isFieldBaseReceiver;

    final selected = _shipmentId;
    final detail = _shipmentDetail;
    final manifestNo = (detail?['manifestNo'] ?? '').toString().trim();
    final hasSelection = selected != null && selected.trim().isNotEmpty;

    final expectedCount = _expected.length;
    final receivedCount = _received.length;
    final remainingCount = _expected.difference(_received).length;
    final title = _isFieldBaseReceiver ? 'Receive transfer' : 'Receive shipment';

    return Scaffold(
      appBar: AnchorAppBar(title: title),
      body: !canUse
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: AnchorNotice('Your account cannot receive boxes here.', warning: true),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Icon(Icons.place_outlined, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Receiving at $_facilityLabel', style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: AnchorStep(
                                number: 1,
                                title: 'Choose the delivery',
                                hint: 'Pick the waybill number written on the delivery papers.',
                                done: hasSelection,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Check for new deliveries',
                              onPressed: _refreshing ? null : _refreshShipments,
                              icon: _refreshing
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.refresh),
                            ),
                          ],
                        ),
                        if (_shipments.isEmpty)
                          const AnchorNotice('No deliveries on their way to you. When online, tap refresh to check again.')
                        else
                          DropdownButtonFormField<String>(
                            value: selected,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Waybill', prefixIcon: Icon(Icons.receipt_long_outlined)),
                            hint: const Text('Choose a waybill'),
                            items: _shipments
                                .map((s) => DropdownMenuItem(
                                      value: (s['id'] ?? '').toString(),
                                      child: Text('${(s['manifestNo'] ?? '').toString()}  ·  ${(s['itemCount'] ?? 0)} boxes', overflow: TextOverflow.ellipsis),
                                    ))
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
                        if (hasSelection && expectedCount > 0) ...[
                          const SizedBox(height: 14),
                          Text(
                            manifestNo.isNotEmpty ? manifestNo : 'Selected delivery',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: expectedCount == 0 ? 0 : receivedCount / expectedCount,
                              minHeight: 10,
                              backgroundColor: cs.surfaceContainerHighest,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            remainingCount == 0
                                ? 'All $expectedCount boxes received.'
                                : '$receivedCount of $expectedCount boxes received · $remainingCount to scan',
                            style: TextStyle(fontSize: 13, color: remainingCount == 0 ? const Color(0xFF1B7F4B) : cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                        ],
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
                        const AnchorStep(
                          number: 2,
                          title: 'Scan the boxes',
                          hint: 'Scan every box you received. Boxes that are not on this waybill are refused.',
                        ),
                        TextField(
                          controller: _noteCtl,
                          decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Received by, condition of boxes…', prefixIcon: Icon(Icons.notes)),
                          enabled: !_receiving,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _receiving || !hasSelection || remainingCount == 0 ? null : _startReceive,
                            icon: _receiving
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.qr_code_scanner),
                            label: Text(remainingCount > 0 ? 'Scan $remainingCount boxes' : 'Scan boxes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const AnchorNotice('Works offline. Received boxes appear in your store at once and are sent to the server when there is internet.', icon: Icons.cloud_done_outlined),
              ],
            ),
    );
  }
}
