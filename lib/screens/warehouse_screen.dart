import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/bootstrap/bootstrap_service.dart';
import '../core/sync/sync_service.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/warehouse_api.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/cache/box_cache_repo.dart';
import '../data/local/cache/facility_cache_repo.dart';
import '../data/local/isar/facility_cache.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../commodity/multi_scan_page.dart';
import 'dispatch_screen.dart';
import 'facility_receive_screen.dart';
import 'generate_boxes_screen.dart';
import 'queue_inspector_screen.dart';
import '../widgets/acf_brand.dart';

class WarehouseScreen extends StatefulWidget {
  const WarehouseScreen({super.key});

  @override
  State<WarehouseScreen> createState() => _WarehouseScreenState();
}

class _WarehouseScreenState extends State<WarehouseScreen> {
  final SessionStore _sessionStore = SessionStore();
  final TokenStore _tokenStore = const TokenStore();
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();

  final FacilityCacheRepo _facilityCacheRepo = FacilityCacheRepo();
  final BoxCacheRepo _boxCacheRepo = BoxCacheRepo();

  final BootstrapService _bootstrapService = BootstrapService();
  final SyncQueueRepo _queueRepo = SyncQueueRepo();
  final SyncService _syncService = SyncService();

  final Uuid _uuid = const Uuid();

  final Connectivity _connectivity = Connectivity();
  List<ConnectivityResult> _conn = const [ConnectivityResult.none];
  StreamSubscription? _connSub;

  bool _syncing = false;
  bool _loadingMe = true;
  Map<String, dynamic>? _me;

  bool _loadingSummary = false;
  WarehouseSummaryDto? _summary;
  String? _summaryError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await _loadMe();
    await _initConnectivity();
    await _refreshWarehouseSummary();
  }

  Future<void> _loadMe() async {
    final me = await _sessionStore.readUserJson();
    if (!mounted) return;
    setState(() {
      _me = me;
      _loadingMe = false;
    });
  }

  Future<void> _refreshWarehouseSummary() async {
    final role = (_me?['role'] ?? '').toString();
    if (role != 'WAREHOUSE_OFFICER' && role != 'SUPER_ADMIN') return;
    if (!_isOnline) return;

    setState(() {
      _loadingSummary = true;
      _summaryError = null;
    });

    try {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final warehouseApi = WarehouseApi(api);
      final s = await warehouseApi.fetchWarehouseSummary();
      if (!mounted) return;
      setState(() => _summary = s);
    } catch (e) {
      if (!mounted) return;
      setState(() => _summaryError = e.toString());
    } finally {
      if (mounted) setState(() => _loadingSummary = false);
    }
  }

  Future<void> _initConnectivity() async {
    final current = await _connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _conn = current);

    _connSub = _connectivity.onConnectivityChanged.listen((result) {
      if (!mounted) return;
      setState(() => _conn = result);

      final online = !result.contains(ConnectivityResult.none);
      if (online) {
        // Auto-sync when coming online.
        _syncNow(auto: true);
        _refreshWarehouseSummary();
      }
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  bool get _isOnline => !_conn.contains(ConnectivityResult.none);

  Future<void> _logout() async {
    await _tokenStore.clear();
    await _sessionStore.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _syncNow({bool auto = false}) async {
    if (_syncing) return;

    setState(() => _syncing = true);
    try {
      final result = await _syncService.syncNow();
      if (!mounted) return;

      if (!result.online) {
        if (!auto) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offline: nothing to sync')));
        }
        return;
      }

      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync done: sent ${result.sent}, failed ${result.failed} (attempted ${result.attempted})'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncDownFacilities() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are offline.')));
      return;
    }
    try {
      final res = await _bootstrapService.syncDownFacilities();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${res.facilitiesSaved} facilities from ${res.baseUrl}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Facility download failed: $e')),
      );
    }
  }

  Future<void> _syncDownBoxesForFacility() async {
    if (!_isOnline) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You are offline.')));
      return;
    }

    // Prefer a sensible default based on logged-in user.
    final defaultFacilityId = (_me?['role'] == 'WAREHOUSE_OFFICER')
        ? (_me?['warehouseId'] as String?)
        : (_me?['facilityId'] as String?);

    final facilityId = await _pickCachedFacility(context, defaultId: defaultFacilityId);
    if (facilityId == null || facilityId.trim().isEmpty) return;

    try {
      final res = await _bootstrapService.syncDownBoxesForFacility(facilityId.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloaded ${res.boxesSaved} boxes for facility')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Boxes download failed: $e')),
      );
    }
  }

  // Developer utility (kept for testing)
  Future<void> _enqueueDemoItem() async {
    final item = SyncQueueItem.build(
      queueId: _uuid.v4(),
      entityType: 'demo',
      localEntityId: _uuid.v4(),
      method: 'POST',
      endpoint: '/api/demo',
      operation: SyncOperation.create,
      payloadJson: jsonEncode({'hello': 'offline-first', 'createdAt': DateTime.now().toIso8601String()}),
      idempotencyKey: _uuid.v4(),
    );
    await _queueRepo.enqueue(item);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demo item queued')));
  }

  // Developer utility (kept for testing)
  Future<void> _scanAndQueueBoxes() async {
    final results = await Navigator.push<List<String>>(
      context,
      MaterialPageRoute(
        builder: (_) => const MultiScanPage(
          title: 'Scan Boxes (Demo)',
          expectedCount: 3,
          helperText: 'Scan 3 boxes. Each scan is queued as an offline transaction.',
        ),
      ),
    );

    if (results == null || results.isEmpty) return;

    for (final raw in results) {
      final parsed = _safeJson(raw);
      final boxUid = (parsed['boxUid'] as String?)?.trim();
      if (boxUid == null || boxUid.isEmpty) continue;

      final item = SyncQueueItem.build(
        queueId: _uuid.v4(),
        entityType: 'box_scan',
        localEntityId: boxUid,
        method: 'POST',
        endpoint: '/api/boxes/scan',
        operation: SyncOperation.create,
        payloadJson: jsonEncode({'boxUid': boxUid, 'raw': raw}),
        idempotencyKey: _uuid.v4(),
      );
      await _queueRepo.enqueue(item);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Queued ${results.length} scans')));
  }

  Map<String, dynamic> _safeJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
    } catch (_) {
      // ignore
    }
    return <String, dynamic>{};
  }

  Future<String?> _pickCachedFacility(BuildContext context, {String? defaultId}) async {
    final facilities = await _facilityCacheRepo.listAll();

    if (facilities.isEmpty) {
      if (!context.mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No cached facilities yet. Download facilities first.')),
      );
      return null;
    }

    FacilityCache? selected;
    if (defaultId != null) {
      for (final f in facilities) {
        if (f.facilityId == defaultId) {
          selected = f;
          break;
        }
      }
    }

    return showDialog<String>(
      context: context,
      builder: (ctx) {
        final searchCtrl = TextEditingController();
        var filtered = facilities;

        return StatefulBuilder(
          builder: (ctx, setState) {
            void applyFilter(String q) {
              final query = q.trim().toLowerCase();
              setState(() {
                if (query.isEmpty) {
                  filtered = facilities;
                } else {
                  filtered = facilities.where((f) {
                    final name = f.name.toLowerCase();
                    final code = (f.code ?? '').toLowerCase();
                    final id = f.facilityId.toLowerCase();
                    return name.contains(query) || code.contains(query) || id.contains(query);
                  }).toList();
                }
              });
            }

            return AlertDialog(
              title: const Text('Choose facility'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchCtrl,
                      onChanged: applyFilter,
                      decoration: const InputDecoration(
                        hintText: 'Search by name, code or id',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final f = filtered[i];
                          final isSelected = selected?.facilityId == f.facilityId;
                          return ListTile(
                            dense: true,
                            title: Text(f.name),
                            subtitle: Text((f.code ?? '').isEmpty ? f.facilityId : '${f.code} • ${f.facilityId}'),
                            trailing: isSelected ? const Icon(Icons.check_circle) : null,
                            onTap: () {
                              setState(() => selected = f);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                FilledButton(
                  onPressed: selected == null ? null : () => Navigator.pop(ctx, selected!.facilityId),
                  child: const Text('Use facility'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final me = _me;
    final role = (me?['role'] ?? '').toString();
    final name = (me?['name'] ?? me?['email'] ?? '').toString();
    final facilityName = (me?['facilityName'] ?? '').toString();

    final isWarehouseOfficer = role == 'WAREHOUSE_OFFICER';

    final canDispatch = role == 'WAREHOUSE_OFFICER' || role == 'SUPER_ADMIN';
    final canReceive = role == 'FACILITY_OFFICER' || role == 'CLINICIAN' || role == 'SUPER_ADMIN';

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Warehouse',
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(child: _OnlineChip(conn: _conn)),
          ),
          IconButton(
            tooltip: 'Sync queue',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueInspectorScreen())),
            icon: const Icon(Icons.sync),
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'logout') _logout();
              if (v == 'refresh') _loadMe();
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'refresh', child: Text('Refresh profile')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: _loadingMe
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadMe();
                await _refreshWarehouseSummary();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          const AcfLogo(size: 44),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name.isEmpty ? 'User' : name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 2),
                                Text(role.isEmpty ? 'Role not set' : role,
                                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                if (facilityName.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(facilityName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                ],
                              ],
                            ),
                          ),
                          Icon(Icons.verified_user, color: cs.primary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Warehouse officers operate online; show live stock first.
                  if (isWarehouseOfficer) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text('Warehouse stock',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                ),
                                IconButton(
                                  tooltip: 'Refresh',
                                  onPressed: _loadingSummary ? null : _refreshWarehouseSummary,
                                  icon: _loadingSummary
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Icon(Icons.refresh),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            if (!_isOnline)
                              Text('Offline: warehouse actions require internet.',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                            else if (_summaryError != null)
                              Text('Failed to load stock: $_summaryError',
                                  style: TextStyle(fontSize: 12, color: cs.error))
                            else ...[
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  _MetricPill(
                                    label: 'Boxes in warehouse',
                                    value: (_summary?.boxesInWarehouse ?? 0).toString(),
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                  _MetricPill(
                                    label: 'Sachets available',
                                    value: (_summary?.totalSachetsAvailable ?? 0).toString(),
                                    icon: Icons.medical_services_outlined,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'These values reduce immediately after dispatch (boxes move to IN_TRANSIT).',
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Sync queue is primarily for offline facility workflows.
                  // Warehouse officers are online-only, so we hide this section.
                  if (!isWarehouseOfficer) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: StreamBuilder<SyncQueueCounts>(
                          stream: _queueRepo.watchCounts(),
                          builder: (context, snapshot) {
                            final counts = snapshot.data ?? const SyncQueueCounts(pending: 0, failed: 0, sent: 0);
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text('Sync status',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: _syncing ? null : () => _syncNow(auto: false),
                                      icon: _syncing
                                          ? const SizedBox(
                                              width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                          : const Icon(Icons.cloud_upload),
                                      label: const Text('Sync now'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    _MetricPill(label: 'Pending', value: counts.pending.toString(), icon: Icons.schedule),
                                    _MetricPill(label: 'Failed', value: counts.failed.toString(), icon: Icons.error_outline),
                                    _MetricPill(label: 'Sent', value: counts.sent.toString(), icon: Icons.check_circle_outline),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  _isOnline
                                      ? 'Online: you can sync now (and we also auto-sync when connectivity returns).'
                                      : 'Offline: capture data normally. Everything is saved locally and will sync later.',
                                  style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Offline cache is not needed for warehouse officers (online-only).
                  if (!isWarehouseOfficer) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Offline cache',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(
                              'Download reference data so warehouse/facility actions can work offline.',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                StreamBuilder<int>(
                                  stream: _facilityCacheRepo.watchCount(),
                                  builder: (context, snapshot) => _MetricPill(
                                    label: 'Facilities cached',
                                    value: (snapshot.data ?? 0).toString(),
                                    icon: Icons.apartment,
                                  ),
                                ),
                                StreamBuilder<int>(
                                  stream: _boxCacheRepo.watchCount(),
                                  builder: (context, snapshot) => _MetricPill(
                                    label: 'Boxes cached',
                                    value: (snapshot.data ?? 0).toString(),
                                    icon: Icons.inventory_2_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonalIcon(
                              onPressed: _syncDownFacilities,
                              icon: const Icon(Icons.download),
                              label: const Text('Download facilities'),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.tonalIcon(
                              onPressed: _syncDownBoxesForFacility,
                              icon: const Icon(Icons.download_for_offline_outlined),
                              label: const Text('Download boxes (by facility)'),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tip: this uses cached facilities list. If the list is empty, download facilities first.',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('LMIS transactions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 6),
                          Text(
                            isWarehouseOfficer
                                ? 'Warehouse is online: generate QR labels, dispatch shipments, and print the waybill immediately.'
                                : 'Use cached facilities + offline scanning to queue movements. Sync later to the backend.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              if (isWarehouseOfficer)
                                _ActionCard(
                                  title: 'Generate boxes',
                                  subtitle: 'Create QR codes + print A3 labels',
                                  icon: Icons.qr_code_2,
                                  enabled: _isOnline,
                                  onTap: () async {
                                    final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(builder: (_) => const GenerateBoxesScreen()),
                                    );
                                    if (changed == true) {
                                      _refreshWarehouseSummary();
                                    }
                                  },
                                ),
                              _ActionCard(
                                title: 'Dispatch',
                                subtitle: 'Warehouse → Facility',
                                icon: Icons.local_shipping_outlined,
                                enabled: canDispatch,
                                onTap: () async {
                                  final changed = await Navigator.push<bool>(
                                    context,
                                    MaterialPageRoute(builder: (_) => const DispatchScreen()),
                                  );
                                  if (changed == true) {
                                    _refreshWarehouseSummary();
                                  }
                                },
                              ),
                              if (!isWarehouseOfficer)
                                _ActionCard(
                                  title: 'Receive',
                                  subtitle: 'Facility receives shipment',
                                  icon: Icons.inventory_2_outlined,
                                  enabled: canReceive,
                                  onTap: () =>
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => const FacilityReceiveScreen())),
                                ),
                              _ActionCard(
                                title: 'Queue',
                                subtitle: 'Pending/failed/sent',
                                icon: Icons.list_alt,
                                enabled: !isWarehouseOfficer,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueInspectorScreen())),
                              ),
                            ],
                          ),
                          if (!canDispatch || !canReceive) ...[
                            const SizedBox(height: 10),
                            Text(
                              'Some actions are disabled based on your role ($role).',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (!isWarehouseOfficer) ...[
                    Card(
                      child: ExpansionTile(
                        title: const Text('Developer tools', style: TextStyle(fontWeight: FontWeight.w900)),
                        subtitle:
                            Text('Optional demo actions for testing', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                FilledButton.tonalIcon(
                                  onPressed: _enqueueDemoItem,
                                  icon: const Icon(Icons.add),
                                  label: const Text('Add demo queue item'),
                                ),
                                const SizedBox(height: 10),
                                FilledButton.tonalIcon(
                                  onPressed: _scanAndQueueBoxes,
                                  icon: const Icon(Icons.qr_code_scanner),
                                  label: const Text('Scan 3 boxes (demo) → queue'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'Tip: Even offline, you can continue working. Actions are saved locally and synced later.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _OnlineChip extends StatelessWidget {
  final List<ConnectivityResult> conn;

  const _OnlineChip({required this.conn});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final online = !conn.contains(ConnectivityResult.none);

    final bg = online ? cs.secondaryContainer : cs.surfaceVariant;
    final fg = online ? cs.onSecondaryContainer : cs.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(online ? Icons.wifi : Icons.wifi_off, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(
            online ? 'Online' : 'Offline',
            style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceVariant,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
          ),
          Text(
            value,
            style: TextStyle(fontSize: 12, color: cs.onSurface, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 170,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: enabled ? cs.surfaceVariant : cs.surfaceVariant.withOpacity(0.45),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: enabled ? cs.primary : cs.onSurfaceVariant),
                const Spacer(),
                Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w900, color: enabled ? cs.onSurface : cs.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
