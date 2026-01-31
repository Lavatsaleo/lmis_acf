import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/facility.dart';
import 'package:lmis_acf/models/box_models.dart';
import 'package:lmis_acf/models/shipment_models.dart';
import 'package:lmis_acf/models/scan_results.dart';
import 'package:lmis_acf/stores/box_store.dart';
import 'package:lmis_acf/stores/shipment_store.dart';
import 'package:lmis_acf/screens/commodity/register_box_page.dart';
import 'package:lmis_acf/screens/commodity/bulk_register_boxes_page.dart';
import 'package:lmis_acf/screens/commodity/dispatch_page.dart';
import 'package:lmis_acf/screens/commodity/receive_page.dart';
import 'package:lmis_acf/screens/commodity/shipments_page.dart';
import 'package:lmis_acf/screens/commodity/box_details_page.dart';
import 'package:lmis_acf/screens/commodity/commodity_utils.dart';

class CommodityManagementPage extends StatefulWidget {
  const CommodityManagementPage({super.key});

  @override
  State<CommodityManagementPage> createState() => _CommodityManagementPageState();
}

class ApplyResult {
  final int ok;
  final int skipped;
  final int notFound;
  final List<String> okBoxUids;

  ApplyResult({
    required this.ok,
    required this.skipped,
    required this.notFound,
    required this.okBoxUids,
  });
}

class _CommodityManagementPageState extends State<CommodityManagementPage> {
  bool _loading = true;
  List<BoxItem> _boxes = [];
  List<Shipment> _shipments = [];

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final boxes = await BoxStore.load();
    final shipments = await ShipmentStore.load();
    setState(() {
      _boxes = boxes;
      _shipments = shipments;
      _loading = false;
    });
  }

  Future<void> _persistBoxes() async => BoxStore.save(_boxes);
  Future<void> _persistShipments() async => ShipmentStore.save(_shipments);

  Future<void> _registerBox() async {
    final created = await Navigator.push<BoxItem?>(
      context,
      MaterialPageRoute(builder: (_) => const RegisterBoxPage()),
    );

    if (created == null) return;

    setState(() {
      _boxes.insert(0, created);
    });
    await _persistBoxes();
  }

Future<void> _bulkRegisterBoxes() async {
  final createdList = await Navigator.push<List<BoxItem>?>(
    context,
    MaterialPageRoute(builder: (_) => const BulkRegisterBoxesPage()),
  );

  if (createdList == null || createdList.isEmpty) return;

  setState(() {
    // show newest on top
    _boxes.insertAll(0, createdList.reversed);
  });

  await _persistBoxes();
}


  Future<void> _dispatch() async {
    final result = await Navigator.push<ScanSessionResult?>(
      context,
      MaterialPageRoute(builder: (_) => DispatchPage()),
    );

    if (result == null) return;

    // Prepare shipment id (commit number only if ok>0)
    final nextNo = await ShipmentStore.peekNextShipmentNo();
    final shipmentId = ShipmentStore.formatShipmentId(DateTime.now(), nextNo);

    final apply = await _applyBatchScans(
      payloads: result.payloads,
      type: "OUT",
      facility: result.facility,
      expectedCount: result.expectedCount,
      shipmentId: shipmentId,
      allowedBoxUids: null,
    );

    if (apply.ok > 0) {
      final shipment = Shipment(
        shipmentId: shipmentId,
        facilityName: result.facility.name,
        facilityOrgUnitUid: result.facility.orgUnitUid,
        createdAt: DateTime.now(),
        expectedCount: result.expectedCount,
        boxUids: apply.okBoxUids,
        status: ShipmentStatus.inTransit,
        receivedBoxUids: [],
      );

      setState(() {
        _shipments.insert(0, shipment);
      });

      await ShipmentStore.commitShipmentNo(nextNo);
      await _persistShipments();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Dispatch saved. OK=${apply.ok}, skipped=${apply.skipped}, notFound=${apply.notFound}"
          "${apply.ok > 0 ? " | Shipment: $shipmentId" : ""}",
        ),
      ),
    );
  }

  Future<void> _receive() async {
    final result = await Navigator.push<ReceiveSessionResult?>(
      context,
      MaterialPageRoute(builder: (_) => ReceivePage(shipments: _shipments)),
    );

    if (result == null) return;

    final shipmentIdx = _shipments.indexWhere((s) => s.shipmentId == result.shipmentId);
    if (shipmentIdx == -1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Shipment not found.")));
      return;
    }

    final shipment = _shipments[shipmentIdx];

    final allowed = shipment.boxUids.toSet();
    final alreadyReceived = shipment.receivedBoxUids.toSet();

    final apply = await _applyBatchScans(
      payloads: result.payloads,
      type: "IN",
      facility: result.facility,
      expectedCount: result.expectedCount,
      shipmentId: shipment.shipmentId,
      allowedBoxUids: allowed,
      alreadyReceived: alreadyReceived,
    );

    // Update shipment
    if (apply.ok > 0) {
      final updatedReceived = {...shipment.receivedBoxUids, ...apply.okBoxUids}.toList();

      setState(() {
        shipment.receivedBoxUids
          ..clear()
          ..addAll(updatedReceived);

        if (shipment.remaining == 0) {
          shipment.status = ShipmentStatus.received;
          shipment.receivedAt = DateTime.now();
        }
      });

      await _persistShipments();
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "Receive saved. OK=${apply.ok}, skipped=${apply.skipped}, notFound=${apply.notFound}"
          " | Shipment: ${shipment.shipmentId} | Remaining: ${shipment.remaining}",
        ),
      ),
    );
  }

  Future<ApplyResult> _applyBatchScans({
    required List<String> payloads,
    required String type, // OUT or IN
    required Facility facility,
    required int expectedCount,
    required String shipmentId,
    Set<String>? allowedBoxUids, // for IN (only boxes in shipment)
    Set<String>? alreadyReceived, // for IN
  }) async {
    int ok = 0;
    int skipped = 0;
    int notFound = 0;

    final okBoxUids = <String>[];

    for (final payload in payloads) {
      final parsed = _parsePayload(payload);
      final boxUid = (parsed["boxUid"] as String?)?.trim();

      if (boxUid == null || boxUid.isEmpty) {
        skipped++;
        continue;
      }

      final idx = _boxes.indexWhere((b) => b.boxUid == boxUid);
      if (idx == -1) {
        notFound++;
        continue;
      }

      final box = _boxes[idx];
      final from = box.status;

      if (type == "OUT") {
        if (box.status != BoxStatus.inWarehouse) {
          skipped++;
          continue;
        }

        box.status = BoxStatus.inTransit;
        box.toFacilityName = facility.name;
        box.toFacilityOrgUnitUid = facility.orgUnitUid;
        box.lastShipmentId = shipmentId;

        box.history.insert(
          0,
          MovementLog(
            type: "OUT",
            at: DateTime.now(),
            facilityName: facility.name,
            facilityOrgUnitUid: facility.orgUnitUid,
            fromStatus: from.name,
            toStatus: box.status.name,
            shipmentId: shipmentId,
          ),
        );

        ok++;
        okBoxUids.add(boxUid);
      } else {
        // IN rules
        if (box.status != BoxStatus.inTransit) {
          skipped++;
          continue;
        }

        // must match facility
        if (box.toFacilityOrgUnitUid != facility.orgUnitUid) {
          skipped++;
          continue;
        }

        // must belong to shipment
        if (allowedBoxUids != null && !allowedBoxUids.contains(boxUid)) {
          skipped++;
          continue;
        }

        // must not be already received
        if (alreadyReceived != null && alreadyReceived.contains(boxUid)) {
          skipped++;
          continue;
        }

        box.status = BoxStatus.receivedAtFacility;
        box.lastShipmentId = shipmentId;

        box.history.insert(
          0,
          MovementLog(
            type: "IN",
            at: DateTime.now(),
            facilityName: facility.name,
            facilityOrgUnitUid: facility.orgUnitUid,
            fromStatus: from.name,
            toStatus: box.status.name,
            shipmentId: shipmentId,
          ),
        );

        ok++;
        okBoxUids.add(boxUid);
      }
    }

    setState(() {}); // refresh UI once
    await _persistBoxes();

    return ApplyResult(ok: ok, skipped: skipped, notFound: notFound, okBoxUids: okBoxUids);
  }

  Map<String, dynamic> _parsePayload(String payload) {
    try {
      final data = jsonDecode(payload);
      if (data is Map<String, dynamic>) return data;
      return {};
    } catch (_) {
      return {"boxUid": payload.trim()};
    }
  }

  String _statusText(BoxStatus s) {
    switch (s) {
      case BoxStatus.inWarehouse:
        return "In Warehouse";
      case BoxStatus.inTransit:
        return "In Transit";
      case BoxStatus.receivedAtFacility:
        return "Received at Facility";
    }
  }

  Color _statusColor(BoxStatus s) {
    switch (s) {
      case BoxStatus.inWarehouse:
        return acfBlue;
      case BoxStatus.inTransit:
        return Colors.orange;
      case BoxStatus.receivedAtFacility:
        return acfGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Commodity Management")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Register Box
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _registerBox,
                icon: const Icon(Icons.qr_code_2),
                label: const Text("Register Box (Generate QR)"),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _bulkRegisterBoxes,
                icon: const Icon(Icons.print_outlined),
                label: const Text("Bulk Register & Print QR"),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _dispatch,
                    icon: const Icon(Icons.local_shipping_outlined),
                    label: const Text("Dispatch to Facility"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _receive,
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text("Receive at Facility"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ShipmentsPage(shipments: _shipments)),
                  );
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text("Shipments (${_shipments.length})"),
              ),
            ),

            const SizedBox(height: 18),
            Align(
              alignment: Alignment.centerLeft,
              child: Text("Boxes", style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 10),

            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _boxes.isEmpty
                      ? const Center(child: Text("No boxes yet. Register one first."))
                      : ListView.builder(
                          itemCount: _boxes.length,
                          itemBuilder: (_, i) {
                            final b = _boxes[i];
                            return Card(
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: const BorderSide(color: Colors.black12),
                              ),
                              child: ListTile(
                                title: Text(
                                  b.boxUid,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                subtitle: Text(
                                  "${_statusText(b.status)}"
                                  "${b.toFacilityName != null ? " → ${b.toFacilityName}" : ""}",
                                ),
                                leading: Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: _statusColor(b.status),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => BoxDetailsPage(box: b)),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

/// =====================
/// REGISTER BOX (form)
/// =====================
