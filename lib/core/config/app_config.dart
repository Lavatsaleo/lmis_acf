/// Central place for defaults.
///
/// In Step 2/3 we keep this intentionally simple. You can later move this to a
/// remote config or environment-specific flavors.
class AppConfig {
  /// Default backend base URL.
  ///
  /// - Android emulator talks to host via 10.0.2.2
  /// - Real phone should use your LAN IP (e.g. http://192.168.1.10:8080)
  static const String defaultBaseUrl = 'http://10.0.2.2:8080';

  /// Optional login endpoint (you can change later to match your backend).
  static const String defaultLoginPath = '/api/auth/login';

  /// Facilities list endpoint used by the mobile app to cache facilities.
  ///
  /// Update this to match your backend routing.
  static const String facilitiesPath = '/api/facilities';

  /// Boxes list endpoint used to optionally cache boxes.
  ///
  /// Recommended shape: GET /api/boxes?facilityId=<id>
  static const String boxesPath = '/api/boxes';

  /// Dispatch transaction endpoint.
  ///
  /// Recommended shape: POST /api/boxes/dispatch
  static const String dispatchPath = '/api/boxes/dispatch';

  /// Facility receive transaction endpoint.
  ///
  /// Recommended shape: POST /api/boxes/facility-receive
  static const String facilityReceivePath = '/api/boxes/facility-receive';

  /// Shipments (manifests/waybills)
  ///
  /// Recommended:
  /// - GET /api/shipments?status=DISPATCHED
  /// - GET /api/shipments/:id
  static const String shipmentsPath = '/api/shipments';

  /// Facility store summary (server-side truth)
  /// GET /api/boxes/store/summary
  static const String facilityStoreSummaryPath = '/api/boxes/store/summary';

  /// Warehouse live stock summary (online).
  ///
  /// Backend: GET /api/boxes/warehouse/summary
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

