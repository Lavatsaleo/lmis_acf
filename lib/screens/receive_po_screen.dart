import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../utils/remote_pdf.dart';
import '../widgets/anchor_brand.dart';

/// Warehouse (online): receive a delivery against a purchase order.
///
/// The PO itself is entered on the dashboard with the signed PDF. Here the
/// warehouse records what physically arrived: per PO line, the batch number,
/// expiry date and number of cartons. The server creates one box (QR label)
/// per carton tagged with the PO line and donor, then the label sheet prints.
///
/// Backend:
/// - GET  /api/purchase-orders?status=OPEN_ANY&warehouseId=...
/// - GET  /api/purchase-orders/:id
/// - POST /api/purchase-orders/:id/receipts   (X-Idempotency-Key)
/// - GET  /api/orders/:orderId/print/a3?goodsReceiptId=...
class ReceivePoListScreen extends StatefulWidget {
  const ReceivePoListScreen({super.key});

  @override
  State<ReceivePoListScreen> createState() => _ReceivePoListScreenState();
}

class _ReceivePoListScreenState extends State<ReceivePoListScreen> {
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final SessionStore _sessionStore = SessionStore();

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _pos = const [];
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await _sessionStore.readUserJson();
      final warehouseId = (me?['warehouseId'] ?? me?['facilityId'])?.toString() ?? '';
      final api = ApiClient.create(baseUrl: await _settingsRepo.getBaseUrl());
      final resp = await api.request(
        method: 'GET',
        path: '/api/purchase-orders?status=OPEN_ANY${warehouseId.isEmpty ? '' : '&warehouseId=$warehouseId'}',
      );
      final data = resp.data;
      final rows = (data is Map && data['rows'] is List) ? (data['rows'] as List) : const [];
      if (!mounted) return;
      setState(() {
        _pos = rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: const AnchorAppBar(title: 'Receive delivery'),
        body: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Purchase orders awaiting delivery at your warehouse. POs are entered on the Anchor dashboard with the signed PDF.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              if (_loading) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator())),
              if (_error != null)
                Card(
                  color: cs.errorContainer,
                  child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: cs.onErrorContainer))),
                ),
              if (!_loading && _error == null && _pos.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No purchase orders are waiting for delivery. Ask the office to enter the PO on the dashboard.'),
                  ),
                ),
              for (final po in _pos) _PoCard(po: po, onTap: () => _open(po)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _open(Map<String, dynamic> po) async {
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ReceivePoScreen(poId: po['id'].toString())),
    );
    if (done == true) {
      _changed = true;
      _load();
    }
  }
}

class _PoCard extends StatelessWidget {
  final Map<String, dynamic> po;
  final VoidCallback onTap;
  const _PoCard({required this.po, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final totals = (po['totals'] as Map?)?.cast<String, dynamic>() ?? const {};
    final donors = (po['donors'] as List? ?? const []).whereType<Map>().map((d) => d['name']).join(', ');
    final overdue = po['isOverdue'] == true;
    final expected = (po['expectedDeliveryDate'] ?? '').toString();
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(po['poNumber'].toString(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                  if (overdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(8)),
                      child: Text('Overdue', style: TextStyle(color: cs.onErrorContainer, fontSize: 12, fontWeight: FontWeight.w700)),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [po['supplierName'], donors].where((x) => x != null && x.toString().isNotEmpty).join(' · '),
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
              ),
              const SizedBox(height: 8),
              LinearProgress(value: ((totals['percentReceived'] ?? 0) as num).toDouble() / 100),
              const SizedBox(height: 6),
              Text(
                '${totals['receivedPacks'] ?? 0} of ${totals['orderedPacks'] ?? 0} received · ${totals['outstandingPacks'] ?? 0} outstanding'
                '${expected.length >= 10 ? ' · expected ${expected.substring(0, 10)}' : ''}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LinearProgress extends StatelessWidget {
  final double value;
  const LinearProgress({super.key, required this.value});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 6),
      );
}

/// One batch row being received against a PO line.
class _BatchRow {
  final String lineId;
  final TextEditingController batch = TextEditingController();
  final TextEditingController cartons;
  DateTime? expiry;
  _BatchRow(this.lineId, int cartons) : cartons = TextEditingController(text: '$cartons');
  void dispose() {
    batch.dispose();
    cartons.dispose();
  }
}

class ReceivePoScreen extends StatefulWidget {
  final String poId;
  const ReceivePoScreen({super.key, required this.poId});

  @override
  State<ReceivePoScreen> createState() => _ReceivePoScreenState();
}

class _ReceivePoScreenState extends State<ReceivePoScreen> {
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final TokenStore _tokenStore = const TokenStore();
  final _uuid = const Uuid();

  Map<String, dynamic>? _po;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  final List<_BatchRow> _rows = [];
  final _deliveryNote = TextEditingController();
  final _waybill = TextEditingController();
  final _note = TextEditingController();

  // Same key across retries of the same submission (e.g. after a timeout when
  // the server may already have recorded it); a new key after any edit.
  String? _key;
  String? _keyInput;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final r in _rows) {
      r.dispose();
    }
    _deliveryNote.dispose();
    _waybill.dispose();
    _note.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _openLines => ((_po?['lines'] as List?) ?? const [])
      .whereType<Map>()
      .map((e) => e.cast<String, dynamic>())
      .where((l) => ((l['outstandingPacks'] ?? 0) as num) > 0)
      .toList();

  Future<void> _load() async {
    try {
      final api = ApiClient.create(baseUrl: await _settingsRepo.getBaseUrl());
      final resp = await api.request(method: 'GET', path: '/api/purchase-orders/${widget.poId}');
      final po = (resp.data as Map).cast<String, dynamic>();
      if (!mounted) return;
      setState(() {
        _po = po;
        for (final l in _openLines) {
          _rows.add(_BatchRow(l['id'].toString(), (l['outstandingPacks'] as num).toInt()));
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _message(e);
        _loading = false;
      });
    }
  }

  String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickExpiry(_BatchRow r) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: r.expiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => r.expiry = picked);
  }

  void _toast(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _submit() async {
    if (_saving || _po == null) return;
    final lines = {for (final l in _openLines) l['id'].toString(): l};
    final use = _rows.where((r) => (int.tryParse(r.cartons.text.trim()) ?? 0) > 0).toList();
    if (use.isEmpty) return _toast('Enter the cartons received on at least one line');
    final perLine = <String, int>{};
    for (final r in use) {
      if (r.batch.text.trim().isEmpty) return _toast('Enter the batch number for every line received');
      if (r.expiry == null) return _toast('Pick the expiry date for every line received');
      perLine[r.lineId] = (perLine[r.lineId] ?? 0) + int.parse(r.cartons.text.trim());
    }
    for (final e in perLine.entries) {
      final l = lines[e.key]!;
      final outstanding = (l['outstandingPacks'] as num).toInt();
      if (e.value > outstanding) {
        return _toast('Line ${l['lineNo']}: ${e.value} entered but only $outstanding outstanding');
      }
    }

    final payloadLines = use
        .map((r) => {
              'lineId': r.lineId,
              'batchNo': r.batch.text.trim(),
              'expiryDate': _ymd(r.expiry!),
              'packs': int.parse(r.cartons.text.trim()),
            })
        .toList();
    final input = [payloadLines.toString(), _deliveryNote.text, _waybill.text, _note.text].join('|');
    if (_key == null || _keyInput != input) {
      _key = _uuid.v4();
      _keyInput = input;
    }

    setState(() => _saving = true);
    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final resp = await api.request(
        method: 'POST',
        path: '/api/purchase-orders/${widget.poId}/receipts',
        headers: {'X-Idempotency-Key': _key!},
        receiveTimeout: const Duration(minutes: 3),
        data: {
          'deliveryNote': _deliveryNote.text.trim(),
          'waybillNo': _waybill.text.trim(),
          'note': _note.text.trim(),
          'lines': payloadLines,
        },
      );
      final m = (resp.data as Map).cast<String, dynamic>();
      final orderId = m['orderId']?.toString();
      final receiptId = (m['receipt'] as Map?)?['id']?.toString();
      final grn = m['grnNumber']?.toString() ?? '';
      final count = m['createdCount'] ?? 0;

      if (orderId != null && receiptId != null) {
        try {
          final Uint8List pdf = await RemotePdf.downloadPdfBytes(
            baseUrl: baseUrl,
            pathOrUrl: '/api/orders/$orderId/print/a3?goodsReceiptId=$receiptId',
            accessToken: await _tokenStore.readAccessToken(),
          );
          await Printing.layoutPdf(onLayout: (_) async => pdf);
        } catch (e) {
          if (mounted) _toast('Received, but labels did not print: ${_message(e)}. Print them from the dashboard.');
        }
      }
      _key = null;
      _keyInput = null;
      if (!mounted) return;
      _toast('$grn: $count boxes received');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('Receive failed: ${_message(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final po = _po;
    final total = _rows.fold<int>(0, (s, r) => s + (int.tryParse(r.cartons.text.trim()) ?? 0));
    return Scaffold(
      appBar: AnchorAppBar(title: po == null ? 'Receive goods' : 'Receive ${po['poNumber']}'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: TextStyle(color: cs.error)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Enter the batch and expiry printed on the cartons. If one line arrived as two batches, tap "Add batch" on it. Set cartons to 0 for lines that did not arrive.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                    for (final l in _openLines) _lineCard(l, cs),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            TextField(controller: _deliveryNote, enabled: !_saving, decoration: const InputDecoration(labelText: 'Supplier delivery note no.')),
                            const SizedBox(height: 12),
                            TextField(controller: _waybill, enabled: !_saving, decoration: const InputDecoration(labelText: 'Waybill no.')),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _note,
                              enabled: !_saving,
                              maxLines: 2,
                              decoration: const InputDecoration(labelText: 'Notes (damages, shortages…)'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving || total <= 0 ? null : _submit,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.print_outlined),
                      label: Text('Receive $total boxes & print labels'),
                    ),
                  ],
                ),
    );
  }

  Widget _lineCard(Map<String, dynamic> l, ColorScheme cs) {
    final id = l['id'].toString();
    final product = (l['product'] as Map?)?['name'] ?? '';
    final donor = (l['donor'] as Map?)?['name'] ?? '';
    final rows = _rows.where((r) => r.lineId == id).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${l['lineNo']}. $product', style: const TextStyle(fontWeight: FontWeight.w900)),
            Text('$donor · ${l['outstandingPacks']} outstanding of ${l['quantityPacks']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            for (final r in rows) ...[
              const SizedBox(height: 12),
              TextField(
                controller: r.batch,
                enabled: !_saving,
                decoration: const InputDecoration(labelText: 'Batch number'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _saving ? null : () => _pickExpiry(r),
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Expiry date', border: OutlineInputBorder()),
                        child: Text(r.expiry == null ? 'Select date' : _ymd(r.expiry!)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: r.cartons,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Cartons'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  if (rows.length > 1)
                    IconButton(
                      tooltip: 'Remove batch',
                      onPressed: _saving
                          ? null
                          : () => setState(() {
                                _rows.remove(r);
                                r.dispose();
                              }),
                      icon: const Icon(Icons.delete_outline),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving ? null : () => setState(() => _rows.add(_BatchRow(id, 0))),
                icon: const Icon(Icons.add),
                label: const Text('Add batch'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _message(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    return e.message ?? e.toString();
  }
  return e.toString();
}
