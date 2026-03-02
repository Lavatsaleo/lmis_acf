import '../../core/config/app_config.dart';
import 'api_client.dart';

class FacilityDto {
  final String id;
  final String name;
  final String? code;

  FacilityDto({required this.id, required this.name, this.code});

  factory FacilityDto.fromJson(Map<String, dynamic> j) {
    return FacilityDto(
      id: (j['id'] ?? '').toString(),
      name: (j['name'] ?? j['facilityName'] ?? '').toString(),
      code: j['code']?.toString(),
    );
  }
}

class BoxDto {
  final String boxUid;
  final String status;
  final String? currentFacilityId;
  final String? orderId;
  final String? productId;
  final String? batchNo;
  final DateTime? expiryDate;

  BoxDto({
    required this.boxUid,
    required this.status,
    this.currentFacilityId,
    this.orderId,
    this.productId,
    this.batchNo,
    this.expiryDate,
  });

  factory BoxDto.fromJson(Map<String, dynamic> j) {
    DateTime? exp;
    final rawExp = j['expiryDate'];
    if (rawExp is String && rawExp.trim().isNotEmpty) {
      exp = DateTime.tryParse(rawExp.trim());
    }
    return BoxDto(
      boxUid: (j['boxUid'] ?? '').toString(),
      status: (j['status'] ?? '').toString(),
      currentFacilityId: j['currentFacilityId']?.toString(),
      orderId: j['orderId']?.toString(),
      productId: j['productId']?.toString(),
      batchNo: j['batchNo']?.toString(),
      expiryDate: exp,
    );
  }
}

/// Minimal API calls used for "bootstrap" caching.
class BootstrapApi {
  final ApiClient _api;

  BootstrapApi(this._api);

  Future<List<FacilityDto>> fetchFacilities() async {
    final resp = await _api.request(method: 'GET', path: AppConfig.facilitiesPath);
    final data = resp.data;
    if (data is List) {
      return data.whereType<Map>().map((e) => FacilityDto.fromJson(e.cast<String, dynamic>())).toList();
    }
    if (data is Map && data['facilities'] is List) {
      final list = (data['facilities'] as List).whereType<Map>();
      return list.map((e) => FacilityDto.fromJson(e.cast<String, dynamic>())).toList();
    }
    return const [];
  }

  Future<List<BoxDto>> fetchBoxesForFacility(String facilityId) async {
    final fid = facilityId.trim();
    if (fid.isEmpty) return const [];
    final path = '${AppConfig.boxesPath}?facilityId=$fid';
    final resp = await _api.request(method: 'GET', path: path);
    final data = resp.data;
    if (data is List) {
      return data.whereType<Map>().map((e) => BoxDto.fromJson(e.cast<String, dynamic>())).toList();
    }
    if (data is Map && data['boxes'] is List) {
      final list = (data['boxes'] as List).whereType<Map>();
      return list.map((e) => BoxDto.fromJson(e.cast<String, dynamic>())).toList();
    }
    return const [];
  }
}
