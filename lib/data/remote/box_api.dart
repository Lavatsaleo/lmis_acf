import '../../core/config/app_config.dart';
import 'api_client.dart';

class BoxEventDto {
  final String type;
  final DateTime? createdAt;
  final String? fromFacilityId;
  final String? toFacilityId;
  final String? note;

  BoxEventDto({
    required this.type,
    this.createdAt,
    this.fromFacilityId,
    this.toFacilityId,
    this.note,
  });

  factory BoxEventDto.fromJson(Map<String, dynamic> j) {
    DateTime? at;
    final raw = j['createdAt'] ?? j['date'] ?? j['timestamp'];
    if (raw is String && raw.trim().isNotEmpty) {
      at = DateTime.tryParse(raw.trim());
    }
    return BoxEventDto(
      type: (j['type'] ?? j['eventType'] ?? '').toString(),
      createdAt: at,
      fromFacilityId: j['fromFacilityId']?.toString(),
      toFacilityId: j['toFacilityId']?.toString(),
      note: j['note']?.toString(),
    );
  }
}

class BoxDetailDto {
  final String boxUid;
  final String status;
  final String? currentFacilityId;
  final String? orderId;
  final String? productId;
  final String? batchNo;
  final DateTime? expiryDate;
  final List<BoxEventDto> events;

  BoxDetailDto({
    required this.boxUid,
    required this.status,
    this.currentFacilityId,
    this.orderId,
    this.productId,
    this.batchNo,
    this.expiryDate,
    required this.events,
  });

  factory BoxDetailDto.fromJson(Map<String, dynamic> j) {
    // Some backends wrap the box in { box: {...}, events: [...] }
    Map<String, dynamic> boxJson = j;
    if (j['box'] is Map) {
      boxJson = (j['box'] as Map).cast<String, dynamic>();
    }

    DateTime? exp;
    final rawExp = boxJson['expiryDate'];
    if (rawExp is String && rawExp.trim().isNotEmpty) {
      exp = DateTime.tryParse(rawExp.trim());
    }

    // Events may be at root or nested.
    final dynamic rawEvents = j['events'] ?? boxJson['events'];
    final List<BoxEventDto> events = <BoxEventDto>[];
    if (rawEvents is List) {
      for (final e in rawEvents.whereType<Map>()) {
        events.add(BoxEventDto.fromJson(e.cast<String, dynamic>()));
      }
    }

    return BoxDetailDto(
      boxUid: (boxJson['boxUid'] ?? '').toString(),
      status: (boxJson['status'] ?? '').toString(),
      currentFacilityId: boxJson['currentFacilityId']?.toString(),
      orderId: boxJson['orderId']?.toString(),
      productId: boxJson['productId']?.toString(),
      batchNo: boxJson['batchNo']?.toString(),
      expiryDate: exp,
      events: events,
    );
  }
}

/// Box lookup API (Step 7).
///
/// Backend expected: GET /api/boxes/:boxUid
class BoxApi {
  final ApiClient _api;

  BoxApi(this._api);

  Future<BoxDetailDto?> fetchBox(String boxUid) async {
    final uid = boxUid.trim();
    if (uid.isEmpty) return null;

    final path = '${AppConfig.boxesPath}/$uid';
    final resp = await _api.request(method: 'GET', path: path);
    final data = resp.data;
    if (data is Map) {
      return BoxDetailDto.fromJson(data.cast<String, dynamic>());
    }
    return null;
  }
}
