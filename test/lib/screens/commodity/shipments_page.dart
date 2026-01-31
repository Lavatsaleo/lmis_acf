import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/shipment_models.dart';
import 'package:lmis_acf/stores/shipment_store.dart';
import 'package:lmis_acf/screens/commodity/commodity_utils.dart';

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
