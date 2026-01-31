import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';
import 'package:lmis_acf/models/box_models.dart';
import 'package:lmis_acf/screens/commodity/commodity_utils.dart';

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
