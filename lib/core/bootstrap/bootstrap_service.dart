import '../config/app_config.dart';
import '../../data/local/settings/app_settings_repo.dart';
import '../../data/remote/api_client.dart';
import '../../data/remote/bootstrap_api.dart';
import '../../data/local/cache/facility_cache_repo.dart';
import '../../data/local/cache/box_cache_repo.dart';
import '../../data/local/isar/facility_cache.dart';
import '../../data/local/isar/box_cache.dart';

class BootstrapResult {
  final int facilitiesSaved;
  final int boxesSaved;
  final String baseUrl;

  const BootstrapResult({
    required this.facilitiesSaved,
    required this.boxesSaved,
    required this.baseUrl,
  });
}

/// Downloads master data needed for offline workflows.
///
/// Step 3A: cache facilities (and optionally boxes per facility).
class BootstrapService {
  final AppSettingsRepo _settingsRepo;
  final FacilityCacheRepo _facilityRepo;
  final BoxCacheRepo _boxRepo;

  BootstrapService({
    AppSettingsRepo? settingsRepo,
    FacilityCacheRepo? facilityRepo,
    BoxCacheRepo? boxRepo,
  })  : _settingsRepo = settingsRepo ?? AppSettingsRepo(),
        _facilityRepo = facilityRepo ?? FacilityCacheRepo(),
        _boxRepo = boxRepo ?? BoxCacheRepo();

  Future<BootstrapResult> syncDownFacilities() async {
    final baseUrl = await _settingsRepo.getBaseUrl();
    final api = ApiClient.create(baseUrl: baseUrl);
    final bootstrapApi = BootstrapApi(api);
    final facilities = await bootstrapApi.fetchFacilities();

    final records = facilities.map((f) {
      final r = FacilityCache()
        ..facilityId = f.id
        ..name = f.name
        ..code = f.code
        ..updatedAt = DateTime.now();
      return r;
    }).toList();

    await _facilityRepo.clear();
    await _facilityRepo.upsertAll(records);

    return BootstrapResult(
      facilitiesSaved: records.length,
      boxesSaved: 0,
      baseUrl: baseUrl.isEmpty ? AppConfig.defaultBaseUrl : baseUrl,
    );
  }

  Future<BootstrapResult> syncDownBoxesForFacility(String facilityId) async {
    final baseUrl = await _settingsRepo.getBaseUrl();
    final api = ApiClient.create(baseUrl: baseUrl);
    final bootstrapApi = BootstrapApi(api);
    final boxes = await bootstrapApi.fetchBoxesForFacility(facilityId);

    final records = boxes.where((b) => b.boxUid.trim().isNotEmpty).map((b) {
      final r = BoxCache()
        ..boxUid = b.boxUid.trim()
        ..status = b.status
        ..currentFacilityId = b.currentFacilityId
        ..orderId = b.orderId
        ..productId = b.productId
        ..batchNo = b.batchNo
        ..expiryDate = b.expiryDate
        ..updatedAt = DateTime.now();
      return r;
    }).toList();

    // For now we replace the cache, but you can later merge by facility.
    await _boxRepo.clear();
    await _boxRepo.upsertAll(records);

    return BootstrapResult(
      facilitiesSaved: 0,
      boxesSaved: records.length,
      baseUrl: baseUrl.isEmpty ? AppConfig.defaultBaseUrl : baseUrl,
    );
  }
}
