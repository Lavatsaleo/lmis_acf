import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/access/user_access.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/warehouse_api.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';
import 'box_lookup_screen.dart';
import 'clinical_home_screen.dart';
import 'dispatch_screen.dart';
import 'facility_receive_screen.dart';
import 'facility_store_screen.dart';
import 'generate_boxes_screen.dart';
import 'receive_po_screen.dart';
import 'stock_control_screens.dart';

/// Home: the user's own tasks, grouped by area.
///
/// Only what this user's role can do is shown (see [UserAccess]); there are no
/// greyed-out buttons. Warehouse work is online; facility and clinical work
/// can be captured offline and synced later.
class HomeScreen extends StatefulWidget {
  /// Opens the Sync tab (offline users).
  final VoidCallback? onOpenSync;

  const HomeScreen({super.key, this.onOpenSync});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SessionStore _sessionStore = SessionStore();
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final SyncQueueRepo _queueRepo = SyncQueueRepo();
  final Connectivity _connectivity = Connectivity();

  bool _loading = true;
  UserAccess? _access;
  List<ConnectivityResult> _conn = const [ConnectivityResult.wifi];
  StreamSubscription? _connSub;

  bool _loadingStock = false;
  WarehouseSummaryDto? _stock;
  String? _stockError;

  bool get _online => _conn.isNotEmpty && !_conn.contains(ConnectivityResult.none);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _conn = await _connectivity.checkConnectivity();
    _connSub = _connectivity.onConnectivityChanged.listen((c) {
      if (!mounted) return;
      final wasOffline = !_online;
      setState(() => _conn = c);
      if (wasOffline && _online) _loadStock();
    });
    await _load();
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    if (!mounted) return;
    setState(() {
      _access = UserAccess.fromUserJson(me);
      _loading = false;
    });
    await _loadStock();
  }

  Future<void> _loadStock() async {
    final a = _access;
    if (a == null || !(a.canWarehouse || a.canReceiveTransfer) || !_online) return;
    setState(() {
      _loadingStock = true;
      _stockError = null;
    });
    try {
      final api = ApiClient.create(baseUrl: await _settingsRepo.getBaseUrl());
      final s = await WarehouseApi(api).fetchWarehouseSummary();
      if (mounted) setState(() => _stock = s);
    } catch (_) {
      if (mounted) setState(() => _stockError = 'Could not load stock. Pull down to try again.');
    } finally {
      if (mounted) setState(() => _loadingStock = false);
    }
  }

  /// Opens a task and refreshes the stock figures when it comes back.
  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _loadStock();
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _access == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final a = _access!;
    final cs = Theme.of(context).colorScheme;

    final warehouseTasks = <AnchorTask>[
      if (a.canReceivePurchaseOrder)
        AnchorTask(
          title: 'Receive delivery',
          subtitle: 'Supplier delivery against a purchase order',
          icon: Icons.receipt_long_outlined,
          needsInternet: true,
          onTap: () => _open(const ReceivePoListScreen()),
        ),
      if (a.canReceiveTransfer)
        AnchorTask(
          title: 'Receive transfer',
          subtitle: 'Boxes sent from the main warehouse',
          icon: Icons.move_to_inbox_outlined,
          needsInternet: true,
          onTap: () => _open(const FacilityReceiveScreen()),
        ),
      if (a.canDispatch)
        AnchorTask(
          title: 'Dispatch',
          subtitle: a.isFieldBase ? 'Send boxes to a site' : 'Send boxes to a facility or base',
          icon: Icons.local_shipping_outlined,
          needsInternet: true,
          onTap: () => _open(const DispatchScreen()),
        ),
      if (a.canStockCount)
        AnchorTask(
          title: 'Stock count',
          subtitle: 'Count cartons and compare',
          icon: Icons.fact_check_outlined,
          needsInternet: true,
          onTap: () => _open(const StockCountScreen()),
        ),
      if (a.canReportLoss)
        AnchorTask(
          title: 'Report loss',
          subtitle: 'Damaged, expired or missing',
          icon: Icons.report_gmailerrorred_outlined,
          needsInternet: true,
          onTap: () => _open(const ReportLossScreen()),
        ),
      if (a.canGenerateLabels)
        AnchorTask(
          title: 'Make QR labels',
          subtitle: 'For stock without a purchase order',
          icon: Icons.qr_code_2,
          needsInternet: true,
          onTap: () => _open(const GenerateBoxesScreen()),
        ),
    ];

    final facilityTasks = <AnchorTask>[
      if (a.canReceiveShipment)
        AnchorTask(
          title: 'Receive shipment',
          subtitle: 'Scan boxes delivered to this facility',
          icon: Icons.move_to_inbox_outlined,
          onTap: () => _open(const FacilityReceiveScreen()),
        ),
      if (a.canFacilityStore)
        AnchorTask(
          title: 'Store',
          subtitle: 'Boxes and sachets in this facility',
          icon: Icons.storefront_outlined,
          onTap: () => _open(const FacilityStoreScreen()),
        ),
    ];

    final clinicalTasks = <AnchorTask>[
      if (a.canClinical)
        AnchorTask(
          title: 'Children & visits',
          subtitle: 'Enrol, follow up, dispense',
          icon: Icons.child_care_outlined,
          onTap: () => _open(const ClinicalHomeScreen()),
        ),
    ];

    final toolTasks = <AnchorTask>[
      if (a.canBoxLookup)
        AnchorTask(
          title: 'Find a box',
          subtitle: 'Scan a QR to see where it is',
          icon: Icons.manage_search,
          onTap: () => _open(const BoxLookupScreen()),
        ),
    ];

    return Scaffold(
      appBar: const AnchorAppBar(title: 'Anchor'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Greeting(greeting: _greeting, access: a, conn: _conn),
            if (a.usesOfflineQueue) _PendingSyncBanner(repo: _queueRepo, onOpen: widget.onOpenSync),
            if (!a.hasMobileTasks) ...[
              const SizedBox(height: 16),
              AnchorNotice(
                a.isViewer
                    ? 'Your account can view information only. Reports and stock are on the Anchor web dashboard; here you can look up boxes.'
                    : 'As ${a.roleLabel.toLowerCase()}, you manage Anchor from the web dashboard. Here you can look up boxes.',
              ),
            ],
            if (warehouseTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              AnchorSectionTitle(
                a.isFieldBase ? 'Field base' : 'Warehouse',
                subtitle: 'Needs internet',
              ),
              _StockCard(loading: _loadingStock, stock: _stock, error: _stockError, online: _online, onRefresh: _loadStock),
              const SizedBox(height: 12),
              AnchorTaskGrid(tasks: warehouseTasks, online: _online),
            ],
            if (facilityTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const AnchorSectionTitle('Facility store', subtitle: 'Works offline, syncs later'),
              AnchorTaskGrid(tasks: facilityTasks, online: _online),
            ],
            if (clinicalTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const AnchorSectionTitle('Clinical', subtitle: 'Works offline, syncs later'),
              AnchorTaskGrid(tasks: clinicalTasks, online: _online),
            ],
            if (toolTasks.isNotEmpty) ...[
              const SizedBox(height: 12),
              const AnchorSectionTitle('Tools'),
              AnchorTaskGrid(tasks: toolTasks, online: _online),
            ],
            if (!a.hasMobileTasks && !a.canBoxLookup) ...[
              const SizedBox(height: 16),
              Text('Nothing to do on the phone for this account.', style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  final String greeting;
  final UserAccess access;
  final List<ConnectivityResult> conn;

  const _Greeting({required this.greeting, required this.access, required this.conn});

  @override
  Widget build(BuildContext context) {
    final a = access;
    final place = a.locationName.isNotEmpty ? a.locationName : a.platform.countryName;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: anchorGradient, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$greeting, ${a.firstName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                ),
              ),
              AnchorConnectionChip(conn: conn, onDark: true),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Tag(icon: Icons.badge_outlined, text: a.roleLabel),
              if (place.isNotEmpty) _Tag(icon: Icons.place_outlined, text: place),
              if (a.locationName.isNotEmpty && a.platform.countryName.isNotEmpty) _Tag(icon: Icons.flag_outlined, text: a.platform.countryName),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _StockCard extends StatelessWidget {
  final bool loading;
  final WarehouseSummaryDto? stock;
  final String? error;
  final bool online;
  final VoidCallback onRefresh;

  const _StockCard({required this.loading, required this.stock, required this.error, required this.online, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget body;
    if (!online) {
      body = const AnchorNotice('You are offline. Warehouse tasks and stock figures need internet.', icon: Icons.wifi_off, warning: true);
    } else if (error != null) {
      body = Text(error!, style: TextStyle(color: cs.error, fontSize: 13));
    } else {
      body = Row(
        children: [
          Expanded(
            child: AnchorStat(label: 'Boxes in stock', value: stock == null ? '—' : formatCount(stock!.boxesInWarehouse), icon: Icons.inventory_2_outlined),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnchorStat(label: 'Sachets', value: stock == null ? '—' : formatCount(stock!.totalSachetsAvailable), icon: Icons.grain),
          ),
        ],
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 6, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Stock on hand', style: TextStyle(fontWeight: FontWeight.w900))),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: loading || !online ? null : onRefresh,
                  icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                ),
              ],
            ),
            Padding(padding: const EdgeInsets.only(right: 8), child: body),
          ],
        ),
      ),
    );
  }
}

/// Shown on Home only when something is waiting to sync.
class _PendingSyncBanner extends StatelessWidget {
  final SyncQueueRepo repo;
  final VoidCallback? onOpen;

  const _PendingSyncBanner({required this.repo, this.onOpen});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SyncQueueCounts>(
      stream: repo.watchCounts(),
      builder: (context, snap) {
        final c = snap.data;
        if (c == null || (c.pending == 0 && c.failed == 0)) return const SizedBox.shrink();
        final text = c.failed > 0
            ? '${c.failed} record(s) could not sync. Tap to see why.'
            : '${c.pending} record(s) saved on this phone, waiting to sync.';
        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onOpen,
            child: AnchorNotice(text, icon: c.failed > 0 ? Icons.error_outline : Icons.cloud_upload_outlined, warning: c.failed > 0),
          ),
        );
      },
    );
  }
}
