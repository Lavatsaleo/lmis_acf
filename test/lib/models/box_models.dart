import 'dart:convert';

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
        "expiryDate": dateOnly(expiryDate),
      });

  static String dateOnly(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return "$y-$m-$day";
  }
}

