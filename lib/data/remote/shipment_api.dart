import '../../core/config/app_config.dart';
import 'api_client.dart';

class ShipmentListItemDto {
  final String id;
  final String manifestNo;
  final String status;
  final String? note;
  final String? fromWarehouseName;
  final String? fromWarehouseCode;
  final String? toFacilityName;
  final String? toFacilityCode;
  final DateTime? dispatchedAt;
  final int itemCount;

  ShipmentListItemDto({
    required this.id,
    required this.manifestNo,
    required this.status,
    this.note,
    this.fromWarehouseName,
    this.fromWarehouseCode,
    this.toFacilityName,
    this.toFacilityCode,
    this.dispatchedAt,
    required this.itemCount,
  });

  factory ShipmentListItemDto.fromJson(Map<String, dynamic> j) {
    DateTime? at;
    final raw = j['dispatchedAt'] ?? j['createdAt'];
    if (raw is String && raw.trim().isNotEmpty) {
      at = DateTime.tryParse(raw.trim());
    }

    final from = (j['fromWarehouse'] is Map) ? (j['fromWarehouse'] as Map).cast<String, dynamic>() : null;
    final to = (j['toFacility'] is Map) ? (j['toFacility'] as Map).cast<String, dynamic>() : null;

    return ShipmentListItemDto(
      id: (j['id'] ?? '').toString(),
      manifestNo: (j['manifestNo'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      note: j['note']?.toString(),
      fromWarehouseName: from?['name']?.toString(),
      fromWarehouseCode: from?['code']?.toString(),
      toFacilityName: to?['name']?.toString(),
      toFacilityCode: to?['code']?.toString(),
      dispatchedAt: at,
      itemCount: (j['itemCount'] is int) ? j['itemCount'] as int : int.tryParse('${j['itemCount']}') ?? 0,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'manifestNo': manifestNo,
        'status': status,
        'note': note,
        'fromWarehouseName': fromWarehouseName,
        'fromWarehouseCode': fromWarehouseCode,
        'toFacilityName': toFacilityName,
        'toFacilityCode': toFacilityCode,
        'dispatchedAt': dispatchedAt?.toIso8601String(),
        'itemCount': itemCount,
      };
}

class ShipmentDetailDto {
  final String id;
  final String manifestNo;
  final String status;
  final String? fromWarehouseName;
  final String? fromWarehouseCode;
  final String? toFacilityName;
  final String? toFacilityCode;
  final DateTime? dispatchedAt;
  final List<BoxInShipmentDto> boxes;

  ShipmentDetailDto({
    required this.id,
    required this.manifestNo,
    required this.status,
    this.fromWarehouseName,
    this.fromWarehouseCode,
    this.toFacilityName,
    this.toFacilityCode,
    this.dispatchedAt,
    required this.boxes,
  });

  factory ShipmentDetailDto.fromJson(Map<String, dynamic> j) {
    final from = (j['fromWarehouse'] is Map) ? (j['fromWarehouse'] as Map).cast<String, dynamic>() : null;
    final to = (j['toFacility'] is Map) ? (j['toFacility'] as Map).cast<String, dynamic>() : null;

    DateTime? at;
    final raw = j['dispatchedAt'];
    if (raw is String && raw.trim().isNotEmpty) at = DateTime.tryParse(raw.trim());

    final items = <BoxInShipmentDto>[];
    final rawItems = j['items'];
    if (rawItems is List) {
      for (final it in rawItems.whereType<Map>()) {
        final m = it.cast<String, dynamic>();
        if (m['box'] is Map) {
          items.add(BoxInShipmentDto.fromBoxJson((m['box'] as Map).cast<String, dynamic>()));
        }
      }
    }

    return ShipmentDetailDto(
      id: (j['id'] ?? '').toString(),
      manifestNo: (j['manifestNo'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      fromWarehouseName: from?['name']?.toString(),
      fromWarehouseCode: from?['code']?.toString(),
      toFacilityName: to?['name']?.toString(),
      toFacilityCode: to?['code']?.toString(),
      dispatchedAt: at,
      boxes: items,
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'id': id,
        'manifestNo': manifestNo,
        'status': status,
        'fromWarehouseName': fromWarehouseName,
        'fromWarehouseCode': fromWarehouseCode,
        'toFacilityName': toFacilityName,
        'toFacilityCode': toFacilityCode,
        'dispatchedAt': dispatchedAt?.toIso8601String(),
        'boxes': boxes.map((b) => b.toCacheJson()).toList(),
      };
}

class BoxInShipmentDto {
  final String boxUid;
  final String? batchNo;
  final DateTime? expiryDate;
  final String? status;

  BoxInShipmentDto({
    required this.boxUid,
    this.batchNo,
    this.expiryDate,
    this.status,
  });

  factory BoxInShipmentDto.fromBoxJson(Map<String, dynamic> b) {
    DateTime? exp;
    final raw = b['expiryDate'];
    if (raw is String && raw.trim().isNotEmpty) exp = DateTime.tryParse(raw.trim());

    return BoxInShipmentDto(
      boxUid: (b['boxUid'] ?? '').toString(),
      batchNo: b['batchNo']?.toString(),
      expiryDate: exp,
      status: b['status']?.toString(),
    );
  }

  Map<String, dynamic> toCacheJson() => {
        'boxUid': boxUid,
        'batchNo': batchNo,
        'expiryDate': expiryDate?.toIso8601String(),
        'status': status,
      };
}

/// Remote shipments API.
///
/// Backend:
/// - GET /api/shipments?status=DISPATCHED
/// - GET /api/shipments/:id
class ShipmentApi {
  final ApiClient _api;

  ShipmentApi(this._api);

  Future<List<ShipmentListItemDto>> listOpenShipments() async {
    final path = '${AppConfig.shipmentsPath}?status=DISPATCHED';
    final resp = await _api.request(method: 'GET', path: path);
    final data = resp.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => ShipmentListItemDto.fromJson(e.cast<String, dynamic>()))
          .toList();
    }
    return const [];
  }

  Future<ShipmentDetailDto?> getShipment(String shipmentId) async {
    final id = shipmentId.trim();
    if (id.isEmpty) return null;
    final path = '${AppConfig.shipmentsPath}/$id';
    final resp = await _api.request(method: 'GET', path: path);
    final data = resp.data;
    if (data is Map) {
      return ShipmentDetailDto.fromJson(data.cast<String, dynamic>());
    }
    return null;
  }
}
