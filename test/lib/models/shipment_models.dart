import 'dart:convert';

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

