import 'dart:convert';

import 'package:flutter/material.dart';

import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/remote/clinical_remote_sync_service.dart';
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
  final _remoteSync = ClinicalRemoteSyncService();

  DateTime _selectedDate = DateTime.now();
  bool _loading = true;
  bool _usingLocalFallback = false;
  List<_ApptRow> _rows = const [];

  @override
  void initState() {
    super.initState();
    _loadRows();
  }

  Future<void> _loadRows() async {
    setState(() => _loading = true);

    try {
      final remoteRows = await _remoteSync.fetchFacilityAppointments(_selectedDate);
      final rows = <_ApptRow>[];
      for (final r in remoteRows) {
        final child = (r['child'] is Map) ? (r['child'] as Map).cast<String, dynamic>() : const <String, dynamic>{};
        final caregiver = (child['caregiver'] is Map)
            ? (child['caregiver'] as Map).cast<String, dynamic>()
            : const <String, dynamic>{};
        final remoteId = (child['id'] ?? '').toString().trim();
        final existing = remoteId.isEmpty ? null : await _childRepo.findByRemoteChildId(remoteId);
        rows.add(
          _ApptRow(
            localChildId: existing?.localChildId,
            remoteChildId: remoteId.isEmpty ? null : remoteId,
            firstName: (child['firstName'] ?? '').toString(),
            lastName: (child['lastName'] ?? '').toString(),
            caregiverContacts: (caregiver['contacts'] ?? caregiver['caregiverContacts'] ?? '').toString(),
            cwcNumber: (child['cwcNumber'] ?? '').toString(),
            appointmentDate: _parseDate(r['appointmentDate']) ?? _selectedDate,
            seen: ((r['seen'] ?? false) == true),
            status: (r['status'] ?? '').toString().trim().toUpperCase(),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _usingLocalFallback = false;
        _loading = false;
      });
      return;
    } catch (_) {
      // fall back to local cache below
    }

    final children = await _childRepo.listAll(limit: 5000);
    final rows = await _buildRowsForDate(children, _selectedDate);

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _usingLocalFallback = true;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final normalized = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final today = DateTime.now();
    final todayN = DateTime(today.year, today.month, today.day);
    final isPastOrToday = !normalized.isAfter(todayN);
    final seen = _rows.where((r) => r.seen).length;
    final missed = isPastOrToday ? (_rows.length - seen) : 0;

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Appointments diary',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadRows,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
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
                      onDateChanged: (d) {
                        setState(() => _selectedDate = d);
                        _loadRows();
                      },
                    ),
                  ),
                ),
                if (_usingLocalFallback)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Text(
                        'Showing cached local appointments because live facility data could not be reached.',
                        style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
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
                      Expanded(child: _StatChip(label: 'Scheduled', value: _rows.length.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: _StatChip(label: 'Seen', value: seen.toString())),
                      const SizedBox(width: 10),
                      Expanded(child: _StatChip(label: 'Missed', value: missed.toString())),
                    ],
                  ),
                ),
                Expanded(
                  child: _rows.isEmpty
                      ? Center(child: Text('No appointments for this day', style: TextStyle(color: cs.onSurfaceVariant)))
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: _rows.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final r = _rows[i];
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
                              title: Text('${r.firstName} ${r.lastName}', style: const TextStyle(fontWeight: FontWeight.w900)),
                              subtitle: Text(
                                [
                                  'Appt: ${_fmtDate(r.appointmentDate)}',
                                  statusText,
                                  if (r.caregiverContacts.isNotEmpty) 'Tel: ${r.caregiverContacts}',
                                  if (r.cwcNumber.isNotEmpty) 'CWC: ${r.cwcNumber}',
                                ].join(' • '),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => _openChild(r),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _openChild(_ApptRow row) async {
    try {
      String? localChildId = row.localChildId;
      if ((localChildId == null || localChildId.isEmpty) && row.remoteChildId != null) {
        localChildId = await _remoteSync.importChildSummaryByRemoteId(row.remoteChildId!);
      }
      if (!mounted || localChildId == null || localChildId.trim().isEmpty) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ClinicalChildDetailScreen(localChildId: localChildId!)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open child: $e')));
    }
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
      rows.add(
        _ApptRow(
          localChildId: c.localChildId,
          remoteChildId: c.remoteChildId,
          firstName: c.firstName,
          lastName: c.lastName,
          caregiverContacts: c.caregiverContacts,
          cwcNumber: c.cwcNumber ?? '',
          appointmentDate: d,
          seen: seen,
          status: seen ? 'HONOURED' : (target.isAfter(DateTime.now()) ? 'UPCOMING' : 'MISSED'),
        ),
      );
    }

    rows.sort((a, b) {
      if (a.seen != b.seen) return a.seen ? 1 : -1;
      return ('${a.firstName} ${a.lastName}').compareTo('${b.firstName} ${b.lastName}');
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

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    final s = value.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _ApptRow {
  final String? localChildId;
  final String? remoteChildId;
  final String firstName;
  final String lastName;
  final String caregiverContacts;
  final String cwcNumber;
  final DateTime appointmentDate;
  final bool seen;
  final String status;

  const _ApptRow({
    required this.localChildId,
    required this.remoteChildId,
    required this.firstName,
    required this.lastName,
    required this.caregiverContacts,
    required this.cwcNumber,
    required this.appointmentDate,
    required this.seen,
    required this.status,
  });
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
