import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../core/config/app_config.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../utils/remote_pdf.dart';
import '../widgets/acf_brand.dart';

/// Warehouse-only (online): Generate boxes (QR codes) and print A3 labels.
///
/// Backend:
/// - POST /api/orders
/// - POST /api/orders/:orderId/boxes/generate
/// - GET  /api/orders/:orderId/print/a3
class GenerateBoxesScreen extends StatefulWidget {
  const GenerateBoxesScreen({super.key});

  @override
  State<GenerateBoxesScreen> createState() => _GenerateBoxesScreenState();
}

class _GenerateBoxesScreenState extends State<GenerateBoxesScreen> {
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final TokenStore _tokenStore = const TokenStore();
  final SessionStore _sessionStore = SessionStore();

  final _orderNumberCtrl = TextEditingController();
  final _donorCtrl = TextEditingController();
  final _productCodeCtrl = TextEditingController();
  final _productNameCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '100');

  DateTime? _expiry;
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic>? _me;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    if (!mounted) return;
    setState(() {
      _me = me;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _orderNumberCtrl.dispose();
    _donorCtrl.dispose();
    _productCodeCtrl.dispose();
    _productNameCtrl.dispose();
    _batchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _expiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() => _expiry = picked);
  }

  String _fmtYmd(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _generateAndPrint() async {
    if (_saving) return;

    final me = _me;
    final role = (me?['role'] ?? '').toString();
    if (role != 'WAREHOUSE_OFFICER' && role != 'SUPER_ADMIN') {
      _toast('Your role ($role) cannot generate boxes');
      return;
    }

    final warehouseFacilityId = (me?['warehouseId'] ?? me?['facilityId'])?.toString();
    if (warehouseFacilityId == null || warehouseFacilityId.trim().isEmpty) {
      _toast('Your account is not linked to a warehouse facility');
      return;
    }

    final orderNumber = _orderNumberCtrl.text.trim();
    final donorName = _donorCtrl.text.trim();
    final productCode = _productCodeCtrl.text.trim();
    final productName = _productNameCtrl.text.trim();
    final batchNo = _batchCtrl.text.trim();
    final qty = int.tryParse(_qtyCtrl.text.trim()) ?? 0;
    final exp = _expiry;

    if (orderNumber.isEmpty) return _toast('Order number is required');
    if (productCode.isEmpty) return _toast('Product code is required');
    if (productName.isEmpty) return _toast('Product name is required');
    if (batchNo.isEmpty) return _toast('Batch number is required');
    if (exp == null) return _toast('Expiry date is required');
    if (qty <= 0) return _toast('Quantity must be > 0');

    setState(() => _saving = true);
    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);

      // 1) Create order (idempotent).
      final orderResp = await api.request(
        method: 'POST',
        path: AppConfig.ordersPath,
        data: {
          'orderNumber': orderNumber,
          if (donorName.isNotEmpty) 'donorName': donorName,
        },
      );

      String? orderId;
      if (orderResp.data is Map) {
        final m = (orderResp.data as Map).cast<String, dynamic>();
        if (m['id'] != null) {
          orderId = m['id'].toString();
        } else if (m['order'] is Map) {
          orderId = (m['order'] as Map)['id']?.toString();
        }
      }
      if (orderId == null || orderId.isEmpty) {
        throw Exception('Could not resolve orderId from server response');
      }

      // 2) Generate boxes.
      await api.request(
        method: 'POST',
        path: '${AppConfig.ordersPath}/$orderId/boxes/generate',
        data: {
          'productCode': productCode,
          'productName': productName,
          'batchNo': batchNo,
          'expiryDate': _fmtYmd(exp),
          'quantity': qty,
          'warehouseFacilityId': warehouseFacilityId,
          if (donorName.isNotEmpty) 'donorName': donorName,
        },
      );

      // 3) Print A3 labels.
      final token = await _tokenStore.readAccessToken();
      final Uint8List pdf = await RemotePdf.downloadPdfBytes(
        baseUrl: baseUrl,
        pathOrUrl: '${AppConfig.ordersPath}/$orderId/print/a3',
        accessToken: token,
      );

      await Printing.layoutPdf(onLayout: (_) async => pdf);

      if (!mounted) return;
      _toast('Boxes generated and labels sent to printer');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _toast('Generate/print failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final me = _me;
    final facilityName = (me?['facilityName'] ?? '').toString();

    return Scaffold(
      appBar: const AcfAppBar(title: 'Generate boxes (QR) & print'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (facilityName.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(Icons.warehouse_outlined, color: cs.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              facilityName,
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
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
                        const Text('Order details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _orderNumberCtrl,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Order number',
                            hintText: 'e.g. SPO-ISL-00884-001',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _donorCtrl,
                          enabled: !_saving,
                          decoration: const InputDecoration(
                            labelText: 'Donor name (optional)',
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text('Product & batch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _productCodeCtrl,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: 'Product code'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _productNameCtrl,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: 'Product name'),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _batchCtrl,
                          enabled: !_saving,
                          decoration: const InputDecoration(labelText: 'Batch number'),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _saving ? null : _pickExpiry,
                                borderRadius: BorderRadius.circular(12),
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Expiry date',
                                    border: OutlineInputBorder(),
                                  ),
                                  child: Text(
                                    _expiry == null ? 'Select date' : _fmtYmd(_expiry!),
                                    style: TextStyle(color: _expiry == null ? cs.onSurfaceVariant : cs.onSurface),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              child: TextField(
                                controller: _qtyCtrl,
                                enabled: !_saving,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Quantity'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _saving ? null : _generateAndPrint,
                          icon: _saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.print_outlined),
                          label: const Text('Generate boxes & print QR labels (A3)'),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Warehouse is online: boxes are generated on the server and the A3 label sheet opens for printing immediately.',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
