import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/box_models.dart';
import 'package:lmis_acf/stores/box_store.dart';
import 'package:lmis_acf/screens/commodity/commodity_utils.dart';

class RegisterBoxPage extends StatefulWidget {
  const RegisterBoxPage({super.key});

  @override
  State<RegisterBoxPage> createState() => _RegisterBoxPageState();
}

class _RegisterBoxPageState extends State<RegisterBoxPage> {
  final _formKey = GlobalKey<FormState>();

  final _orderCtrl = TextEditingController();
  final _batchCtrl = TextEditingController();

  DateTime? _expiry;
  int? _nextNumber; // for UID
  BoxItem? _created;

  @override
  void initState() {
    super.initState();
    _loadNextUid();
  }

  Future<void> _loadNextUid() async {
    final next = await BoxStore.peekNextNumber();
    setState(() {
      _nextNumber = next;
    });
  }

  @override
  void dispose() {
    _orderCtrl.dispose();
    _batchCtrl.dispose();
    super.dispose();
  }

  String _makeId() => DateTime.now().microsecondsSinceEpoch.toString();

  Future<void> _pickExpiry() async {
  final now = DateTime.now();

  // Minimum expiry date = today + 90 days (no past dates allowed)
  final minDate = DateTime(now.year, now.month, now.day).add(const Duration(days: 90));
  final maxDate = DateTime(now.year + 10, now.month, now.day);

  final picked = await showDatePicker(
    context: context,
    firstDate: minDate, // ✅ locks out past dates and <90 days
    lastDate: maxDate,
    initialDate: _expiry ?? minDate,
    helpText: "Select Expiry Date (min 90 days from today)",
  );

  if (picked == null) return;

  // Extra safety check (in case)
  if (picked.isBefore(minDate)) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Expiry date must be at least 90 days from today (${_dateOnly(minDate)}).")),
    );
    return;
  }

  setState(() => _expiry = picked);
}


Future<void> _printLabel(BoxItem box) async {
  final doc = pw.Document();

  doc.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (context) {
        return pw.Center(
          child: _labelWidget(box), // single label centered
        );
      },
    ),
  );

  await Printing.layoutPdf(onLayout: (format) => doc.save());
}

pw.Widget _labelWidget(BoxItem box) {
  String dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  return pw.Container(
    width: 320,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 1),
      borderRadius: pw.BorderRadius.circular(8),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        pw.Text("Action Against Hunger", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text("BOX UID: ${box.boxUid}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text("Order No: ${box.orderNumber}", style: const pw.TextStyle(fontSize: 11)),
        pw.Text("Batch No: ${box.batchNumber}", style: const pw.TextStyle(fontSize: 11)),
        pw.Text("Expiry: ${dateOnly(box.expiryDate)}", style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.Center(
          child: pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: box.qrPayload(), // your JSON payload
            width: 160,
            height: 160,
          ),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text(
            box.boxUid,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ),
      ],
    ),
  );
}



  void _generate() {
    if (_nextNumber == null) return;
    if (!_formKey.currentState!.validate()) return;
    if (_expiry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select Expiry Date")),
      );
      return;
    }

    final uid = BoxStore.formatBoxUid(_nextNumber!);

    final box = BoxItem(
      boxId: _makeId(),
      boxUid: uid,
      orderNumber: _orderCtrl.text.trim(),
      batchNumber: _batchCtrl.text.trim(),
      expiryDate: _expiry!,
      status: BoxStatus.inWarehouse,
      createdAt: DateTime.now(),
      history: [],
    );

    setState(() => _created = box);
  }

  Future<void> _saveAndReturn() async {
    if (_created == null || _nextNumber == null) return;

    // Commit UID number as used (no gaps)
    await BoxStore.commitNumber(_nextNumber!);

    if (!mounted) return;
    Navigator.pop(context, _created);
  }

  String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  @override
  Widget build(BuildContext context) {
    final previewUid = _nextNumber == null ? "Loading..." : BoxStore.formatBoxUid(_nextNumber!);
    final created = _created;

    return Scaffold(
      appBar: AppBar(title: const Text("Register Box (Generate QR)")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(14),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  const Icon(Icons.confirmation_number_outlined, color: acfGrey),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      "Box UID (Auto): $previewUid",
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
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
                      label: Text(_expiry == null ? "Select Expiry Date" : "Expiry: ${_dateOnly(_expiry!)}"),
                    ),
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
                child: const Text("Generate QR"),
              ),
            ),

            const SizedBox(height: 18),

            if (created != null) ...[
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black12),
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.white,
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: created.qrPayload(),
                        size: 220,
                      ),
                      const SizedBox(height: 10),
                      Text(created.boxUid, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 6),
                      Text("Order: ${created.orderNumber}", style: const TextStyle(color: Colors.black87)),
                      Text("Batch: ${created.batchNumber}", style: const TextStyle(color: Colors.black87)),
                      Text("Expiry: ${_dateOnly(created.expiryDate)}", style: const TextStyle(color: Colors.black87)),
                      const SizedBox(height: 6),
                      Text("Internal ID: ${created.boxId}", style: const TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: acfGreen, foregroundColor: Colors.white),
                  onPressed: _saveAndReturn,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Box (Create in Warehouse)"),
                ),
              ),
 const SizedBox(height: 14),
Row(
  children: [
    Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: acfBlue, foregroundColor: Colors.white),
        onPressed: () => _printLabel(created),
        icon: const Icon(Icons.print),
        label: const Text("Print Label"),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: acfGreen, foregroundColor: Colors.white),
        onPressed: _saveAndReturn,
        icon: const Icon(Icons.save),
        label: const Text("Save Box"),
      ),
    ),
  ],
),
            ],
          ],
        ),
      ),
    );
  }
}



/// =============================
/// BULK REGISTER + BULK PRINT QR
/// =============================
