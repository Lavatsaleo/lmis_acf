import '../platform/platform_context.dart';

/// What the signed-in user may see and do in the app.
///
/// One place decides access, so every screen agrees: a task a user cannot do
/// is not shown at all (rather than shown greyed out). The backend still
/// enforces the same rules; this only shapes the interface.
///
/// The implementation (country/programme) decides which modules exist; the
/// role decides what this user does inside them.
class UserAccess {
  final String role;
  final String fullName;
  final String email;
  final String locationName;
  final String locationType; // stockLocationType, e.g. FIELD_BASE_WAREHOUSE
  final String facilityType; // WAREHOUSE / FACILITY
  final String facilityId;
  final PlatformContext platform;

  const UserAccess({
    required this.role,
    required this.fullName,
    required this.email,
    required this.locationName,
    required this.locationType,
    required this.facilityType,
    required this.facilityId,
    required this.platform,
  });

  factory UserAccess.fromUserJson(Map<String, dynamic>? me) {
    String s(dynamic v) => (v ?? '').toString().trim();
    final facility = me?['facility'];
    final f = facility is Map ? facility : const {};
    return UserAccess(
      role: s(me?['role']).toUpperCase(),
      fullName: s(me?['fullName'] ?? me?['name']),
      email: s(me?['email']),
      locationName: s(f['name'] ?? me?['facilityName']),
      locationType: s(f['stockLocationType']),
      facilityType: s(me?['facilityType']),
      facilityId: s(me?['facilityId']),
      platform: PlatformContext.fromUserJson(me),
    );
  }

  bool get isSuperAdmin => role == 'SUPER_ADMIN';
  bool get isCountryAdmin => role == 'COUNTRY_ADMIN';
  bool get isWarehouseOfficer => role == 'WAREHOUSE_OFFICER';
  bool get isFacilityOfficer => role == 'FACILITY_OFFICER';
  bool get isClinician => role == 'CLINICIAN';
  bool get isViewer => role == 'VIEWER';

  bool get _logistics => platform.isModuleEnabled('LOGISTICS') || platform.isModuleEnabled('PHARMACY');
  bool get _clinical => platform.isModuleEnabled('CLINICAL');

  /// Field bases (South Sudan) receive transfers from the main warehouse.
  bool get isFieldBase => locationType == 'FIELD_BASE_WAREHOUSE';

  // ---- Warehouse ---------------------------------------------------------
  bool get canWarehouse => _logistics && (isWarehouseOfficer || isSuperAdmin);
  // Stock-control tools are switched on per country (dashboard: QR Labels
  // page). Kenya keeps its current app until it opts in.
  bool get canReceivePurchaseOrder => canWarehouse && platform.warehouseTools;
  bool get canStockCount => canWarehouse && platform.warehouseTools;
  bool get canReportLoss => canWarehouse && platform.warehouseTools;
  bool get canGenerateLabels => canWarehouse;
  bool get canDispatch => canWarehouse;
  bool get canReceiveTransfer => _logistics && isWarehouseOfficer && isFieldBase;

  // ---- Facility store ----------------------------------------------------
  bool get canFacilityStore => _logistics && (isFacilityOfficer || isClinician || isSuperAdmin);
  bool get canReceiveShipment => canFacilityStore;

  // ---- Clinical ----------------------------------------------------------
  bool get canClinical => _clinical && (isClinician || isSuperAdmin);

  // ---- Shared ------------------------------------------------------------
  bool get canBoxLookup => _logistics;

  /// Facility and clinical work is captured offline and synced later;
  /// warehouse work happens online, so warehouse officers have no queue.
  bool get usesOfflineQueue => canFacilityStore || canClinical;

  /// Nothing to do on the phone (admins and viewers work on the dashboard).
  bool get hasMobileTasks => canWarehouse || canReceiveTransfer || canFacilityStore || canClinical;

  String get roleLabel => roleLabelFor(role);

  String get firstName {
    final n = fullName.isNotEmpty ? fullName : email.split('@').first;
    return n.split(RegExp(r'\s+')).first;
  }

  static String roleLabelFor(String role) {
    switch (role.toUpperCase()) {
      case 'SUPER_ADMIN':
        return 'Super admin';
      case 'COUNTRY_ADMIN':
        return 'Country admin';
      case 'WAREHOUSE_OFFICER':
        return 'Warehouse officer';
      case 'FACILITY_OFFICER':
        return 'Facility officer';
      case 'CLINICIAN':
        return 'Clinician';
      case 'VIEWER':
        return 'Viewer';
      default:
        return role.isEmpty ? 'No role' : role;
    }
  }
}
