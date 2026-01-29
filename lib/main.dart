import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';


void main() {
  runApp(const LmisApp());
}

/// ============================
/// THEME (Action Against Hunger)
/// ============================
const acfGreen = Color(0xFF52AE32);
const acfBlue = Color(0xFF005FB6);
const acfGrey = Color(0xFF707070);

class LmisApp extends StatelessWidget {
  const LmisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LMIS ACF',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: acfBlue),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const HomePage(),
    );
  }
}

/// ===============
/// HOME (2 modules)
/// ===============
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HomeCard(
              title: 'Commodity Management',
              subtitle: 'Register boxes · Dispatch · Receive · Track',
              icon: Icons.inventory_2_outlined,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const CommodityManagementPage()),
                );
              },
            ),
            const SizedBox(height: 12),
            _HomeCard(
              title: 'Clinical Data (DHIS2)',
              subtitle: 'Coming next',
              icon: Icons.medical_services_outlined,
              onTap: () {},
              disabled: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  const _HomeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: disabled ? 0.6 : 1,
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(14),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Icon(icon, size: 28, color: acfGrey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black54),
            ],
          ),
        ),
      ),
    );
  }
}

/// ======================
/// FACILITIES (OrgUnit UID)
/// ======================
class Facility {
  final String name;
  final String orgUnitUid;

  const Facility({required this.name, required this.orgUnitUid});
}

const List<Facility> kFacilities = [
  Facility(name: 'Bulapesa Dispensary', orgUnitUid: 'pmTpnNl2kN4'),
  Facility(name: 'APU Dispensary', orgUnitUid: 'zIexRhvdCrl'),
  Facility(name: 'Kambi Garba Dispensary', orgUnitUid: 'aY6M7dNYhU2'),
  Facility(name: 'Tupendane Dispensary', orgUnitUid: 'Sb8oFX3kWl8'),
  Facility(name: 'Daaba Dispensary', orgUnitUid: 'n7iyO93AJrP'),
  Facility(name: 'Eremet Dispensary', orgUnitUid: 'DGRblhIhkLy'),
  Facility(name: 'Ngaremara Gok Dispensary', orgUnitUid: 'FFVEtmjDhHQ'),
  Facility(name: 'Samburu Complex', orgUnitUid: 'n5u0uxY1yzY'),
  Facility(name: 'Kipsing Dispensary', orgUnitUid: 'z69OWARU0Ws'),
  Facility(name: 'Lebalsherik Dispensary', orgUnitUid: 'NkCE2fcUwdM'),
  Facility(name: 'Narrapu Dispensary', orgUnitUid: 'U8pschcQI4I'),
  Facility(name: 'Oldonyiro Dispensary', orgUnitUid: 'rzD4ngxnLoU'),
  Facility(name: 'Tuale Dispensary', orgUnitUid: 'eV9FmRTJcob'),
  Facility(name: 'Biliqo Marara Dispensary', orgUnitUid: 'Qh7uxkCiSrg'),
  Facility(name: 'Bisan Biliqo Dispensary', orgUnitUid: 'VlHPTQAGM2k'),
  Facility(name: 'Bassa Dispensary', orgUnitUid: 'XISm6n5HvXv'),
  Facility(name: 'Korbesa Dispensary', orgUnitUid: 'mmcGL8iH0Qh'),
  Facility(name: 'Merti Facility', orgUnitUid: 'ZFz3NrjkUgX'),
];

/// ======================
/// DATA MODEL (Box + Log)
/// ======================
enum BoxStatus { inWarehouse, inTransit, receivedAtFacility }

class MovementLog {
  final String type; // "OUT" or "IN"
  final DateTime at;
  final String? facilityName;
  final String? facilityOrgUnitUid;
  final String fromStatus;
  final String toStatus;
  final String? shipmentId; // NEW

  MovementLog({
    required this.type,
    required this.at,
    required this.fromStatus,
    required this.toStatus,
    this.facilityName,
    this.facilityOrgUnitUid,
    this.shipmentId,
  });

  Map<String, dynamic> toJson() => {
        "type": type,
        "at": at.toIso8601String(),
        "facilityName": facilityName,
        "facilityOrgUnitUid": facilityOrgUnitUid,
        "fromStatus": fromStatus,
        "toStatus": toStatus,
        "shipmentId": shipmentId,
      };

  static MovementLog fromJson(Map<String, dynamic> json) => MovementLog(
        type: (json["type"] ?? "") as String,
        at: DateTime.parse((json["at"] ?? DateTime.now().toIso8601String()) as String),
        facilityName: json["facilityName"] as String?,
        facilityOrgUnitUid: json["facilityOrgUnitUid"] as String?,
        fromStatus: (json["fromStatus"] ?? "") as String,
        toStatus: (json["toStatus"] ?? "") as String,
        shipmentId: json["shipmentId"] as String?,
      );
}

class BoxItem {
  final String boxId; // internal stable id
  final String boxUid; // label UID e.g AAH-KE-ISL-001 (GLOBAL on device)
  final String orderNumber;
  final String batchNumber;
  final DateTime expiryDate;

  BoxStatus status;

  // Dispatch target
  String? toFacilityName;
  String? toFacilityOrgUnitUid;

  // Link to last shipment
  String? lastShipmentId;

  final DateTime createdAt;
  final List<MovementLog> history;

  BoxItem({
    required this.boxId,
    required this.boxUid,
    required this.orderNumber,
    required this.batchNumber,
    required this.expiryDate,
    required this.status,
    required this.createdAt,
    required this.history,
    this.toFacilityName,
    this.toFacilityOrgUnitUid,
    this.lastShipmentId,
  });

  Map<String, dynamic> toJson() => {
        "boxId": boxId,
        "boxUid": boxUid,
        "orderNumber": orderNumber,
        "batchNumber": batchNumber,
        "expiryDate": expiryDate.toIso8601String(),
        "status": status.name,
        "toFacilityName": toFacilityName,
        "toFacilityOrgUnitUid": toFacilityOrgUnitUid,
        "lastShipmentId": lastShipmentId,
        "createdAt": createdAt.toIso8601String(),
        "history": history.map((e) => e.toJson()).toList(),
      };

  static BoxItem fromJson(Map<String, dynamic> json) => BoxItem(
        boxId: json["boxId"] as String,
        boxUid: json["boxUid"] as String,
        orderNumber: json["orderNumber"] as String,
        batchNumber: json["batchNumber"] as String,
        expiryDate: DateTime.parse(json["expiryDate"] as String),
        status: BoxStatus.values.firstWhere((e) => e.name == (json["status"] as String)),
        toFacilityName: json["toFacilityName"] as String?,
        toFacilityOrgUnitUid: json["toFacilityOrgUnitUid"] as String?,
        lastShipmentId: json["lastShipmentId"] as String?,
        createdAt: DateTime.parse(json["createdAt"] as String),
        history: (json["history"] as List<dynamic>)
            .map((e) => MovementLog.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// This is what we encode into the QR (small + stable).
  String qrPayload() => jsonEncode({
        "boxUid": boxUid,
        "orderNumber": orderNumber,
        "batchNumber": batchNumber,
        "expiryDate": _dateOnly(expiryDate),
      });

  static String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }
}

/// ======================
/// SHIPMENTS (Dispatch Notes)
/// ======================
enum ShipmentStatus { inTransit, received }

class Shipment {
  final String shipmentId;
  final String facilityName;
  final String facilityOrgUnitUid;
  final DateTime createdAt;

  final int expectedCount; // what warehouse typed
  final List<String> boxUids; // what was actually scanned OUT

  ShipmentStatus status;
  DateTime? receivedAt;
  final List<String> receivedBoxUids;

  Shipment({
    required this.shipmentId,
    required this.facilityName,
    required this.facilityOrgUnitUid,
    required this.createdAt,
    required this.expectedCount,
    required this.boxUids,
    required this.status,
    required this.receivedBoxUids,
    this.receivedAt,
  });

  int get totalOut => boxUids.length;
  int get totalIn => receivedBoxUids.length;
  int get remaining => (totalOut - totalIn) < 0 ? 0 : (totalOut - totalIn);

  Map<String, dynamic> toJson() => {
        "shipmentId": shipmentId,
        "facilityName": facilityName,
        "facilityOrgUnitUid": facilityOrgUnitUid,
        "createdAt": createdAt.toIso8601String(),
        "expectedCount": expectedCount,
        "boxUids": boxUids,
        "status": status.name,
        "receivedAt": receivedAt?.toIso8601String(),
        "receivedBoxUids": receivedBoxUids,
      };

  static Shipment fromJson(Map<String, dynamic> json) => Shipment(
        shipmentId: json["shipmentId"] as String,
        facilityName: json["facilityName"] as String,
        facilityOrgUnitUid: json["facilityOrgUnitUid"] as String,
        createdAt: DateTime.parse(json["createdAt"] as String),
        expectedCount: (json["expectedCount"] as num).toInt(),
        boxUids: (json["boxUids"] as List<dynamic>).map((e) => e.toString()).toList(),
        status: ShipmentStatus.values.firstWhere((e) => e.name == (json["status"] as String)),
        receivedAt: json["receivedAt"] == null ? null : DateTime.parse(json["receivedAt"] as String),
        receivedBoxUids: (json["receivedBoxUids"] as List<dynamic>).map((e) => e.toString()).toList(),
      );
}

/// ======================
/// LOCAL STORAGE (simple)
/// ======================
class BoxStore {
  static const _boxesKey = "boxes_v2";
  static const _uidCounterKey = "box_uid_counter_v1"; // last used number; default 0

  static Future<List<BoxItem>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_boxesKey);
    if (raw == null || raw.trim().isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final out = <BoxItem>[];

      for (final e in decoded) {
        try {
          out.add(BoxItem.fromJson(e as Map<String, dynamic>));
        } catch (_) {
          // Skip any old/invalid records
        }
      }

      if (out.isEmpty && decoded.isNotEmpty) {
        await prefs.remove(_boxesKey);
      }

      return out;
    } catch (_) {
      await prefs.remove(_boxesKey);
      return [];
    }
  }

  static Future<void> save(List<BoxItem> boxes) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(boxes.map((b) => b.toJson()).toList());
    await prefs.setString(_boxesKey, raw);
  }

  /// Preview next number without committing (no gaps if user cancels).
  static Future<int> peekNextNumber() async {
    final prefs = await SharedPreferences.getInstance();
    final lastUsed = prefs.getInt(_uidCounterKey) ?? 0;
    return lastUsed + 1;
  }

  /// Commit next number as used.
  static Future<void> commitNumber(int used) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_uidCounterKey, used);
  }

  static String formatBoxUid(int n) {
    final suffix = n.toString().padLeft(3, '0');
    return "AAH-KE-ISL-$suffix";
  }
}

class ShipmentStore {
  static const _shipmentsKey = "shipments_v1";
  static const _shipmentCounterKey = "shipment_counter_v1"; // last used

  static Future<List<Shipment>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_shipmentsKey);
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => Shipment.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      await prefs.remove(_shipmentsKey);
      return [];
    }
  }

  static Future<void> save(List<Shipment> shipments) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(shipments.map((s) => s.toJson()).toList());
    await prefs.setString(_shipmentsKey, raw);
  }

  static Future<int> peekNextShipmentNo() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_shipmentCounterKey) ?? 0;
    return last + 1;
  }

  static Future<void> commitShipmentNo(int used) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_shipmentCounterKey, used);
  }

  static String formatShipmentId(DateTime now, int n) {
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final suffix = n.toString().padLeft(3, '0');
    return "SHIP-$y$m$d-$suffix";
  }
}

/// =====================
/// COMMODITY MANAGEMENT
/// =====================
class CommodityManagementPage extends StatefulWidget {
  const CommodityManagementPage({super.key});

  @override
  State<CommodityManagementPage> createState() => _CommodityManagementPageState();
}

class _ApplyResult {
  final int ok;
  final int skipped;
  final int notFound;
  final List<String> okBoxUids;

  _ApplyResult({
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
    final result = await Navigator.push<_ScanSessionResult?>(
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
    final result = await Navigator.push<_ReceiveSessionResult?>(
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

  Future<_ApplyResult> _applyBatchScans({
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

    return _ApplyResult(ok: ok, skipped: skipped, notFound: notFound, okBoxUids: okBoxUids);
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
                pw.Text("Exp: ${BoxItem._dateOnly(box.expiryDate)}", style: const pw.TextStyle(fontSize: 6), maxLines: 1),
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

  String _dateOnly(DateTime d) => BoxItem._dateOnly(d);

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
                        Text("Exp: ${BoxItem._dateOnly(b.expiryDate)}", style: const TextStyle(fontSize: 11)),
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
      _ScanSessionResult(payloads: payloads, facility: _facility!, expectedCount: expected),
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
      _ReceiveSessionResult(
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
class MultiScanPage extends StatefulWidget {
  final String title;
  final String helperText;
  final int expectedCount;

  const MultiScanPage({
    super.key,
    required this.title,
    required this.helperText,
    required this.expectedCount,
  });

  @override
  State<MultiScanPage> createState() => _MultiScanPageState();
}

class _MultiScanPageState extends State<MultiScanPage> {
  final MobileScannerController _controller = MobileScannerController();
  final List<String> _payloads = [];
  final Set<String> _uniqueKeys = {}; // boxUid keys

  bool _cooldown = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

Future<void> _onDetect(BarcodeCapture capture) async {
  if (_cooldown) return;

  // ✅ If we already reached the expected count, auto-close (safety net)
  if (_payloads.length >= widget.expectedCount) {
    await _controller.stop();
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    Navigator.pop(context, _payloads);
    return;
  }

  final barcodes = capture.barcodes;
  if (barcodes.isEmpty) return;

  final raw = barcodes.first.rawValue;
  if (raw == null || raw.trim().isEmpty) return;

  final parsed = _parsePayload(raw);
  final boxUid = (parsed["boxUid"] as String?)?.trim();
  if (boxUid == null || boxUid.isEmpty) return;

  // prevent duplicates
  if (_uniqueKeys.contains(boxUid)) return;

  setState(() {
    _payloads.add(raw);
    _uniqueKeys.add(boxUid);
    _cooldown = true;
  });

  // ✅ Hit the target: stop camera + close automatically
  if (_payloads.length >= widget.expectedCount) {
    await _controller.stop();
    await Future.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;
    Navigator.pop(context, _payloads);
    return;
  }

  // small delay to avoid rapid double scans
  await Future.delayed(const Duration(milliseconds: 800));
  if (mounted) setState(() => _cooldown = false);
}

  void _finish() {
    Navigator.pop(context, _payloads);
  }

  @override
  Widget build(BuildContext context) {
    final doneEnabled = _payloads.length >= widget.expectedCount;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed: doneEnabled ? _finish : null,
            child: const Text("DONE"),
          )
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text(
                          widget.helperText,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          "Scanned: ${_payloads.length} / ${widget.expectedCount}",
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: doneEnabled ? acfGreen : Colors.grey,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: doneEnabled ? _finish : null,
                            child: const Text("Finish Scanning"),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black12)),
              color: Colors.white,
            ),
            child: Text(
              _payloads.isEmpty ? "No scans yet." : "Latest: ${_extractUid(_payloads.last)}",
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  String _extractUid(String payload) {
    final parsed = _parsePayload(payload);
    return (parsed["boxUid"] as String?) ?? "Unknown";
  }
}

class _ScanSessionResult {
  final List<String> payloads;
  final Facility facility;
  final int expectedCount;

  _ScanSessionResult({
    required this.payloads,
    required this.facility,
    required this.expectedCount,
  });
}

class _ReceiveSessionResult {
  final List<String> payloads;
  final Facility facility;
  final int expectedCount;
  final String shipmentId;

  _ReceiveSessionResult({
    required this.payloads,
    required this.facility,
    required this.expectedCount,
    required this.shipmentId,
  });
}

/// =====================
/// SHIPMENTS PAGE
/// =====================
class ShipmentsPage extends StatelessWidget {
  final List<Shipment> shipments;

  const ShipmentsPage({super.key, required this.shipments});

  String _dateTime(DateTime d) => d.toLocal().toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Shipments")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: shipments.isEmpty
            ? const Center(child: Text("No shipments yet. Dispatch boxes to create one."))
            : ListView.builder(
                itemCount: shipments.length,
                itemBuilder: (_, i) {
                  final s = shipments[i];
                  final statusText = s.status == ShipmentStatus.inTransit ? "In Transit" : "Received";
                  final statusColor = s.status == ShipmentStatus.inTransit ? Colors.orange : acfGreen;

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Colors.black12),
                    ),
                    child: ListTile(
                      leading: Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      title: Text(s.shipmentId, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        "${s.facilityName}\n$statusText | OUT=${s.totalOut} IN=${s.totalIn} REM=${s.remaining}\n${_dateTime(s.createdAt)}",
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// =====================
/// BOX DETAILS (history)
/// =====================
class BoxDetailsPage extends StatelessWidget {
  final BoxItem box;

  const BoxDetailsPage({super.key, required this.box});

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

  String _dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }

  @override
  Widget build(BuildContext context) {
    final history = box.history;

    return Scaffold(
      appBar: AppBar(title: const Text("Box Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(box.boxUid, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text("Status: ${_statusText(box.status)}", style: const TextStyle(color: Colors.black54)),
            if (box.lastShipmentId != null) ...[
              const SizedBox(height: 4),
              Text("Shipment: ${box.lastShipmentId}", style: const TextStyle(color: Colors.black54)),
            ],
            const SizedBox(height: 12),

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
                    Text("Order: ${box.orderNumber}", style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text("Batch: ${box.batchNumber}", style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text("Expiry: ${_dateOnly(box.expiryDate)}", style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    if (box.toFacilityName != null)
                      Text(
                        "Assigned Facility: ${box.toFacilityName} (${box.toFacilityOrgUnitUid})",
                        style: const TextStyle(color: Colors.black87),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            const Text("History", style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),

            if (history.isEmpty)
              const Text("No movements yet.")
            else
              ...history.map((h) {
                final icon = h.type == "OUT" ? Icons.local_shipping_outlined : Icons.storefront_outlined;
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Colors.black12),
                  ),
                  child: ListTile(
                    leading: Icon(icon),
                    title: Text("${h.type}  ${h.fromStatus} → ${h.toStatus}"),
                    subtitle: Text(
                      "${h.at.toLocal()}\n${h.facilityName ?? ""} ${h.facilityOrgUnitUid ?? ""}\n${h.shipmentId ?? ""}"
                          .trim(),
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}
