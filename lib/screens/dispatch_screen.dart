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
import '../widgets/acf_brand.dart';

class _FacilityLite {
  final String id;
  final String name;
  final String? code;
  final String? type; // WAREHOUSE/FACILITY

  const _FacilityLite({required this.id, required this.name, this.code, this.type});

  factory _FacilityLite.fromJson(Map<String, dynamic> j) {
    return _FacilityLite(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['facilityName'] ?? '').toString(),
      code: j['code']?.toString(),
      type: j['type']?.toString(),
    );
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

      // Default TO: first FACILITY different from FROM.
      String? toId;
      for (final f in facilities) {
        if (f.id == fromId) continue;
        if ((f.type ?? 'FACILITY') == 'FACILITY') {
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
      _toast('Failed to load facilities: $e');
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
      _toast('Expected count must be > 0');
      return;
    }

    setState(() => _saving = true);
    try {
      // Scan boxes.
      final scans = await Navigator.push<List<String>>(
        context,
        MaterialPageRoute(
          builder: (_) => MultiScanPage(
            title: 'Dispatch: Scan boxes',
            expectedCount: expected,
            helperText: 'Scan $expected box QR codes. Dispatch will be sent immediately and a waybill will print.',
          ),
        ),
      );

      if (scans == null || scans.isEmpty) {
        _toast('No scans captured');
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
        _toast('No valid boxUid found in scans');
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
      _toast(manifestNo == null ? 'Dispatched and printed waybill' : 'Dispatched ($manifestNo) and printed waybill');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('Dispatch failed: $e');
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
    final toFacilities = _facilities.where((f) => f.id != _fromFacilityId && (f.type ?? 'FACILITY') == 'FACILITY').toList();

    final canUse = role == 'WAREHOUSE_OFFICER' || role == 'SUPER_ADMIN';

    return Scaffold(
      appBar: const AcfAppBar(title: 'Dispatch shipment'),
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
                      Text('Your role ($role) cannot dispatch.', style: TextStyle(color: cs.onSurfaceVariant)),
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
            : _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView(
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text('Shipment details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 12),
                              InputDecorator(
                                decoration: const InputDecoration(labelText: 'From warehouse', border: OutlineInputBorder()),
                                child: Text(
                                  from == null
                                      ? (_fromFacilityId ?? 'Not set')
                                      : '${from.name}${from.code == null ? '' : ' (${from.code})'}',
                                  style: const TextStyle(fontWeight: FontWeight.w800),
                                ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                value: _toFacilityId,
                                decoration: const InputDecoration(labelText: 'To facility (receiver)'),
                                items: toFacilities
                                    .map(
                                      (f) => DropdownMenuItem(
                                        value: f.id,
                                        child: Text('${f.name}${f.code == null ? '' : ' (${f.code})'}'),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _saving ? null : (v) => setState(() => _toFacilityId = v),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _expectedCountCtl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Expected number of boxes'),
                                enabled: !_saving,
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _noteCtl,
                                decoration: const InputDecoration(
                                  labelText: 'Note (optional)',
                                  hintText: 'e.g. truck, driver, route...',
                                ),
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
                              const Text('Scan & dispatch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 10),
                              FilledButton.icon(
                                onPressed: _saving ? null : _startDispatch,
                                icon: _saving
                                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.qr_code_scanner),
                                label: const Text('Scan boxes → dispatch & print waybill'),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Warehouse dispatch is online-only. The server validates box status and destination, updates stock immediately, and generates a waybill PDF.',
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
