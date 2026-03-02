import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import 'clinical_child_detail_screen.dart';
import '../widgets/acf_brand.dart';

class ClinicalAppointmentsScreen extends StatefulWidget {
  const ClinicalAppointmentsScreen({super.key});

  @override
  State<ClinicalAppointmentsScreen> createState() => _ClinicalAppointmentsScreenState();
}

class _ClinicalAppointmentsScreenState extends State<ClinicalAppointmentsScreen> {
  final _childRepo = ClinicalChildRepo();
  final _assessRepo = ClinicalAssessmentRepo();

  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Appointments diary',
        actions: const [],
      ),
      body: StreamBuilder<List<ClinicalChild>>(
        stream: _childRepo.watchAll(limit: 5000),
        builder: (context, snap) {
          final children = snap.data ?? const <ClinicalChild>[];
          return FutureBuilder<List<_ApptRow>>(
            future: _buildRowsForDate(children, _selectedDate),
            builder: (context, rowsSnap) {
              final rows = rowsSnap.data ?? const <_ApptRow>[];
              if (rowsSnap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final normalized = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
              final today = DateTime.now();
              final todayN = DateTime(today.year, today.month, today.day);
              final isPastOrToday = !normalized.isAfter(todayN);
              final seen = rows.where((r) => r.seen).length;
              final missed = isPastOrToday ? (rows.length - seen) : 0;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: CalendarDatePicker(
                        initialDate: normalized,
                        firstDate: DateTime(today.year - 1, 1, 1),
                        lastDate: DateTime(today.year + 2, 12, 31),
                        onDateChanged: (d) => setState(() => _selectedDate = d),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: cs.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: cs.outlineVariant),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.event_note, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Selected: ${_fmtDate(normalized)}',
                                    style: const TextStyle(fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        Expanded(child: _StatChip(label: 'Scheduled', value: rows.length.toString())),
                        const SizedBox(width: 10),
                        Expanded(child: _StatChip(label: 'Seen', value: seen.toString())),
                        const SizedBox(width: 10),
                        Expanded(child: _StatChip(label: 'Missed', value: missed.toString())),
                      ],
                    ),
                  ),

                  Expanded(
                    child: rows.isEmpty
                        ? Center(child: Text('No appointments for this day', style: TextStyle(color: cs.onSurfaceVariant)))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            itemCount: rows.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) {
                              final r = rows[i];
                              final statusIcon = r.seen
                                  ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
                                  : (isPastOrToday
                                      ? Icon(Icons.cancel, color: cs.error)
                                      : Icon(Icons.schedule, color: cs.onSurfaceVariant));

                              final statusText = r.seen
                                  ? 'Visited'
                                  : (isPastOrToday ? 'Not seen' : 'Upcoming');

                              return ListTile(
                                tileColor: cs.surface,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                leading: statusIcon,
                                title: Text('${r.child.firstName} ${r.child.lastName}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                subtitle: Text(
                                  [
                                    'Appt: ${_fmtDate(r.appointmentDate)}',
                                    statusText,
                                    if ((r.child.caregiverContacts).isNotEmpty) 'Tel: ${r.child.caregiverContacts}',
                                    if ((r.child.cwcNumber ?? '').isNotEmpty) 'CWC: ${r.child.cwcNumber}',
                                  ].join(' • '),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ClinicalChildDetailScreen(localChildId: r.child.localChildId),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<List<_ApptRow>> _buildRowsForDate(List<ClinicalChild> children, DateTime day) async {
    final target = DateTime(day.year, day.month, day.day);

    final rows = <_ApptRow>[];
    for (final c in children) {
      final items = await _assessRepo.listForChild(c.localChildId, limit: 100);
      final appt = _extractNextAppointment(items);
      if (appt == null) continue;
      final d = DateTime(appt.year, appt.month, appt.day);
      if (d.year != target.year || d.month != target.month || d.day != target.day) continue;

      final seen = _hasFollowupOn(items, target);
      rows.add(_ApptRow(child: c, appointmentDate: d, seen: seen));
    }

    rows.sort((a, b) {
      // Not seen first (so clinician can quickly see who is pending).
      if (a.seen != b.seen) return a.seen ? 1 : -1;
      return ('${a.child.firstName} ${a.child.lastName}').compareTo('${b.child.firstName} ${b.child.lastName}');
    });
    return rows;
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

  static bool _hasFollowupOn(List<ClinicalAssessment> items, DateTime day) {
    for (final a in items) {
      // Quick day match using stored assessmentDate.
      final d = DateTime(a.assessmentDate.year, a.assessmentDate.month, a.assessmentDate.day);
      if (d.year != day.year || d.month != day.month || d.day != day.day) continue;
      try {
        final m = jsonDecode(a.dataJson) as Map<String, dynamic>;
        final t = (m['encounterType'] ?? '').toString().toUpperCase();
        if (t == 'FOLLOWUP' || t == 'FOLLOW-UP') return true;
      } catch (_) {
        // ignore
      }
    }
    return false;
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _ApptRow {
  final ClinicalChild child;
  final DateTime appointmentDate;
  final bool seen;

  _ApptRow({required this.child, required this.appointmentDate, required this.seen});
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
