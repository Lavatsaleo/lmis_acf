import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/remote/clinical_remote_sync_service.dart';
import '../screens/clinical_enrollment_visit_screen.dart';
import '../screens/clinical_followup_visit_screen.dart';
import '../screens/clinical_edit_child_screen.dart';
import '../widgets/nutrition_snapshot_card.dart';
import '../widgets/whz_growth_chart_card.dart';
import '../widgets/acf_brand.dart';
import '../utils/clinical/clinical_status.dart';
import '../widgets/clinical_status_card.dart';

class ClinicalChildDetailScreen extends StatefulWidget {
  final String localChildId;

  const ClinicalChildDetailScreen({super.key, required this.localChildId});

  @override
  State<ClinicalChildDetailScreen> createState() => _ClinicalChildDetailScreenState();
}

class _ClinicalChildDetailScreenState extends State<ClinicalChildDetailScreen> {
  final _childRepo = ClinicalChildRepo();
  final _assessRepo = ClinicalAssessmentRepo();
  final _queueRepo = SyncQueueRepo();
  final _remoteClinical = ClinicalRemoteSyncService();

  ClinicalChild? _child;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    var c = await _childRepo.findByLocalId(widget.localChildId);

    // If this child already exists on the server, pull the full child summary when
    // opening details. This brings down all server visits, not only the latest
    // facility activity row, so clinicians can identify and correct any visit.
    final remoteChildId = (c?.remoteChildId ?? '').trim();
    if (remoteChildId.isNotEmpty) {
      try {
        await _remoteClinical.importChildSummaryByRemoteId(remoteChildId);
        c = await _childRepo.findByLocalId(widget.localChildId);
      } catch (_) {
        // Keep showing local data when offline or when refresh fails.
      }
    }

    if (!mounted) return;
    setState(() {
      _child = c;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final child = _child;
    if (child == null) {
      return const Scaffold(body: Center(child: Text('Child not found')));
    }

    final canEditChildDetails = true;

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Child details',
        actions: [
          if (canEditChildDetails)
            IconButton(
              tooltip: 'Edit child details',
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ClinicalEditChildScreen(localChildId: child.localChildId),
                  ),
                );
                if (result != null) {
                  await _load();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Child details updated.')),
                  );
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    [
                      if (child.cwcNumber != null && child.cwcNumber!.isNotEmpty) 'CWC: ${child.cwcNumber}',
                      if (child.dateOfBirth != null) 'DOB: ${_fmtDate(child.dateOfBirth!)}',
	                      if ((child.uniqueChildNumber ?? '').isNotEmpty)
	                        'Reg#: ${child.uniqueChildNumber}'
	                      else if ((child.facilityCode ?? '').isNotEmpty && (child.cwcNumber ?? '').isNotEmpty)
	                        'Reg#: ${child.facilityCode}/${child.cwcNumber}/SQLNS (pending sync)',
                      'Sex: ${child.sex}',
                      'Status: ${child.status}',
                    ].join(' • '),
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text('Caregiver: ${child.caregiverName}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  if ((child.caregiverContacts).isNotEmpty) Text('Contacts: ${child.caregiverContacts}'),
                  if ((child.village ?? '').isNotEmpty) Text('Village: ${child.village}'),
                  if (canEditChildDetails) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ClinicalEditChildScreen(localChildId: child.localChildId),
                            ),
                          );
                          if (result != null) {
                            await _load();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Child details updated.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit enrollment details'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: StreamBuilder<List<ClinicalAssessment>>(
                stream: _assessRepo.watchForChild(child.localChildId),
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <ClinicalAssessment>[];

                  final nextAppt = _extractNextAppointment(items);
                  final isDischarged = _hasEncounter(items, 'DISCHARGE');
                  final hasEnrollment = _hasEncounter(items, 'ENROLLMENT');

                  final monthsInProgram = _monthsBetween(child.enrollmentDate, DateTime.now());
                  final latestClinicalStatus = _latestClinicalStatus(child, items);
                  final exitEligible = !isDischarged && (latestClinicalStatus?.isExitEligible ?? false);

                  final children = <Widget>[];



                  // If the user registered the child but did not complete the enrollment visit,
                  // allow them to capture anthropometry and dispensing from here.
                  if (!hasEnrollment) {
                    children.add(
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Enrollment visit missing', style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 6),
                            Text(
                              'This child was registered locally but the enrollment anthropometry and dispensing visit was not completed. Tap below to continue.',
                              style: TextStyle(color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 10),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ClinicalEnrollmentVisitScreen(
                                      localChildId: child.localChildId,
                                      onFinalizeQueued: () async {
                                        // Mark enrollment as queued once the enrollment visit queues the enrollment payload.
                                        child.status = 'QUEUED';
                                        await _childRepo.upsert(child);
                                        if (mounted) setState(() {});
                                      },
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.assignment_outlined),
                              label: const Text('Complete enrollment visit'),
                            ),
                          ],
                        ),
                      ),
                    );
                    children.add(const SizedBox(height: 12));
                  }
                  // Quick actions
                  children.add(
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (isDischarged || !hasEnrollment)
                                ? null
                                : () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ClinicalFollowupVisitScreen(localChildId: child.localChildId),
                                      ),
                                    );
                                  },
                            icon: const Icon(Icons.straighten),
                            label: const Text('Follow-up visit'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.logout),
                            label: const Text('Exit later'),
                          ),
                        ),
                      ],
                    ),
                  );

                  children.add(const SizedBox(height: 10));

                  // Programme banner
                  children.add(
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enrolled: ${_fmtDate(child.enrollmentDate)} • Duration: $monthsInProgram months',
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            nextAppt == null ? 'Next appointment: not set' : 'Next appointment: ${_fmtDate(nextAppt)}',
                            style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
                          ),
                          if (isDischarged) ...[
                            const SizedBox(height: 6),
                            Text('Status: DISCHARGED', style: TextStyle(color: cs.primary, fontWeight: FontWeight.w900)),
                          ],
                          if (exitEligible) ...[
                            const SizedBox(height: 6),
                            Text(
                              'This child is exit eligible: recovery criteria achieved and 6 months in programme completed.',
                              style: TextStyle(color: cs.error, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );

                  children.add(const SizedBox(height: 12));

                  if (latestClinicalStatus != null) {
                    children.add(ClinicalStatusCard(result: latestClinicalStatus));
                    children.add(const SizedBox(height: 12));
                  }

                  if (items.isNotEmpty) {
                    children.add(NutritionSnapshotCard(child: child, latest: items.first));
                    children.add(const SizedBox(height: 12));
                    children.add(WhzGrowthChartCard(child: child, assessments: items));
                    children.add(const SizedBox(height: 14));
                  }

                  children.add(const Text('Visits and measurements', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)));
                  children.add(const SizedBox(height: 8));

                  if (items.isEmpty) {
                    children.add(
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cs.surface,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: cs.outlineVariant),
                        ),
                        child: Text('No visits or measurements saved locally yet.', style: TextStyle(color: cs.onSurfaceVariant)),
                      ),
                    );
                    return ListView(children: children);
                  }

                  for (final a in items) {
                    final label = _assessmentLabel(a);
                    final encounterType = _encounterType(a);
                    final canEdit = _canEditVisit(child, a, encounterType);
                    children.add(
                      ListTile(
                        tileColor: cs.surface,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: Text('$label • ${_fmtDate(a.assessmentDate)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        subtitle: Text(
                          [
                            if (a.weightKg != null) 'W: ${a.weightKg!.toStringAsFixed(1)}kg',
                            if (a.heightCm != null) 'H: ${a.heightCm!.toStringAsFixed(1)}cm',
                            if (a.muacMm != null) 'MUAC: ${a.muacMm}mm',
                            if (a.householdHungerScore != null) 'HHS: ${a.householdHungerScore} (${a.householdHungerCategory ?? ''})',
                            if (a.pssScore != null) 'PSS: ${a.pssScore} (${a.pssCategory ?? ''})',
                            'Status: ${a.status}',
                          ].where((s) => s.trim().isNotEmpty).join(' • '),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'View',
                              onPressed: () => _showAssessment(context, a),
                              icon: const Icon(Icons.visibility),
                            ),
                            if (canEdit)
                              IconButton(
                                tooltip: a.status == 'SYNCED' ? 'Edit synced visit' : 'Edit draft visit',
                                onPressed: () => _openEdit(context, a, encounterType),
                                icon: const Icon(Icons.edit),
                              ),
                          ],
                        ),
                        onTap: () => _showAssessment(context, a),
                      ),
                    );
                    children.add(const SizedBox(height: 10));
                  }

                  return ListView(children: children);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canEditVisit(ClinicalChild child, ClinicalAssessment a, String encounterType) {
    final t = encounterType.toUpperCase();
    if (t != 'FOLLOWUP' && t != 'ENROLLMENT') return false;
    if (a.status != 'SYNCED') return true;

    final remoteChildId = (child.remoteChildId ?? '').trim();
    final remoteVisitId = _remoteVisitId(a);
    return remoteChildId.isNotEmpty && remoteVisitId != null && remoteVisitId.isNotEmpty;
  }

  String? _remoteVisitId(ClinicalAssessment a) {
    final raw = (a.remoteAssessmentId ?? '').trim();
    if (raw.isEmpty) return null;
    return raw.startsWith('visit:') ? raw.substring('visit:'.length) : raw;
  }

  void _showAssessment(BuildContext context, ClinicalAssessment a) {
    Map<String, dynamic>? data;
    try {
      data = jsonDecode(a.dataJson) as Map<String, dynamic>;
    } catch (_) {
      data = null;
    }

    final encounterType = (data?['encounterType'] ?? '').toString().toUpperCase();
    final child = _child;
    final canEdit = child != null && _canEditVisit(child, a, encounterType);
    final canDelete = a.status != 'SYNCED' && (encounterType == 'FOLLOWUP' || encounterType == 'ENROLLMENT');

    final notes = (data?['analysis']?['notes'] as List?)?.cast<String>() ?? const <String>[];

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Record ${_fmtDate(a.assessmentDate)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),

                if (canEdit) ...[
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(context); // close sheet
                      _openEdit(context, a, encounterType);
                    },
                    icon: const Icon(Icons.edit),
                    label: Text(encounterType == 'FOLLOWUP' ? 'Edit this follow-up' : 'Edit this enrollment visit'),
                  ),
                  const SizedBox(height: 10),
                  if (a.status == 'SYNCED')
                    Text(
                      'This synced visit can be corrected. Your correction will be queued and synced to the server automatically.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w700),
                    ),
                  if (canDelete) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                    onPressed: () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete draft?'),
                          content: const Text(
                            'This record has not been synced yet. Deleting it will restore sachet totals in the facility store.',
                          ),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
                          ],
                        ),
                      );
                      if (ok != true) return;

                      // Delete local assessment + corresponding queued sync item.
                      await _assessRepo.deleteByLocalAssessmentId(a.localAssessmentId);
                      if (encounterType == 'FOLLOWUP') {
                        await _queueRepo.deleteByQueueId(a.localAssessmentId);
                      } else if (encounterType == 'DISCHARGE') {
                        await _queueRepo.deleteByQueueId(a.localAssessmentId);
                      } else if (encounterType == 'ENROLLMENT') {
                        // Enrollment queue item uses localChildId as localEntityId.
                        await _queueRepo.deleteLatestForEntity('clinical_enroll', a.localChildId);
                      }

                      if (context.mounted) {
                        Navigator.pop(context); // close sheet
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted. Stock totals restored locally.')));
                      }
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete (not synced)'),
                  ),
                  ],
                  const SizedBox(height: 12),
                ] else ...[
                  Text(
                    'View only. Only enrollment and follow-up visit records can be edited.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 12),
                ],

                if (notes.isEmpty)
                  const Text('No analysis notes'),
                if (notes.isNotEmpty) ...[
                  const Text('Analysis notes', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  for (final n in notes) Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  '),
                        Expanded(child: Text(n)),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text('Local record data (JSON):', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Text(a.dataJson, style: const TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openEdit(BuildContext context, ClinicalAssessment a, String encounterType) {
    final t = encounterType.toUpperCase();
    if (t == 'FOLLOWUP') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClinicalFollowupVisitScreen(
            localChildId: a.localChildId,
            editAssessmentId: a.localAssessmentId,
          ),
        ),
      );
      return;
    }

    if (t == 'ENROLLMENT') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClinicalEnrollmentVisitScreen(
            localChildId: a.localChildId,
            editAssessmentId: a.localAssessmentId,
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Editing this record is not available in the simplified workflow.')),
    );
  }

  static ClinicalStatusResult? _latestClinicalStatus(ClinicalChild child, List<ClinicalAssessment> items) {
    final latest = ClinicalStatusCalculator.latestMeasurement(items);
    if (latest == null) return null;

    final previous = ClinicalStatusCalculator.findPreviousMeasurement(
      items,
      beforeOrOnDate: latest.visitDate.subtract(const Duration(days: 1)),
      excludeLocalAssessmentId: latest.localAssessmentId,
    );

    return ClinicalStatusCalculator.evaluate(
      current: latest,
      previous: previous,
      enrollmentDate: child.enrollmentDate,
      visitDate: latest.visitDate,
      nutritionalStatus: _nutritionalStatusForAssessment(items, latest.localAssessmentId),
    );
  }

  static String? _nutritionalStatusForAssessment(List<ClinicalAssessment> items, String? localAssessmentId) {
    if (localAssessmentId == null) return null;
    for (final item in items) {
      if (item.localAssessmentId != localAssessmentId) continue;
      try {
        final m = jsonDecode(item.dataJson) as Map<String, dynamic>;
        final derived = (m['derived'] as Map?)?.cast<String, dynamic>();
        return (derived?['nutritionalStatus'] ?? m['nutritionalStatus'])?.toString();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  static bool _hasEncounter(List<ClinicalAssessment> items, String encounterType) {
    for (final a in items) {
      try {
        final m = jsonDecode(a.dataJson) as Map<String, dynamic>;
        final t = (m['encounterType'] ?? '').toString().toUpperCase();
        if (t == encounterType.toUpperCase()) return true;
      } catch (_) {
        // ignore
      }
    }
    return false;
  }

  static String _assessmentLabel(ClinicalAssessment a) {
    try {
      final m = jsonDecode(a.dataJson) as Map<String, dynamic>;
      final t = (m['encounterType'] ?? '').toString().toUpperCase();
      if (t == 'FOLLOWUP') return 'Follow-up visit';
      if (t == 'DISCHARGE') return 'Discharge assessment';
      if (t == 'ENROLLMENT') return 'Enrollment visit';
    } catch (_) {
      // ignore
    }
    return 'Assessment';
  }

  static String _encounterType(ClinicalAssessment a) {
    try {
      final m = jsonDecode(a.dataJson) as Map<String, dynamic>;
      return (m['encounterType'] ?? '').toString().toUpperCase();
    } catch (_) {
      return '';
    }
  }

  static DateTime? _extractNextAppointment(List<ClinicalAssessment> items) {
    for (final a in items) {
      try {
        final m = jsonDecode(a.dataJson) as Map<String, dynamic>;
        final visit = (m['visit'] as Map?)?.cast<String, dynamic>();
        final v = (visit?['nextAppointmentDate'] ?? m['nextAppointmentDate'])?.toString();
        if (v == null || v.trim().isEmpty) continue;
        final d = DateTime.tryParse(v);
        if (d != null) return d;
      } catch (_) {
        // ignore
      }
    }
    return null;
  }
}
