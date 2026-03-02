import 'package:flutter/material.dart';

import '../data/local/auth/session_store.dart';
import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_child.dart';
import 'clinical_register_child_screen.dart';
import 'clinical_child_detail_screen.dart';
import 'clinical_find_child_screen.dart';
import 'clinical_appointments_screen.dart';
import 'queue_inspector_screen.dart';
import '../widgets/acf_brand.dart';
import '../widgets/acf_tiles.dart';
import '../core/sync/sync_service.dart';

class ClinicalHomeScreen extends StatefulWidget {
  const ClinicalHomeScreen({super.key});

  @override
  State<ClinicalHomeScreen> createState() => _ClinicalHomeScreenState();
}

class _ClinicalHomeScreenState extends State<ClinicalHomeScreen> {
  final SessionStore _session = SessionStore();
  final ClinicalChildRepo _childRepo = ClinicalChildRepo();
  final ClinicalAssessmentRepo _assessRepo = ClinicalAssessmentRepo();
  final SyncService _syncService = SyncService();

  Map<String, dynamic>? _user;
  String? _role;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    // SessionStore persists the user profile as JSON.
    final user = await _session.readUserJson();
    if (!mounted) return;
    setState(() {
      _user = user;
      _role = (user?['role'] ?? '').toString().toUpperCase();
      _loading = false;
    });
  }

  bool get _canUseClinical {
    final r = _role ?? '';
    return r == 'CLINICIAN' || r == 'SUPER_ADMIN';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Clinical',
        actions: [
          IconButton(
            tooltip: 'Sync now',
            icon: const Icon(Icons.sync),
            onPressed: () async {
              final result = await _syncService.syncNow();
              if (!context.mounted) return;
              final msg = result.online
                  ? 'Sync done: sent ${result.sent}, failed ${result.failed}.'
                  : 'Offline: nothing to sync.';
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
            },
          ),
          IconButton(
            tooltip: 'Sync queue',
            icon: const Icon(Icons.list_alt),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueInspectorScreen()));
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TopCard(
              role: _role ?? '-',
              facilityName: (_user?['facilityName'] ?? _user?['facility']?['name'] ?? '').toString(),
              canUseClinical: _canUseClinical,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: AcfActionTile(
                    title: 'Register child',
                    subtitle: 'Enroll + in-depth assessment (offline-first)',
                    icon: Icons.person_add_alt_1,
                    enabled: _canUseClinical,
                    onTap: () {
                      if (!_canUseClinical) {
                        _showNoAccess();
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClinicalRegisterChildScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AcfActionTile(
                    title: 'Find child',
                    subtitle: 'Search local cache',
                    icon: Icons.search,
                    enabled: _canUseClinical,
                    onTap: () {
                      if (!_canUseClinical) {
                        _showNoAccess();
                        return;
                      }
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ClinicalFindChildScreen()));
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            AcfActionTile(
              title: 'Appointments diary',
              subtitle: 'See expected appointments for today & next 7 days',
              icon: Icons.event_note,
              enabled: _canUseClinical,
              onTap: () {
                if (!_canUseClinical) {
                  _showNoAccess();
                  return;
                }
                Navigator.push(context, MaterialPageRoute(builder: (_) => const ClinicalAppointmentsScreen()));
              },
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FutureBuilder<int>(
                    future: _childRepo.countDraftOrQueued(),
                    builder: (context, snap) {
                      final v = snap.data ?? 0;
                      return _StatPill(label: 'Local children', value: '$v');
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FutureBuilder<int>(
                    future: _assessRepo.countDraftOrQueued(),
                    builder: (context, snap) {
                      final v = snap.data ?? 0;
                      return _StatPill(label: 'Local assessments', value: '$v');
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Text('Recent local enrollments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),

            Expanded(
              child: StreamBuilder<List<ClinicalChild>>(
                stream: _childRepo.watchAll(limit: 50),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <ClinicalChild>[];

                  if (items.isEmpty) {
                    return _EmptyState(
                      title: 'No local enrollments yet',
                      subtitle: _canUseClinical
                          ? 'Tap “Register child” to start an enrollment (works offline).'
                          : 'You are logged in, but your account does not have clinical permissions.',
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final c = items[i];
                      final subtitle = [
                        if ((c.cwcNumber ?? '').isNotEmpty) 'CWC: ${c.cwcNumber}',
                        if (c.dateOfBirth != null) 'DOB: ${_fmtDate(c.dateOfBirth!)}',
                        'Status: ${c.status}',
                      ].join(' • ');

                      return ListTile(
                        tileColor: Theme.of(context).colorScheme.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('${c.firstName} ${c.lastName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(subtitle),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClinicalChildDetailScreen(localChildId: c.localChildId),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoAccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('This account does not have clinical permissions.')),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _TopCard extends StatelessWidget {
  final String role;
  final String facilityName;
  final bool canUseClinical;

  const _TopCard({required this.role, required this.facilityName, required this.canUseClinical});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            cs.primary.withOpacity(0.06),
            cs.secondary.withOpacity(0.06),
          ],
        ),
      ),
      child: Row(
        children: [
          const AcfLogo(size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Role: $role', style: const TextStyle(fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(
                  facilityName.isEmpty ? 'Facility: (not set)' : 'Facility: $facilityName',
                  style: TextStyle(color: cs.onSurfaceVariant),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (!canUseClinical)
            Text(
              'No clinical access',
              style: TextStyle(color: cs.error, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}

// _ActionCard replaced by shared AcfActionTile.

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 44, color: cs.onSurfaceVariant),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}
