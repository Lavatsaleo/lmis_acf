import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../commodity/multi_scan_page.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../widgets/anchor_brand.dart';

/// Warehouse (online) stock control: physical counts and reporting losses.
///
/// Backend:
/// - GET/POST /api/stock-counts, PATCH /api/stock-counts/:id/lines,
///   POST /api/stock-counts/:id/submit
/// - POST /api/stock-adjustments (write-off request, needs admin approval)
/// - POST /api/stock-adjustments/holds (hold only)

String _message(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? e.toString();
  }
  return e.toString();
}

Future<ApiClient> _api() async => ApiClient.create(baseUrl: await AppSettingsRepo().getBaseUrl());

Future<String?> _myWarehouseId() async {
  final me = await SessionStore().readUserJson();
  final id = (me?['warehouseId'] ?? me?['facilityId'])?.toString();
  return (id == null || id.isEmpty) ? null : id;
}

String _ymd(String? iso) => (iso ?? '').length >= 10 ? iso!.substring(0, 10) : '';

// ---------------------------------------------------------------------------
// Stock count (blind: expected quantities are not shown while counting)
// ---------------------------------------------------------------------------
class StockCountScreen extends StatefulWidget {
  const StockCountScreen({super.key});

  @override
  State<StockCountScreen> createState() => _StockCountScreenState();
}

class _StockCountScreenState extends State<StockCountScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _count;
  final Map<String, TextEditingController> _ctrls = {};
  String? _result;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> get _lines =>
      ((_count?['lines'] as List?) ?? const []).whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();

  void _bind(Map<String, dynamic> count) {
    _count = count;
    for (final l in _lines) {
      final id = l['id'].toString();
      final v = l['countedBoxes'];
      _ctrls.putIfAbsent(id, () => TextEditingController());
      if (v != null && _ctrls[id]!.text.isEmpty) _ctrls[id]!.text = v.toString();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = await _api();
      final wh = await _myWarehouseId();
      final list = await api.request(method: 'GET', path: '/api/stock-counts?status=IN_PROGRESS${wh == null ? '' : '&warehouseId=$wh'}');
      final rows = (list.data is Map && list.data['rows'] is List) ? list.data['rows'] as List : const [];
      if (rows.isNotEmpty) {
        final detail = await api.request(method: 'GET', path: '/api/stock-counts/${rows.first['id']}');
        _bind((detail.data as Map).cast<String, dynamic>());
      } else {
        _count = null;
      }
    } catch (e) {
      _error = _message(e);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final api = await _api();
      final resp = await api.request(method: 'POST', path: '/api/stock-counts', data: {'warehouseId': await _myWarehouseId()});
      setState(() => _bind((resp.data as Map).cast<String, dynamic>()));
    } catch (e) {
      _toast(_message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _save() async {
    final changes = <Map<String, dynamic>>[];
    for (final l in _lines) {
      final id = l['id'].toString();
      final text = _ctrls[id]?.text.trim() ?? '';
      final value = text.isEmpty ? null : int.tryParse(text);
      if (text.isNotEmpty && (value == null || value < 0)) {
        _toast('${l['batchNo']}: enter a whole number');
        return false;
      }
      if (value != l['countedBoxes']) changes.add({'id': id, 'countedBoxes': value});
    }
    if (changes.isEmpty) return true;
    try {
      final api = await _api();
      final resp = await api.request(method: 'PATCH', path: '/api/stock-counts/${_count!['id']}/lines', data: {'lines': changes});
      setState(() => _bind((resp.data as Map).cast<String, dynamic>()));
      return true;
    } catch (e) {
      _toast('Save failed: ${_message(e)}');
      return false;
    }
  }

  Future<void> _submit() async {
    final missing = _lines.where((l) => (_ctrls[l['id'].toString()]?.text.trim() ?? '').isEmpty).length;
    if (missing > 0) {
      _toast('$missing batch(es) not counted yet. Enter 0 where nothing was found.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Submit count?'),
        content: const Text('Shortages become a write-off request for an administrator to approve. The sheet can no longer be edited.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Back')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      if (!await _save()) return;
      final api = await _api();
      final resp = await api.request(method: 'POST', path: '/api/stock-counts/${_count!['id']}/submit');
      final r = ((resp.data as Map)['result'] as Map?)?.cast<String, dynamic>() ?? const {};
      final short = r['shortageBoxes'] ?? 0;
      final surplus = r['surplusBoxes'] ?? 0;
      setState(() {
        _result = short == 0 && surplus == 0
            ? 'Count submitted: everything matched.'
            : 'Count submitted: $short carton(s) short (sent for approval), $surplus more than expected (to investigate).';
        _count = null;
      });
    } catch (e) {
      _toast('Submit failed: ${_message(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = _count;
    final counted = _lines.where((l) => (_ctrls[l['id'].toString()]?.text.trim() ?? '').isNotEmpty).length;
    return Scaffold(
      appBar: AnchorAppBar(title: count == null ? 'Stock count' : count['countNumber'].toString()),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_error != null) Text(_error!, style: TextStyle(color: cs.error)),
                if (_result != null)
                  Card(
                    color: cs.secondaryContainer,
                    child: Padding(padding: const EdgeInsets.all(16), child: Text(_result!)),
                  ),
                if (count == null) ...[
                  const Text('No count in progress for your warehouse.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : _start,
                    icon: const Icon(Icons.fact_check_outlined),
                    label: const Text('Start a full stock count'),
                  ),
                ] else ...[
                  Text(
                    'Count the cartons of each batch and type the number. Expected quantities are hidden on purpose. $counted of ${_lines.length} counted.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                  for (final l in _lines)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(l['productName'].toString(), style: const TextStyle(fontWeight: FontWeight.w800)),
                                  Text('Batch ${l['batchNo']} · exp ${_ymd(l['expiryDate']?.toString())}', style: const TextStyle(fontSize: 12)),
                                  Text(l['donorName']?.toString() ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 96,
                              child: TextField(
                                controller: _ctrls[l['id'].toString()],
                                enabled: !_busy,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.right,
                                decoration: const InputDecoration(labelText: 'Cartons'),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _busy
                              ? null
                              : () async {
                                  if (await _save()) _toast('Saved');
                                },
                          child: const Text('Save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(onPressed: _busy ? null : _submit, child: const Text('Submit count')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Found cartons that are not listed? Add them on the dashboard count sheet.', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Report loss / damage: scan the cartons, choose a reason.
// ---------------------------------------------------------------------------
class ReportLossScreen extends StatefulWidget {
  const ReportLossScreen({super.key});

  @override
  State<ReportLossScreen> createState() => _ReportLossScreenState();
}

class _ReportLossScreenState extends State<ReportLossScreen> {
  static const _reasons = {
    'DAMAGED': 'Damaged',
    'EXPIRED': 'Expired',
    'LOST': 'Lost / missing',
    'THEFT': 'Theft',
    'CONTAMINATED': 'Contaminated / pests',
    'RECALLED': 'Recalled',
    'OTHER': 'Other',
  };
  String _reason = 'DAMAGED';
  bool _holdOnly = false;
  bool _busy = false;
  final _note = TextEditingController();
  final _expected = TextEditingController(text: '1');
  final List<String> _uids = [];
  final _uuid = const Uuid();
  String? _key;

  @override
  void dispose() {
    _note.dispose();
    _expected.dispose();
    super.dispose();
  }

  String _uidOf(String raw) {
    try {
      final d = jsonDecode(raw);
      if (d is Map && d['boxUid'] != null) return d['boxUid'].toString();
    } catch (_) {}
    return raw.trim();
  }

  Future<void> _scan() async {
    final n = int.tryParse(_expected.text.trim()) ?? 0;
    if (n <= 0) return _toast('How many cartons will you scan?');
    final result = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(builder: (_) => MultiScanPage(title: 'Scan affected cartons', expectedCount: n, helperText: 'Scan the QR label on each carton.')),
    );
    if (result == null) return;
    setState(() {
      for (final raw in result) {
        final uid = _uidOf(raw);
        if (uid.isNotEmpty && !_uids.contains(uid)) _uids.add(uid);
      }
      _key = null;
    });
  }

  Future<void> _submit() async {
    if (_uids.isEmpty) return _toast('Scan at least one carton');
    if (_note.text.trim().length < 5 && _reason != 'EXPIRED' && _reason != 'RECALLED') {
      return _toast('Describe what happened');
    }
    setState(() => _busy = true);
    try {
      final api = await _api();
      final wh = await _myWarehouseId();
      if (_holdOnly) {
        final r = await api.request(
          method: 'POST',
          path: '/api/stock-adjustments/holds',
          data: {'warehouseId': wh, 'boxUids': _uids, 'reason': '${_reasons[_reason]}: ${_note.text.trim()}'},
        );
        if (!mounted) return;
        _toast('${r.data['held']} carton(s) put on hold');
      } else {
        _key ??= _uuid.v4();
        final r = await api.request(
          method: 'POST',
          path: '/api/stock-adjustments',
          headers: {'X-Idempotency-Key': _key!},
          data: {'warehouseId': wh, 'reason': _reason, 'note': _note.text.trim(), 'boxUids': _uids},
        );
        if (!mounted) return;
        _toast('${r.data['adjustmentNumber']} sent for approval. Attach photos on the dashboard.');
      }
      Navigator.pop(context, true);
    } catch (e) {
      _toast(_message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AnchorAppBar(title: 'Report loss or damage'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: _reason,
                    decoration: const InputDecoration(labelText: 'Reason'),
                    items: [for (final e in _reasons.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: _busy ? null : (v) => setState(() => _reason = v ?? 'DAMAGED'),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _note, enabled: !_busy, maxLines: 2, decoration: const InputDecoration(labelText: 'What happened?')),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _holdOnly,
                    onChanged: _busy ? null : (v) => setState(() => _holdOnly = v),
                    title: const Text('Only put on hold'),
                    subtitle: const Text('Not sure yet: keep the cartons from being dispatched until checked.'),
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      SizedBox(
                        width: 110,
                        child: TextField(controller: _expected, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Cartons')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.tonalIcon(onPressed: _busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan cartons')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_uids.isEmpty) Text('No cartons scanned yet.', style: TextStyle(color: cs.onSurfaceVariant)),
                  for (final u in _uids)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.inventory_2_outlined),
                      title: Text(u),
                      trailing: IconButton(icon: const Icon(Icons.close), onPressed: _busy ? null : () => setState(() => _uids.remove(u))),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _busy || _uids.isEmpty ? null : _submit,
            icon: Icon(_holdOnly ? Icons.pause_circle_outline : Icons.send_outlined),
            label: Text(_holdOnly ? 'Put ${_uids.length} on hold' : 'Request write-off (${_uids.length})'),
          ),
          const SizedBox(height: 8),
          Text(
            _holdOnly ? 'Held cartons cannot be dispatched until released on the dashboard.' : 'An administrator must approve before the cartons leave stock. They are on hold meanwhile.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
