import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/sync/sync_service.dart';
import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../utils/growth/growth_models.dart';
import '../utils/growth/whz_calculator.dart';
import '../utils/clinical/clinical_status.dart';
import '../widgets/acf_brand.dart';
import '../widgets/clinical_status_card.dart';

/// Simple enrollment visit screen.
///
/// This replaces the old in-depth enrollment assessment workflow.
/// It captures only:
/// - visit date
/// - anthropometry
/// - sachets dispensed
/// - next appointment
/// - optional notes
///
/// Existing in-depth assessment records remain in the database, but this screen
/// no longer collects or sends the full in-depth assessment form.
class ClinicalEnrollmentVisitScreen extends StatefulWidget {
  final String localChildId;
  final String? draftEnrollmentJson;
  final String? editAssessmentId;
  final Future<void> Function()? onFinalizeQueued;

  const ClinicalEnrollmentVisitScreen({
    super.key,
    required this.localChildId,
    this.draftEnrollmentJson,
    this.editAssessmentId,
    this.onFinalizeQueued,
  });

  @override
  State<ClinicalEnrollmentVisitScreen> createState() => _ClinicalEnrollmentVisitScreenState();
}

class _ClinicalEnrollmentVisitScreenState extends State<ClinicalEnrollmentVisitScreen> {
  final _uuid = const Uuid();
  final _formKey = GlobalKey<FormState>();

  final _childRepo = ClinicalChildRepo();
  final _assessRepo = ClinicalAssessmentRepo();
  final _queueRepo = SyncQueueRepo();
  final _syncService = SyncService();

  ClinicalChild? _child;
  ClinicalAssessment? _editing;
  SyncQueueItem? _existingEnrollQueueItem;

  bool _loading = true;
  bool _saving = false;

  final _weightKg = TextEditingController();
  final _heightCm = TextEditingController();
  final _muacMm = TextEditingController();
  final _sachets = TextEditingController();
  final _notes = TextEditingController();

  DateTime _visitDate = DateTime.now();
  DateTime? _nextAppointment;

  double? _whz;
  String? _status;
  ClinicalStatusResult? _clinicalStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _weightKg.dispose();
    _heightCm.dispose();
    _muacMm.dispose();
    _sachets.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final c = await _childRepo.findByLocalId(widget.localChildId);
    final editId = (widget.editAssessmentId ?? '').trim();

    ClinicalAssessment? existing;
    if (editId.isNotEmpty) {
      existing = await _assessRepo.findByLocalAssessmentId(editId);
    }

    final existingQueue = await _queueRepo.findLatestForEntity('clinical_enroll', widget.localChildId);

    if (!mounted) return;
    setState(() {
      _child = c;
      _editing = existing;
      _existingEnrollQueueItem = existingQueue;
      _loading = false;
    });

    if (existing != null) {
      _hydrateExisting(existing);
    } else if (c?.enrollmentDate != null) {
      _visitDate = DateTime(c!.enrollmentDate.year, c.enrollmentDate.month, c.enrollmentDate.day);
    }

    _nextAppointment ??= _visitDate.add(const Duration(days: 14));
    await _recompute();
  }

  void _hydrateExisting(ClinicalAssessment existing) {
    try {
      final m = (jsonDecode(existing.dataJson) as Map).cast<String, dynamic>();
      final anthro = (m['anthropometry'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final visit = (m['visit'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

      final w = anthro['weightKg'] ?? existing.weightKg;
      final h = anthro['heightCm'] ?? existing.heightCm;
      final mu = anthro['muacMm'] ?? existing.muacMm;
      if (w != null) _weightKg.text = '$w';
      if (h != null) _heightCm.text = '$h';
      if (mu != null) _muacMm.text = '$mu';

      final sachets = visit['sachetsDispensed'] ?? visit['quantitySachets'] ?? visit['sachetsGiven'];
      if (sachets != null) _sachets.text = '$sachets';

      final notes = (visit['notes'] ?? '').toString();
      if (notes.trim().isNotEmpty) _notes.text = notes;

      final parsedVisit = _tryParseYmd((visit['visitDate'] ?? '').toString());
      final parsedNext = _tryParseYmd((visit['nextAppointmentDate'] ?? '').toString());
      if (parsedVisit != null) _visitDate = parsedVisit;
      _nextAppointment = parsedNext;
    } catch (_) {
      // ignore invalid local JSON and allow the user to re-enter the values.
    }
  }

  static DateTime? _tryParseYmd(String v) {
    final s = v.trim();
    if (s.isEmpty) return null;
    try {
      final parts = s.split('-');
      if (parts.length != 3) return null;
      final y = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final d = int.parse(parts[2]);
      return DateTime(y, m, d);
    } catch (_) {
      return null;
    }
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  GrowthSex _parseSex(String v) {
    final s = v.toUpperCase();
    if (s.contains('FEMALE') || s == 'F') return GrowthSex.female;
    return GrowthSex.male;
  }

  int? _ageInMonths(DateTime? dob, DateTime onDate) {
    if (dob == null) return null;
    int months = (onDate.year - dob.year) * 12 + (onDate.month - dob.month);
    if (onDate.day < dob.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  double? _parseD(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int? _parseI(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  String _classifyWhz(double? z) {
    if (z == null) return 'Unknown';
    if (z < -3) return 'Severe Wasting';
    if (z < -2) return 'Moderate Wasting';
    if (z < -1) return 'At risk of Wasting';
    return 'Normal';
  }

  String _classifyMuac(int? mm) {
    if (mm == null) return 'Unknown';
    if (mm < 115) return 'Severe Wasting';
    if (mm < 125) return 'Moderate Wasting';
    if (mm < 135) return 'At risk of Wasting';
    return 'Normal';
  }

  String _mostSevere(String a, String b) {
    int rank(String s) {
      switch (s) {
        case 'Severe Wasting':
          return 4;
        case 'Moderate Wasting':
          return 3;
        case 'At risk of Wasting':
          return 2;
        case 'Normal':
          return 1;
        default:
          return 0;
      }
    }

    return rank(a) >= rank(b) ? a : b;
  }

  Future<void> _recompute() async {
    final child = _child;
    if (child == null || child.dateOfBirth == null) return;

    final weight = _parseD(_weightKg);
    final height = _parseD(_heightCm);
    if (weight == null || height == null) {
      if (!mounted) return;
      setState(() {
        _whz = null;
        _status = null;
        _clinicalStatus = null;
      });
      return;
    }

    final calc = const WhzCalculator();
    final res = await calc.compute(
      sex: _parseSex(child.sex),
      ageMonths: _ageInMonths(child.dateOfBirth, _visitDate),
      weightKg: weight,
      heightCm: height,
    );

    final whz = res.z;
    final statusWhz = _classifyWhz(whz);
    final statusMuac = _classifyMuac(_parseI(_muacMm));

    final nutritionalStatus = _mostSevere(statusWhz, statusMuac);
    final clinicalStatus = ClinicalStatusCalculator.evaluate(
      current: ClinicalMeasurement(
        visitDate: _visitDate,
        weightKg: weight,
        heightCm: height,
        muacMm: _parseI(_muacMm),
        whzScore: whz,
        encounterType: 'ENROLLMENT',
        localAssessmentId: _editing?.localAssessmentId,
      ),
      previous: null,
      enrollmentDate: child.enrollmentDate,
      visitDate: _visitDate,
      nutritionalStatus: nutritionalStatus,
    );

    if (!mounted) return;
    setState(() {
      _whz = whz;
      _status = nutritionalStatus;
      _clinicalStatus = clinicalStatus;
    });
  }

  Future<void> _pickVisitDate() async {
    final child = _child;
    final now = DateTime.now();
    final first = (child?.enrollmentDate != null)
        ? DateTime(child!.enrollmentDate.year, child.enrollmentDate.month, child.enrollmentDate.day)
        : DateTime(now.year - 1, 1, 1);

    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate,
      firstDate: first,
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked == null) return;
    setState(() => _visitDate = picked);
    await _recompute();
  }

  Future<void> _pickNextAppointment() async {
    final now = DateTime.now();
    final initial = _nextAppointment ?? _visitDate.add(const Duration(days: 14));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 1, 1, 1),
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked == null) return;
    setState(() => _nextAppointment = picked);
  }

  Map<String, dynamic> _buildEnrollPayloadFromChild(ClinicalChild c) {
    return {
      'caregiverName': c.caregiverName,
      'caregiverContacts': c.caregiverContacts,
      'village': c.village,
      'childFirstName': c.firstName,
      'childLastName': c.lastName,
      'sex': c.sex,
      'dateOfBirth': c.dateOfBirth != null ? _fmtDate(c.dateOfBirth!) : null,
      'cwcNumber': c.cwcNumber,
      'enrollmentDate': _fmtDate(c.enrollmentDate),
      'chpName': c.chpName,
      'chpContacts': c.chpContacts,
      if (c.facilityCode != null && c.facilityCode!.isNotEmpty) 'facilityCode': c.facilityCode,
    };
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_nextAppointment == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select next appointment date')));
      return;
    }

    final visitDay = DateTime(_visitDate.year, _visitDate.month, _visitDate.day);
    final nextDay = DateTime(_nextAppointment!.year, _nextAppointment!.month, _nextAppointment!.day);
    if (nextDay.isBefore(visitDay)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Next appointment date cannot be before the visit date')));
      return;
    }

    final child = _child;
    if (child == null) return;

    setState(() => _saving = true);
    try {
      final weightKg = _parseD(_weightKg);
      final heightCm = _parseD(_heightCm);
      final muacMm = _parseI(_muacMm);
      final sachets = int.tryParse(_sachets.text.trim());

      if (sachets == null || sachets <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sachets dispensed must be greater than 0')));
        return;
      }

      await _recompute();

      final assessmentDate = DateTime(_visitDate.year, _visitDate.month, _visitDate.day, 12);
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();

      final data = <String, dynamic>{
        'encounterType': 'ENROLLMENT',
        'formType': 'SIMPLE_ENROLLMENT_VISIT',
        'anthropometry': {
          'weightKg': weightKg,
          'heightCm': heightCm,
          'muacMm': muacMm,
          'whzScore': _whz,
        },
        'visit': {
          'visitDate': _fmtDate(_visitDate),
          'sachetsDispensed': sachets,
          'nextAppointmentDate': _fmtDate(_nextAppointment!),
          'notes': notes,
        },
        'derived': {
          'nutritionalStatus': _status,
          if (_clinicalStatus != null) ..._clinicalStatus!.toJson(),
        },
      };

      final existing = _editing;
      final a = existing ?? ClinicalAssessment();
      if (existing == null) {
        a.localAssessmentId = _uuid.v4();
        a.localChildId = child.localChildId;
        a.createdAt = DateTime.now();
      }

      a
        ..assessmentDate = assessmentDate
        ..dataJson = jsonEncode(data)
        ..muacMm = muacMm
        ..weightKg = weightKg
        ..heightCm = heightCm
        ..status = 'QUEUED'
        ..updatedAt = DateTime.now();

      await _assessRepo.upsert(a);

      Map<String, dynamic> base;
      final queueItem = _existingEnrollQueueItem;
      if (queueItem != null && (queueItem.payloadJson ?? '').trim().isNotEmpty) {
        base = (jsonDecode(queueItem.payloadJson!) as Map).cast<String, dynamic>();
      } else if ((widget.draftEnrollmentJson ?? '').trim().isNotEmpty) {
        base = (jsonDecode(widget.draftEnrollmentJson!) as Map).cast<String, dynamic>();
      } else {
        base = _buildEnrollPayloadFromChild(child);
      }

      // The old full in-depth assessment is intentionally not included.
      base.remove('inDepthAssessment');
      base['visit'] = {
        'visitDate': _fmtDate(_visitDate),
        'weightKg': weightKg,
        'heightCm': heightCm,
        'muacMm': muacMm,
        'whzScore': _whz,
        'sachetsDispensed': sachets,
        'quantitySachets': sachets,
        'nextAppointmentDate': _fmtDate(_nextAppointment!),
        'notes': notes,
        'nutritionalStatus': _status,
        if (_clinicalStatus != null) 'clinicalStatus': _clinicalStatus!.toJson(),
      };

      final SyncQueueItem item;
      if (queueItem != null) {
        queueItem.payloadJson = jsonEncode(base);
        queueItem.status = SyncStatus.pending;
        queueItem.lastError = null;
        queueItem.lastAttemptAt = null;
        queueItem.attempts = 0;
        item = queueItem;
      } else {
        item = SyncQueueItem.build(
          queueId: a.localAssessmentId,
          entityType: 'clinical_enroll',
          localEntityId: child.localChildId,
          method: 'POST',
          endpoint: '/api/clinical/enroll',
          operation: SyncOperation.create,
          payloadJson: jsonEncode(base),
          idempotencyKey: a.localAssessmentId,
        );
      }

      await _queueRepo.enqueueOrReplace(item);

      child.status = 'QUEUED';
      child.updatedAt = DateTime.now();
      await _childRepo.upsert(child);
      await widget.onFinalizeQueued?.call();

      final result = await _syncService.syncNow();

      if (!mounted) return;
      final msg = result.online
          ? 'Enrollment saved. Sync: sent ${result.sent}, failed ${result.failed}.'
          : 'Enrollment saved offline and queued for automatic sync.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      Navigator.popUntil(context, (r) => r.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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

    final isEdit = _editing != null;

    return WillPopScope(
      onWillPop: () async => !_saving,
      child: Scaffold(
        appBar: AcfAppBar(title: isEdit ? 'Edit enrollment visit' : 'Enrollment visit'),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: cs.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${child.firstName} ${child.lastName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text(
                            [
                              if ((child.cwcNumber ?? '').isNotEmpty) 'CWC: ${child.cwcNumber}',
                              if (child.dateOfBirth != null) 'DOB: ${_fmtDate(child.dateOfBirth!)}',
                              'Status: ${child.status}',
                            ].join(' • '),
                            style: TextStyle(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickVisitDate,
                            icon: const Icon(Icons.event),
                            label: Text('Visit: ${_fmtDate(_visitDate)}'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving ? null : _pickNextAppointment,
                            icon: const Icon(Icons.event_available),
                            label: Text(_nextAppointment == null ? 'Next appt' : 'Next: ${_fmtDate(_nextAppointment!)}'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text('Anthropometry', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _weightKg,
                            decoration: const InputDecoration(labelText: 'Weight (kg) *'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                            onChanged: (_) => _recompute(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _heightCm,
                            decoration: const InputDecoration(labelText: 'Height/Length (cm) *'),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                            validator: (v) => double.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                            onChanged: (_) => _recompute(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _muacMm,
                      decoration: const InputDecoration(labelText: 'MUAC (mm) *'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                      validator: (v) => int.tryParse((v ?? '').trim()) == null ? 'Required' : null,
                      onChanged: (_) => _recompute(),
                    ),
                    const SizedBox(height: 12),
                    ClinicalStatusCard(
                      result: _clinicalStatus,
                      emptyText: 'Enter weight, height and MUAC to calculate recovery and exit eligibility.',
                    ),
                    const SizedBox(height: 16),
                    const Text('Dispensing', style: TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _sachets,
                      decoration: const InputDecoration(labelText: 'Sachets dispensed *'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                      validator: (v) {
                        final n = int.tryParse((v ?? '').trim());
                        if (n == null || n <= 0) return 'Required';
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notes,
                      decoration: const InputDecoration(labelText: 'Notes (optional)'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.save),
                      label: Text(isEdit ? 'Save changes' : 'Save enrollment'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This visit updates charts, recovery status, exit eligibility and facility stock during sync.',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            if (_saving)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black26,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
