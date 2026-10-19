import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../core/bootstrap/bootstrap_service.dart';
import '../core/access/user_access.dart';
import '../core/sync/sync_service.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/cache/box_cache_repo.dart';
import '../data/local/cache/facility_cache_repo.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';

/// Sync: what this phone has saved, what is waiting to go to the server, and
/// offline data for working without internet. Written for field staff:
/// records are described in plain words; technical details are one tap away.
class QueueInspectorScreen extends StatefulWidget {
  const QueueInspectorScreen({super.key});

  @override
  State<QueueInspectorScreen> createState() => _QueueInspectorScreenState();
}

class _QueueInspectorScreenState extends State<QueueInspectorScreen> {
  final SyncQueueRepo _repo = SyncQueueRepo();
  final SyncService _syncService = SyncService();
  final SessionStore _sessionStore = SessionStore();
  final BootstrapService _bootstrap = BootstrapService();
  final FacilityCacheRepo _facilityCache = FacilityCacheRepo();
  final BoxCacheRepo _boxCache = BoxCacheRepo();
  final Connectivity _connectivity = Connectivity();

  bool _syncing = false;
  bool _downloading = false;
  UserAccess? _access;
  List<ConnectivityResult> _conn = const [ConnectivityResult.wifi];
  StreamSubscription? _connSub;

  @override
  void initState() {
    super.initState();
    _sessionStore.readUserJson().then((me) {
      if (mounted) setState(() => _access = UserAccess.fromUserJson(me));
    });
    _connectivity.checkConnectivity().then((c) {
      if (mounted) setState(() => _conn = c);
    });
    _connSub = _connectivity.onConnectivityChanged.listen((c) {
      if (mounted) setState(() => _conn = c);
    });
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  bool get _online => _conn.isNotEmpty && !_conn.contains(ConnectivityResult.none);

  void _show(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _syncNow() async {
    if (_syncing) return;
    setState(() => _syncing = true);
    try {
      final r = await _syncService.forceSyncNow();
      if (!mounted) return;
      if (!r.online) {
        _show('You are offline. Records stay on this phone and sync when you are back online.');
      } else if (r.failed > 0) {
        _show('Sent ${r.sent}. ${r.failed} could not sync; see the list below.');
      } else {
        _show(r.sent > 0 ? 'All done: ${r.sent} record(s) sent, latest data downloaded.' : 'Up to date. Latest data downloaded.');
      }
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _retryFailed() async {
    await _repo.retryAllFailed();
    if (!mounted) return;
    _show('Failed records will be tried again.');
    _syncNow();
  }

  /// Facilities list and this facility's boxes, for scanning without internet.
  Future<void> _downloadOfflineData() async {
    final facilityId = _access?.facilityId ?? '';
    if (!_online) return _show('Connect to the internet to download offline data.');
    setState(() => _downloading = true);
    try {
      final f = await _bootstrap.syncDownFacilities();
      var boxes = 0;
      if (facilityId.isNotEmpty) boxes = (await _bootstrap.syncDownBoxesForFacility(facilityId)).boxesSaved;
      if (!mounted) return;
      _show('Downloaded ${f.facilitiesSaved} locations and $boxes boxes for offline use.');
    } catch (e) {
      if (mounted) _show('Download failed. Check your connection and try again.');
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AnchorAppBar(
        title: 'Sync',
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: Center(child: AnchorConnectionChip(conn: _conn)))],
      ),
      body: StreamBuilder<List<SyncQueueItem>>(
        stream: _repo.watchLatest(limit: 200),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <SyncQueueItem>[];
          final waiting = items.where((i) => i.status == SyncStatus.pending || i.status == SyncStatus.sending).length;
          final failed = items.where((i) => i.status == SyncStatus.failed).length;
          final sent = items.where((i) => i.status == SyncStatus.sent).length;

          return RefreshIndicator(
            onRefresh: _syncNow,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          failed > 0
                              ? 'Some records need attention'
                              : waiting > 0
                                  ? 'Waiting to sync'
                                  : 'Everything is synced',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Work saved on this phone is sent automatically when there is internet. You can also sync now.',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(child: AnchorStat(label: 'Waiting', value: '$waiting', icon: Icons.schedule)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: AnchorStat(
                                label: 'Not synced',
                                value: '$failed',
                                icon: Icons.error_outline,
                                color: failed > 0 ? cs.error : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: AnchorStat(label: 'Sent', value: '$sent', icon: Icons.check_circle_outline, color: const Color(0xFF1B7F4B))),
                          ],
                        ),
                        const SizedBox(height: 14),
                        FilledButton.icon(
                          onPressed: _syncing ? null : _syncNow,
                          icon: _syncing
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.sync),
                          label: Text(_syncing ? 'Syncing…' : 'Sync now'),
                        ),
                        if (failed > 0) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(onPressed: _syncing ? null : _retryFailed, icon: const Icon(Icons.refresh), label: const Text('Try failed records again')),
                        ],
                      ],
                    ),
                  ),
                ),
                if (_access?.canFacilityStore == true) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Offline data', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            'Download the locations list and your facility\'s boxes so scans can be checked without internet.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: _facilityCache.watchCount(),
                                  builder: (_, s) => AnchorStat(label: 'Locations', value: '${s.data ?? 0}', icon: Icons.place_outlined),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: StreamBuilder<int>(
                                  stream: _boxCache.watchCount(),
                                  builder: (_, s) => AnchorStat(label: 'Boxes', value: '${s.data ?? 0}', icon: Icons.inventory_2_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _downloading ? null : _downloadOfflineData,
                            icon: _downloading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download_for_offline_outlined),
                            label: Text(_downloading ? 'Downloading…' : 'Download offline data'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                AnchorSectionTitle('Recent records', subtitle: items.isEmpty ? null : 'Tap a record for details'),
                if (!snapshot.hasData)
                  const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text('Nothing saved on this phone yet.', textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < items.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _RecordRow(item: items[i], repo: _repo),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------

String _recordTitle(SyncQueueItem it) {
  switch (it.entityType) {
    case 'receive':
      return 'Shipment received';
    case 'clinical_enroll':
      return 'Child enrolled';
    case 'clinical_followup':
      return 'Follow-up visit';
    case 'clinical_visit_update':
      return 'Visit corrected';
    case 'clinical_child_update':
      return 'Child details updated';
    case 'clinical_discharge':
      return 'Child discharged';
    default:
      return it.entityType.replaceAll('_', ' ');
  }
}

String _when(DateTime d) {
  final now = DateTime.now();
  final local = d.toLocal();
  final diff = now.difference(local);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24 && now.day == local.day) return 'today ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '${local.day}/${local.month}/${local.year}';
}

/// Plain explanation for a failed record.
String _problem(SyncQueueItem it) {
  final e = (it.lastError ?? '').trim();
  final upper = e.toUpperCase();
  if (upper.startsWith('LOGIN_REQUIRED:')) return 'Sign in again to send this record.';
  if (upper.startsWith('NEEDS_REVIEW:')) return 'The server did not accept this record: ${e.substring(13).trim()}';
  if (it.httpStatus == null) return 'No connection to the server. It will be tried again.';
  return e.isEmpty ? 'The server returned an error. It will be tried again.' : e;
}

class _RecordRow extends StatelessWidget {
  final SyncQueueItem item;
  final SyncQueueRepo repo;

  const _RecordRow({required this.item, required this.repo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final needsReview = repo.isNeedsReview(item);
    final (label, color, icon) = switch (item.status) {
      SyncStatus.sent => ('Sent', const Color(0xFF1B7F4B), Icons.check_circle),
      SyncStatus.sending => ('Sending', cs.primary, Icons.sync),
      SyncStatus.pending => ('Waiting', cs.onSurfaceVariant, Icons.schedule),
      SyncStatus.failed => (needsReview ? 'Needs review' : 'Not synced', cs.error, Icons.error),
    };
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(_recordTitle(item), style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(
        item.status == SyncStatus.failed ? _problem(item) : 'Saved ${_when(item.createdAt)}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12, color: item.status == SyncStatus.failed ? cs.error : cs.onSurfaceVariant),
      ),
      trailing: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
      onTap: () => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _RecordDetails(item: item),
      ),
    );
  }
}

class _RecordDetails extends StatelessWidget {
  final SyncQueueItem item;

  const _RecordDetails({required this.item});

  String _pretty(String? raw) {
    if (raw == null || raw.trim().isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(jsonDecode(raw));
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          Text(_recordTitle(item), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('Saved ${_when(item.createdAt)} · ${item.attempts} attempt(s)', style: TextStyle(color: cs.onSurfaceVariant)),
          if (item.status == SyncStatus.failed) ...[
            const SizedBox(height: 12),
            AnchorNotice(_problem(item), icon: Icons.error_outline, warning: true),
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Technical details', style: TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('For support staff', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            children: [
              _Mono('Request', '${item.method} ${item.endpoint}\nRecord: ${item.localEntityId}\nQueue id: ${item.queueId}'
                  '${item.httpStatus != null ? '\nHTTP ${item.httpStatus}' : ''}${item.sentAt != null ? '\nSent ${item.sentAt}' : ''}'),
              _Mono('Data', _pretty(item.payloadJson)),
              if ((item.responseJson ?? '').trim().isNotEmpty) _Mono('Server response', _pretty(item.responseJson)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Mono extends StatelessWidget {
  final String title;
  final String text;

  const _Mono(this.title, this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Theme.of(context).colorScheme.outlineVariant)),
            child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
