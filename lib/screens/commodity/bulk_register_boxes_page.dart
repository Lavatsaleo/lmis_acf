import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/box_models.dart';
import 'package:lmis_acf/stores/box_store.dart';
import 'package:lmis_acf/utils/label_pdf.dart';
import 'package:lmis_acf/screens/commodity/commodity_utils.dart';

class BulkRegisterBoxesPage extends StatefulWidget {
  const BulkRegisterBoxesPage({super.key});

  @override
  State<BulkRegisterBoxesPage> createState() => _BulkRegisterBoxesPageState();
}

class _BulkRegisterBoxesPageState extends State<BulkRegisterBoxesPage> {
  final _formKey = GlobalKey<FormState>();

  final _orderCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: "10");

  DateTime? _expiry;
  int? _startNumber; // first UID number
  List<BoxItem> _generated = [];

  static const int _columns = 3;
  static const int _rows = 8;
  static const int _labelsPerPage = _columns * _rows;

  @override
  void initState() {
    super.initState();
    _loadStartUid();
  }

  Future<void> _loadStartUid() async {
    final next = await BoxStore.peekNextNumber();
    if (!mounted) return;
    setState(() => _startNumber = next);
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _batchCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  int _readQty() {
    final n = int.tryParse(_qtyCtrl.text.trim());
    if (n == null || n <= 0) return 1;
    return n;
  }

  Future<void> _pickExpiry() async {
    final minExpiry = DateTime.now().add(const Duration(days: 90));
    final initial = (_expiry != null && _expiry!.isAfter(minExpiry)) ? _expiry! : minExpiry;

    final picked = await showDatePicker(
      context: context,
      firstDate: minExpiry,
      lastDate: DateTime(minExpiry.year + 10),
      initialDate: initial,
    );
    if (picked == null) return;

    setState(() => _expiry = picked);
  }

  String _makeId(String base, int n) => "$base-$n";

  void _generate() {
    if (_startNumber == null) return;
    if (!_formKey.currentState!.validate()) return;

    final qty = _readQty();
    if (qty > 5000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Too many boxes. Please do 5000 or less per batch.")),
      );
      return;
    }

    if (_expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Expiry Date (min 90 days from today)")),
      );
      return;
    }

    final base = DateTime.now().microsecondsSinceEpoch.toString();
    final createdAt = DateTime.now();
    final list = <BoxItem>[];

    for (int i = 0; i < qty; i++) {
      final n = _startNumber! + i;
      list.add(
        BoxItem(
          boxId: _makeId(base, n),
          boxUid: BoxStore.formatBoxUid(n),
          orderNumber: _orderCtrl.text.trim(),
          batchNumber: _batchCtrl.text.trim(),
          expiryDate: _expiry!,
          status: BoxStatus.inWarehouse,
          createdAt: createdAt,
          history: [],
        ),
      );
    }

    setState(() => _generated = list);
  }

  Future<void> _printBulk(List<BoxItem> boxes) async {
    if (boxes.isEmpty) return;

    final pdf = pw.Document();

    // A4 grid of small labels
    final margin = 10 * PdfPageFormat.mm;
    final format = PdfPageFormat.a4.copyWith(
      marginLeft: margin,
      marginRight: margin,
      marginTop: margin,
      marginBottom: margin,
    );
final usableW = format.width - format.marginLeft - format.marginRight;
    final usableH = format.height - format.marginTop - format.marginBottom;

    final cellW = usableW / _columns;
    final cellH = usableH / _rows;

    for (int start = 0; start < boxes.length; start += _labelsPerPage) {
      final end = (start + _labelsPerPage) < boxes.length ? (start + _labelsPerPage) : boxes.length;
      final chunk = boxes.sublist(start, end);

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          build: (_) {
            return pw.Wrap(
              spacing: 0,
              runSpacing: 0,
              children: chunk
                  .map((b) => _labelCell(b, cellW, cellH))
                  .toList(),
            );
          },
        ),
      );
    }

    await Printing.layoutPdf(
      name: "LMIS Box Labels (${boxes.length})",
      onLayout: (_) => pdf.save(),
    );
  }

  pw.Widget _labelCell(BoxItem box, double w, double h) {
    final qrSize = (h - 12) < (w * 0.45) ? (h - 12) : (w * 0.45);

    return pw.Container(
      width: w,
      height: h,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: qrSize,
            height: qrSize,
            child: pw.BarcodeWidget(
              barcode: pw.Barcode.qrCode(),
              data: box.qrPayload(),
            ),
          ),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  box.boxUid,
                  style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                  maxLines: 1,
                ),
                pw.SizedBox(height: 2),
                pw.Text("Order: ${box.orderNumber}", style: const pw.TextStyle(fontSize: 6), maxLines: 1),
                pw.Text("Batch: ${box.batchNumber}", style: const pw.TextStyle(fontSize: 6), maxLines: 1),
                pw.Text("Exp: ${BoxItem.dateOnly(box.expiryDate)}", style: const pw.TextStyle(fontSize: 6), maxLines: 1),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveOnly() async {
    if (_generated.isEmpty || _startNumber == null) return;

    final lastUsed = _startNumber! + _generated.length - 1;
    await BoxStore.commitNumber(lastUsed);

    if (!mounted) return;
    Navigator.pop(context, _generated);
  }

  Future<void> _saveAndPrint() async {
    if (_generated.isEmpty || _startNumber == null) return;

    final lastUsed = _startNumber! + _generated.length - 1;
    await BoxStore.commitNumber(lastUsed);

    // Print first (so the user can directly print/save PDF), then return to save into app list.
    await _printBulk(_generated);

    if (!mounted) return;
    Navigator.pop(context, _generated);
  }

  String _dateOnly(DateTime d) => BoxItem.dateOnly(d);

  @override
  Widget build(BuildContext context) {
    final start = _startNumber;
    final qty = _readQty();
    final startUid = start == null ? "Loading..." : BoxStore.formatBoxUid(start);
    final endUid = start == null ? "Loading..." : BoxStore.formatBoxUid(start + qty - 1);
    final pages = _generated.isEmpty ? 0 : ((_generated.length + _labelsPerPage - 1) ~/ _labelsPerPage);

    final preview = _generated.length <= 6 ? _generated : _generated.take(6).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Bulk Register & Print")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: Colors.black12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("UID range preview", style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    Text("Start: $startUid", style: const TextStyle(fontWeight: FontWeight.w700)),
                    Text("End:   $endUid", style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    const Text(
                      "Note: UID sequence is global. We commit the numbers only when you SAVE.",
                      style: TextStyle(color: Colors.black54, fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    controller: _orderCtrl,
                    decoration: const InputDecoration(
                      labelText: "Order Number",
                      hintText: "Enter supplier order number",
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Order number is required" : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _batchCtrl,
                    decoration: const InputDecoration(
                      labelText: "Batch Number",
                      hintText: "Enter batch number",
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? "Batch number is required" : null,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _pickExpiry,
                      icon: const Icon(Icons.event),
                      label: Text(_expiry == null ? "Select Expiry Date (≥ 90 days)" : "Expiry: ${_dateOnly(_expiry!)}"),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Quantity (number of boxes)",
                      hintText: "e.g. 1234",
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? "").trim());
                      if (n == null || n <= 0) return "Enter a valid quantity";
                      if (n > 5000) return "Max 5000 per batch";
                      return null;
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: acfBlue, foregroundColor: Colors.white),
                onPressed: _generate,
                child: const Text("Generate QR Codes"),
              ),
            ),

            const SizedBox(height: 18),

            if (_generated.isNotEmpty) ...[
              Text(
                "Generated: ${_generated.length} boxes  •  Pages: $pages (A4, $_labelsPerPage labels/page)",
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),

              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: preview.map((b) {
                  return Container(
                    width: 150,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black12),
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.white,
                    ),
                    child: Column(
                      children: [
                        QrImageView(data: b.qrPayload(), size: 90),
                        const SizedBox(height: 6),
                        Text(b.boxUid, style: const TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text("Order: ${b.orderNumber}", style: const TextStyle(fontSize: 11)),
                        Text("Batch: ${b.batchNumber}", style: const TextStyle(fontSize: 11)),
                        Text("Exp: ${BoxItem.dateOnly(b.expiryDate)}", style: const TextStyle(fontSize: 11)),
                      ],
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _printBulk(_generated),
                      icon: const Icon(Icons.print),
                      label: const Text("Print Only"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: acfGreen, foregroundColor: Colors.white),
                      onPressed: _saveOnly,
                      icon: const Icon(Icons.save),
                      label: const Text("Save Only"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: acfBlue, foregroundColor: Colors.white),
                  onPressed: _saveAndPrint,
                  icon: const Icon(Icons.save_alt),
                  label: const Text("Save & Print"),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Recommended: Save & Print (creates boxes in the Warehouse list and prints labels).",
                style: TextStyle(color: Colors.black54),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// =====================
/// DISPATCH PAGE
/// =====================
