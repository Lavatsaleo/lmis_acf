import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/facility.dart';
import 'package:lmis_acf/models/scan_results.dart';
import 'package:lmis_acf/screens/commodity/multi_scan_page.dart';

class DispatchPage extends StatefulWidget {
  const DispatchPage({super.key});

  @override
  State<DispatchPage> createState() => _DispatchPageState();
}

class _DispatchPageState extends State<DispatchPage> {
  Facility? _facility;
  final _countCtrl = TextEditingController(text: "1");

  @override
  void dispose() {
    _countCtrl.dispose();
    super.dispose();
  }

  int _readCount() {
    final n = int.tryParse(_countCtrl.text.trim());
    if (n == null || n <= 0) return 1;
    return n;
  }

  Future<void> _startScan() async {
    if (_facility == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a facility first.")));
      return;
    }

    final expected = _readCount();

    final payloads = await Navigator.push<List<String>?>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiScanPage(
          title: "Dispatch: Scan OUT",
          helperText: "Scan $expected boxes to dispatch to ${_facility!.name}",
          expectedCount: expected,
        ),
      ),
    );

    if (payloads == null || payloads.isEmpty) return;

    if (!mounted) return;
    Navigator.pop(
      context,
      ScanSessionResult(payloads: payloads, facility: _facility!, expectedCount: expected),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Dispatch to Facility")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<Facility>(
              initialValue: _facility,
              items: kFacilities
                  .map((f) => DropdownMenuItem(
                        value: f,
                        child: Text(f.name),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _facility = v),
              decoration: const InputDecoration(labelText: "Select Facility"),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _countCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Number of boxes to dispatch",
                hintText: "e.g. 10",
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: acfBlue, foregroundColor: Colors.white),
                onPressed: _startScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Start Scanning (OUT)"),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Rule: OUT scan moves status from In Warehouse → In Transit and assigns the facility.",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// RECEIVE PAGE (Select Shipment)
/// =====================
