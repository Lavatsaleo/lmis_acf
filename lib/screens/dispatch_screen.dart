import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../commodity/multi_scan_page.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../utils/remote_pdf.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';

class _FacilityLite {
  final String id;
  final String name;
  final String? code;
  final String? type; // WAREHOUSE/FACILITY
  final String? parentStockLocationId;

  const _FacilityLite({required this.id, required this.name, this.code, this.type, this.parentStockLocationId});

  factory _FacilityLite.fromJson(Map<String, dynamic> j) {
    return _FacilityLite(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['facilityName'] ?? '').toString(),
      code: j['code']?.toString(),
      type: j['type']?.toString(),
      parentStockLocationId: j['parentStockLocationId']?.toString(),
    );
  }

  /// Valid dispatch destination from [fromId]: a facility, or a warehouse
  /// directly below it (warehouse-to-warehouse transfer, e.g. main warehouse
  /// to field base). Kenya warehouses have no warehouses below them, so only
  /// facilities appear there, as before.
  bool isDestinationFrom(String? fromId) {
    if (id == fromId) return false;
    final t = type ?? 'FACILITY';
    if (t == 'FACILITY') return true;
    return t == 'WAREHOUSE' && fromId != null && parentStockLocationId == fromId;
  }
}

/// Warehouse dispatch (ONLINE).
///
/// - FROM is always the logged-in warehouse (read-only)
/// - Scan boxes, dispatch immediately, then print waybill
class DispatchScreen extends StatefulWidget {
  const DispatchScreen({super.key});

  @override
  State<DispatchScreen> createState() => _DispatchScreenState();
}

class _DispatchScreenState extends State<DispatchScreen> {
  final SessionStore _sessionStore = SessionStore();
  final TokenStore _tokenStore = const TokenStore();
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final Uuid _uuid = const Uuid();

  final TextEditingController _expectedCountCtl = TextEditingController(text: '10');
  final TextEditingController _noteCtl = TextEditingController();

  bool _loading = true;
  bool _saving = false;

  Map<String, dynamic>? _me;

  List<_FacilityLite> _facilities = const [];
  String? _fromFacilityId;
  String? _toFacilityId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _expectedCountCtl.dispose();
    _noteCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    final role = (me?['role'] ?? '').toString();

    // Only warehouse roles should reach here.
    if (role != 'WAREHOUSE_OFFICER' && role != 'SUPER_ADMIN') {
      if (!mounted) return;
      setState(() {
        _me = me;
        _loading = false;
      });
      return;
    }

    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final resp = await api.request(method: 'GET', path: AppConfig.facilitiesPath);

      final List<_FacilityLite> facilities = <_FacilityLite>[];
      final data = resp.data;
      if (data is List) {
        for (final e in data.whereType<Map>()) {
          facilities.add(_FacilityLite.fromJson(e.cast<String, dynamic>()));
        }
      } else if (data is Map && data['facilities'] is List) {
        for (final e in (data['facilities'] as List).whereType<Map>()) {
          facilities.add(_FacilityLite.fromJson(e.cast<String, dynamic>()));
        }
      }

      final fromId = (me?['warehouseId'] ?? me?['facilityId'])?.toString();

      // Default TO: first valid destination different from FROM.
      String? toId;
      for (final f in facilities) {
        if (f.isDestinationFrom(fromId)) {
          toId = f.id;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _me = me;
        _facilities = facilities;
        _fromFacilityId = fromId;
        _toFacilityId = toId;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _me = me;
        _loading = false;
      });
      _toast('Could not load destinations: ${friendlyError(e)}');
    }
  }

  _FacilityLite? _findFacility(String? id) {
    if (id == null) return null;
    for (final f in _facilities) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<void> _startDispatch() async {
    final fromId = _fromFacilityId;
    final toId = _toFacilityId;
    final role = (_me?['role'] ?? '').toString();

    if (role != 'WAREHOUSE_OFFICER' && role != 'SUPER_ADMIN') {
      _toast('Your role ($role) cannot dispatch.');
      return;
    }

    if (fromId == null || fromId.isEmpty) {
      _toast('Your account is not linked to a warehouse');
      return;
    }
    if (toId == null || toId.isEmpty) {
      _toast('Select destination facility');
      return;
    }
    if (fromId == toId) {
      _toast('FROM and TO cannot be the same');
      return;
    }

    final expected = int.tryParse(_expectedCountCtl.text.trim()) ?? 0;
    if (expected <= 0) {
      _toast('Enter how many boxes you are sending.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Scan boxes.
      final scans = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => MultiScanPage(
            title: 'Scan boxes to dispatch',
            expectedCount: expected,
            helperText: 'Scan all $expected boxes. The dispatch is sent when you finish, then the waybill prints.',
          ),
        ),
      );

      if (scans == null || scans.isEmpty) {
        _toast('No boxes were scanned. Nothing was sent.');
        return;
      }

      // Extract boxUids.
      final boxUids = <String>[];
      for (final raw in scans) {
        final parsed = _safeJson(raw);
        final uid = (parsed['boxUid'] as String?)?.trim();
        if (uid != null && uid.isNotEmpty) {
          boxUids.add(uid);
        }
      }

      if (boxUids.isEmpty) {
        _toast('Those QR codes are not Anchor box labels.');
        return;
      }

      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final idemKey = _uuid.v4();

      final resp = await api.request(
        method: 'POST',
        path: AppConfig.dispatchPath,
        headers: {'X-Idempotency-Key': idemKey},
        data: {
          // Backend will force fromFacilityId for WAREHOUSE_OFFICER
          'toFacilityId': toId,
          'boxUids': boxUids,
          'note': _noteCtl.text.trim(),
          'createdAt': DateTime.now().toIso8601String(),
        },
      );

      String? waybillUrl;
      String? manifestNo;
      if (resp.data is Map) {
        final m = (resp.data as Map).cast<String, dynamic>();
        waybillUrl = m['waybillUrl']?.toString();
        manifestNo = m['manifestNo']?.toString();
      }

      // Print waybill.
      if (waybillUrl != null && waybillUrl.trim().isNotEmpty) {
        final token = await _tokenStore.readAccessToken();
        final Uint8List pdf = await RemotePdf.downloadPdfBytes(
          baseUrl: baseUrl,
          pathOrUrl: waybillUrl.trim(),
          accessToken: token,
        );
        await Printing.layoutPdf(onLayout: (_) async => pdf);
      }

      if (!mounted) return;
      _toast(manifestNo == null ? 'Dispatched. Waybill sent to the printer.' : 'Dispatched as $manifestNo. Waybill sent to the printer.');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast(friendlyError(e, action: 'Dispatch'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _safeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {}
    return <String, dynamic>{};
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = _me;
    final role = (me?['role'] ?? '').toString();

    final from = _findFacility(_fromFacilityId);
    final toFacilities = _facilities.where((f) => f.isDestinationFrom(_fromFacilityId)).toList();
    final canUse = role == 'WAREHOUSE_OFFICER' || role == 'SUPER_ADMIN';
    final expected = int.tryParse(_expectedCountCtl.text.trim()) ?? 0;
    final ready = _toFacilityId != null && expected > 0;

    String label(_FacilityLite f) => '${f.name}${f.code == null ? '' : ' (${f.code})'}';

    return Scaffold(
      appBar: const AnchorAppBar(title: 'Dispatch'),
      body: !canUse
          ? const Padding(
              padding: EdgeInsets.all(16),
              child: AnchorNotice('Only warehouse officers can dispatch boxes.', warning: true),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            AnchorStep(number: 1, title: 'Where are the boxes going?', done: _toFacilityId != null),
                            InputDecorator(
                              decoration: const InputDecoration(labelText: 'From', prefixIcon: Icon(Icons.warehouse_outlined)),
                              child: Text(from == null ? 'Your warehouse' : label(from), style: const TextStyle(fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _toFacilityId,
                              isExpanded: true,
                              decoration: InputDecoration(
                                labelText: toFacilities.any((f) => f.type == 'WAREHOUSE') ? 'To (site or field base)' : 'To (facility)',
                                prefixIcon: const Icon(Icons.place_outlined),
                              ),
                              hint: const Text('Choose the receiver'),
                              items: toFacilities
                                  .map((f) => DropdownMenuItem(
                                        value: f.id,
                                        child: Text('${label(f)}${f.type == 'WAREHOUSE' ? ' · field base' : ''}', overflow: TextOverflow.ellipsis),
                                      ))
                                  .toList(),
                              onChanged: _saving ? null : (v) => setState(() => _toFacilityId = v),
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
                            AnchorStep(number: 2, title: 'How many boxes?', hint: 'Count the boxes you are loading.', done: expected > 0),
                            TextField(
                              controller: _expectedCountCtl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Number of boxes', prefixIcon: Icon(Icons.inventory_2_outlined)),
                              enabled: !_saving,
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _noteCtl,
                              decoration: const InputDecoration(labelText: 'Note (optional)', hintText: 'Truck, driver, route…', prefixIcon: Icon(Icons.notes)),
                              enabled: !_saving,
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
                            const AnchorStep(number: 3, title: 'Scan and send', hint: 'Scan each box QR. When all are scanned, the dispatch is sent and the waybill prints.'),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _saving || !ready ? null : _startDispatch,
                                icon: _saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                    : const Icon(Icons.qr_code_scanner),
                                label: Text(_saving ? 'Sending…' : expected > 0 ? 'Scan $expected boxes' : 'Scan boxes'),
                              ),
                            ),
                            if (!ready) ...[
                              const SizedBox(height: 8),
                              Text('Complete steps 1 and 2 first.', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const AnchorNotice('Dispatch needs internet. Stock leaves your warehouse as soon as the dispatch is sent.', icon: Icons.wifi),
                  ],
                ),
    );
  }
}
