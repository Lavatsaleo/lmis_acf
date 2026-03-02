import '../../core/config/app_config.dart';
import 'api_client.dart';

class WarehouseBoxSummaryItem {
  final String boxUid;
  final String? batchNo;
  final String? expiryDate;
  final int sachetsRemaining;

  WarehouseBoxSummaryItem({
    required this.boxUid,
    this.batchNo,
    this.expiryDate,
    required this.sachetsRemaining,
  });

  factory WarehouseBoxSummaryItem.fromJson(Map<String, dynamic> j) {
    return WarehouseBoxSummaryItem(
      boxUid: (j['boxUid'] ?? '').toString(),
      batchNo: j['batchNo']?.toString(),
      expiryDate: j['expiryDate']?.toString(),
      sachetsRemaining: (j['sachetsRemaining'] is num) ? (j['sachetsRemaining'] as num).round() : 600,
    );
  }
}

class WarehouseSummaryDto {
  final int boxesInWarehouse;
  final int totalSachetsAvailable;
  final List<WarehouseBoxSummaryItem> boxes;

  WarehouseSummaryDto({
    required this.boxesInWarehouse,
    required this.totalSachetsAvailable,
    required this.boxes,
  });

  factory WarehouseSummaryDto.fromJson(Map<String, dynamic> j) {
    final boxesRaw = j['boxes'];
    final List<WarehouseBoxSummaryItem> boxes = <WarehouseBoxSummaryItem>[];
    if (boxesRaw is List) {
      for (final e in boxesRaw.whereType<Map>()) {
        boxes.add(WarehouseBoxSummaryItem.fromJson(e.cast<String, dynamic>()));
      }
    }
    return WarehouseSummaryDto(
      boxesInWarehouse: (j['boxesInWarehouse'] is num) ? (j['boxesInWarehouse'] as num).round() : boxes.length,
      totalSachetsAvailable:
          (j['totalSachetsAvailable'] is num) ? (j['totalSachetsAvailable'] as num).round() : (boxes.length * 600),
      boxes: boxes,
    );
  }
}

class WarehouseApi {
  final ApiClient _api;
  WarehouseApi(this._api);

  Future<WarehouseSummaryDto> fetchWarehouseSummary() async {
    final resp = await _api.request(method: 'GET', path: AppConfig.warehouseSummaryPath);
    final data = resp.data;
    if (data is Map) {
      return WarehouseSummaryDto.fromJson(data.cast<String, dynamic>());
    }
    return WarehouseSummaryDto(boxesInWarehouse: 0, totalSachetsAvailable: 0, boxes: const []);
  }
}
