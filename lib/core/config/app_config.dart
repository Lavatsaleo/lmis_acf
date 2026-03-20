/// Central place for defaults.
///
/// The mobile app now uses a single built-in backend endpoint.
/// End users can no longer change it from the UI.
class AppConfig {
  /// Built-in backend base URL.
  ///
  /// Replace this with your production HTTPS endpoint once before building.
  static const String defaultBaseUrl = 'https://aahdms.actionagainsthunger.org/lmisbackend/';

  /// Optional login endpoint (you can change later to match your backend).
  static const String defaultLoginPath = '/api/auth/login';

  /// Facilities list endpoint used by the mobile app to cache facilities.
  static const String facilitiesPath = '/api/facilities';

  /// Boxes list endpoint used to optionally cache boxes.
  static const String boxesPath = '/api/boxes';

  /// Dispatch transaction endpoint.
  static const String dispatchPath = '/api/boxes/dispatch';

  /// Facility receive transaction endpoint.
  static const String facilityReceivePath = '/api/boxes/facility-receive';

  /// Shipments (manifests/waybills)
  static const String shipmentsPath = '/api/shipments';

  /// Facility store summary (server-side truth)
  static const String facilityStoreSummaryPath = '/api/boxes/store/summary';

  /// Warehouse live stock summary (online).
  static const String warehouseSummaryPath = '/api/boxes/warehouse/summary';

  /// Orders endpoints used by warehouse officers (online).
  static const String ordersPath = '/api/orders';

  /// Max number of retries before an item stays FAILED until manual retry.
  static const int maxSyncAttempts = 8;

  /// Security: after a successful sync, purge sensitive form payloads from the local DB.
  ///
  /// We keep only minimal fields needed for follow-up (anthropometry + next appointment).
  static const bool purgeSensitiveAfterSync = true;
}
