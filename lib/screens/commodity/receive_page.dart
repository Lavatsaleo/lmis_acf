import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/facility.dart';
import 'package:lmis_acf/models/shipment_models.dart';
import 'package:lmis_acf/models/scan_results.dart';
import 'package:lmis_acf/stores/shipment_store.dart';
import 'package:lmis_acf/screens/commodity/multi_scan_page.dart';

class ReceivePage extends StatefulWidget {
  final List<Shipment> shipments;

  const ReceivePage({super.key, required this.shipments});

  @override
  State<ReceivePage> createState() => _ReceivePageState();
}

class _ReceivePageState extends State<ReceivePage> {
  Facility? _facility;
  Shipment? _shipment;

  List<Shipment> get _availableShipments {
    if (_facility == null) return [];
    return widget.shipments
        .where((s) =>
            s.status == ShipmentStatus.inTransit && s.facilityOrgUnitUid == _facility!.orgUnitUid && s.remaining > 0)
        .toList();
  }

  Future<void> _startScan() async {
    if (_facility == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a facility first.")));
      return;
    }
    if (_shipment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a shipment first.")));
      return;
    }

    final expected = _shipment!.remaining;

    final payloads = await Navigator.push<List<String>?>(
      context,
      MaterialPageRoute(
        builder: (_) => MultiScanPage(
          title: "Receive: Scan IN",
          helperText: "Shipment ${_shipment!.shipmentId}\nScan $expected boxes to receive at ${_facility!.name}",
          expectedCount: expected,
        ),
      ),
    );

    if (payloads == null || payloads.isEmpty) return;

    if (!mounted) return;
    Navigator.pop(
      context,
      ReceiveSessionResult(
        payloads: payloads,
        facility: _facility!,
        expectedCount: expected,
        shipmentId: _shipment!.shipmentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final shipments = _availableShipments;

    return Scaffold(
      appBar: AppBar(title: const Text("Receive at Facility")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            DropdownButtonFormField<Facility>(
              initialValue: _facility,
              items: kFacilities.map((f) => DropdownMenuItem(value: f, child: Text(f.name))).toList(),
              onChanged: (v) {
                setState(() {
                  _facility = v;
                  _shipment = null; // reset shipment when facility changes
                });
              },
              decoration: const InputDecoration(labelText: "Select Facility (Receiver)"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<Shipment>(
              initialValue: _shipment,
              items: shipments
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text("${s.shipmentId}  (Remaining: ${s.remaining})"),
                      ))
                  .toList(),
              onChanged: (v) => setState(() => _shipment = v),
              decoration: const InputDecoration(labelText: "Select Shipment"),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: acfGreen, foregroundColor: Colors.white),
                onPressed: _startScan,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Start Scanning (IN)"),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Rule: IN scan receives ONLY boxes that belong to the selected shipment and facility.",
              style: TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// MULTI SCAN PAGE
/// =====================
