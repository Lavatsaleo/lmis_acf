import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/sync/sync_service.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/local/isar/sync_queue_item.dart';
import 'queue_inspector_screen.dart';
import '../widgets/acf_brand.dart';

/// Step 8: Clinical enrollment + baseline in-depth assessment (MVP).
///
/// Offline-first behaviour:
/// - Always enqueue a POST /api/clinical/enroll
/// - If online, we immediately attempt sync
///
/// NOTE: We are starting with the "core" sections first:
/// - Caregiver + Child demographics
/// - Anthropometry (weight/height/MUAC)
/// - Household Hunger Scale (HHS) with skip logic + score
/// - Caregiver stress (PSS) score
///
/// We will expand to the full Word form (all sections) next.
class ClinicalRegisterEnrollScreen extends StatefulWidget {
  const ClinicalRegisterEnrollScreen({super.key});

  @override
  State<ClinicalRegisterEnrollScreen> createState() => _ClinicalRegisterEnrollScreenState();
}

class _ClinicalRegisterEnrollScreenState extends State<ClinicalRegisterEnrollScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _queueRepo = SyncQueueRepo();
  final _syncService = SyncService();

  // Stepper state
  int _step = 0;
  bool _saving = false;

  // Caregiver
  final _caregiverName = TextEditingController();
  final _caregiverContacts = TextEditingController();
  final _caregiverVillage = TextEditingController();

  // Child
  final _childFirstName = TextEditingController();
  final _childLastName = TextEditingController();
  final _cwcNumber = TextEditingController();
  DateTime? _dob;
  String? _sex; // 'M' or 'F'

  // Optional CHP
  final _chpName = TextEditingController();
  final _chpContacts = TextEditingController();

  // Anthropometry
  final _weightKg = TextEditingController();
  final _heightCm = TextEditingController();
  final _muacCm = TextEditingController();

  // HHS (skip logic)
  bool? _hhsQ1NoFood;
  String? _hhsQ1Freq; // rarely/sometimes/often
  bool? _hhsQ2WentToBedHungry;
  String? _hhsQ2Freq;
  bool? _hhsQ3WholeDayNoFood;
  String? _hhsQ3Freq;

  // PSS (0/1/2)
  int? _pss1;
  int? _pss2;
  int? _pss3;
  int? _pss4;
  int? _pss5;

  @override
  void dispose() {
    _caregiverName.dispose();
    _caregiverContacts.dispose();
    _caregiverVillage.dispose();

    _childFirstName.dispose();
    _childLastName.dispose();
    _cwcNumber.dispose();

    _chpName.dispose();
    _chpContacts.dispose();

    _weightKg.dispose();
    _heightCm.dispose();
    _muacCm.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final first = DateTime(now.year - 10, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 1, now.month, now.day),
      firstDate: first,
      lastDate: now,
    );
    if (picked == null) return;
    setState(() => _dob = picked);
  }

  int? _parseInt(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double? _parseDouble(String v) {
    final t = v.trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  int _hhsFreqScore(String? freq) {
    switch ((freq ?? '').toLowerCase()) {
      case 'rarely':
      case 'sometimes':
        return 1;
      case 'often':
        return 2;
      default:
        return 0;
    }
  }

  Map<String, dynamic> _computeHhs() {
    final q1 = (_hhsQ1NoFood ?? false) ? _hhsFreqScore(_hhsQ1Freq) : 0;
    final q2 = (_hhsQ2WentToBedHungry ?? false) ? _hhsFreqScore(_hhsQ2Freq) : 0;
    final q3 = (_hhsQ3WholeDayNoFood ?? false) ? _hhsFreqScore(_hhsQ3Freq) : 0;

    final score = q1 + q2 + q3;
    String category;
    if (score <= 1) {
      category = 'Little to no hunger';
    } else if (score <= 3) {
      category = 'Moderate hunger';
    } else {
      category = 'Severe hunger';
    }

    return {
      'score': score,
      'category': category,
      'q1': {'yes': _hhsQ1NoFood, 'freq': _hhsQ1Freq, 'score': q1},
      'q2': {'yes': _hhsQ2WentToBedHungry, 'freq': _hhsQ2Freq, 'score': q2},
      'q3': {'yes': _hhsQ3WholeDayNoFood, 'freq': _hhsQ3Freq, 'score': q3},
    };
  }

  Map<String, dynamic> _computePss() {
    final vals = [_pss1, _pss2, _pss3, _pss4, _pss5].whereType<int>().toList();
    final total = vals.fold<int>(0, (a, b) => a + b);
    // Basic interpretation using the table in the Word form.
    // (We will refine wording once we implement the full form.)
    String category;
    if (total <= 2) {
      category = 'Low stress';
    } else if (total <= 6) {
      category = 'Moderate stress';
    } else {
      category = 'High stress';
    }
    return {
      'score': total,
      'category': category,
      'q1': _pss1,
      'q2': _pss2,
      'q3': _pss3,
      'q4': _pss4,
      'q5': _pss5,
    };
  }

  String _fmtDob(DateTime? d) {
    if (d == null) return 'Select date';
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  int? _ageInMonths(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    int months = (now.year - dob.year) * 12 + (now.month - dob.month);
    if (now.day < dob.day) months -= 1;
    return months < 0 ? 0 : months;
  }

  Future<void> _submit() async {
    // Prevent double-taps while the request/queueing is still in progress.
    if (_saving) return;

    // Lock immediately (before any validation/await) to avoid double submissions.
    setState(() => _saving = true);
    try {
      // Validate required fields across all steps.
      if (!(_formKey.currentState?.validate() ?? false)) return;
      if (_dob == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Please select Date of birth')));
        return;
      }
      if ((_sex ?? '').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Sex')));
        return;
      }

      final queueId = _uuid.v4();
      final localChildId = _uuid.v4();

      final hhs = _computeHhs();
      final pss = _computePss();

      final weight = _parseDouble(_weightKg.text);
      final height = _parseDouble(_heightCm.text);
      final muacCm = _parseDouble(_muacCm.text);
      final muacMm = (muacCm == null) ? null : (muacCm * 10).round();

      final payload = <String, dynamic>{
        // Caregiver
        'caregiverName': _caregiverName.text.trim(),
        'caregiverContacts': _caregiverContacts.text.trim(),
        'caregiverVillage': _caregiverVillage.text.trim(),

        // Child
        'childFirstName': _childFirstName.text.trim(),
        'childLastName': _childLastName.text.trim(),
        'sex': _sex,
        'dateOfBirth': _dob!.toIso8601String(),
        'cwcNumber': _cwcNumber.text.trim().isEmpty ? null : _cwcNumber.text.trim(),

        // Optional CHP
        'chpName': _chpName.text.trim().isEmpty ? null : _chpName.text.trim(),
        'chpContacts': _chpContacts.text.trim().isEmpty ? null : _chpContacts.text.trim(),

        // Program (default)
        'program': 'SQLNS',

        // Embed baseline in-depth assessment in the same transaction
        'inDepthAssessment': {
          'assessedAt': DateTime.now().toIso8601String(),
          'muacMm': muacMm,
          'weightKg': weight,
          'heightCm': height,
          'householdHungerScore': hhs['score'],
          'householdHungerCategory': hhs['category'],
          'data': {
            'version': 'step8_mvp',
            'childAgeMonths': _ageInMonths(_dob),
            'anthro': {
              'weightKg': weight,
              'heightCm': height,
              'muacCm': muacCm,
            },
            'hhs': hhs,
            'pss': pss,
          },
        },
      };

      final item = SyncQueueItem.build(
        queueId: queueId,
        entityType: 'clinical_enroll',
        localEntityId: localChildId,
        method: 'POST',
        endpoint: '/api/clinical/enroll',
        operation: SyncOperation.create,
        payloadJson: jsonEncode(payload),
        idempotencyKey: queueId,
      );

      await _queueRepo.enqueue(item);

      // Try sync immediately (if online). If offline, queue remains pending.
      final result = await _syncService.syncNow();
      if (!mounted) return;

      final msg = result.online
          ? 'Saved. Sync attempted: sent ${result.sent}, failed ${result.failed}.'
          : 'Saved offline. Will sync when online.';

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

      // Show a small success sheet, then allow user to inspect queue.
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => _EnrollSuccessSheet(queueId: queueId),
      );

      if (!mounted) return;
      Navigator.pop(context);
    
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final age = _ageInMonths(_dob);
    final hhs = _computeHhs();
    final pss = _computePss();

    return WillPopScope(
      onWillPop: () async => !_saving,
      child: Scaffold(
        appBar: AcfAppBar(
        title: 'Register child',
        actions: [
          IconButton(
            tooltip: 'Queue inspector',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueInspectorScreen()),
            ),
            icon: const Icon(Icons.list_alt_outlined),
          ),
        ],
      ),
        body: Stack(
        children: [
          Column(
            children: [
              if (_saving) const LinearProgressIndicator(),
              Expanded(
                child: Form(
        key: _formKey,
        child: Stepper(
          currentStep: _step,
          onStepContinue: _saving
              ? null
              : () {
                  if (_step < 2) {
                    setState(() => _step += 1);
                  } else {
                    _submit();
                  }
                },
          onStepCancel: _saving
              ? null
              : () {
                  if (_step > 0) setState(() => _step -= 1);
                },
          controlsBuilder: (context, details) {
            final isLast = _step == 2;
            return Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: details.onStepContinue,
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(isLast ? 'Save & Queue' : 'Next'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: details.onStepCancel,
                        child: const Text('Back'),
                      ),
                    ),
                ],
              ),
            );
          },
          steps: [
            Step(
              title: const Text('Caregiver'),
              subtitle: const Text('Contacts and location'),
              isActive: _step >= 0,
              content: Column(
                children: [
                  TextFormField(
                    controller: _caregiverName,
                    decoration: const InputDecoration(labelText: 'Caregiver full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _caregiverContacts,
                    decoration: const InputDecoration(labelText: 'Caregiver phone/contact'),
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(15),
                    ],
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _caregiverVillage,
                    decoration: const InputDecoration(labelText: 'Village / settlement'),
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: cs.surfaceVariant,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Tip: We will later auto-search caregiver by contacts to avoid duplicates per facility.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Child details'),
              subtitle: const Text('Demographics + identifiers'),
              isActive: _step >= 1,
              content: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _childFirstName,
                          decoration: const InputDecoration(labelText: 'First name'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _childLastName,
                          decoration: const InputDecoration(labelText: 'Last name'),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _sex,
                          decoration: const InputDecoration(labelText: 'Sex'),
                          items: const [
                            DropdownMenuItem(value: 'M', child: Text('Male')),
                            DropdownMenuItem(value: 'F', child: Text('Female')),
                          ],
                          onChanged: (v) => setState(() => _sex = v),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: InkWell(
                          onTap: _pickDob,
                          borderRadius: BorderRadius.circular(14),
                          child: InputDecorator(
                            decoration: const InputDecoration(labelText: 'Date of birth'),
                            child: Row(
                              children: [
                                Expanded(child: Text(_fmtDob(_dob))),
                                const Icon(Icons.calendar_today_outlined, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (age != null) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Age: $age months',
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _cwcNumber,
                    decoration: const InputDecoration(labelText: 'CWC number (optional)'),
                  ),
                  const SizedBox(height: 12),
                  ExpansionTile(
                    initiallyExpanded: false,
                    title: const Text('Optional CHP details'),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: TextFormField(
                          controller: _chpName,
                          decoration: const InputDecoration(labelText: 'CHP name'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _chpContacts,
                        decoration: const InputDecoration(labelText: 'CHP contacts'),
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(15),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ],
              ),
            ),
            Step(
              title: const Text('Baseline assessment'),
              subtitle: const Text('HHS + PSS + Anthropometry'),
              isActive: _step >= 2,
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionHeader(title: 'Anthropometry', icon: Icons.monitor_weight_outlined),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _weightKg,
                          decoration: const InputDecoration(labelText: 'Weight (kg)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _heightCm,
                          decoration: const InputDecoration(labelText: 'Height/Length (cm)'),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _muacCm,
                    decoration: const InputDecoration(labelText: 'MUAC (cm)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),

                  _SectionHeader(title: 'Household Hunger Scale (HHS)', icon: Icons.restaurant_outlined),
                  const SizedBox(height: 8),
                  _YesNo(
                    label: 'In the past 30 days, was there ever NO food to eat of any kind in your household?',
                    value: _hhsQ1NoFood,
                    onChanged: (v) => setState(() {
                      _hhsQ1NoFood = v;
                      if (v == false) _hhsQ1Freq = null;
                    }),
                  ),
                  if (_hhsQ1NoFood == true)
                    _FreqPicker(
                      label: 'How often did this happen?',
                      value: _hhsQ1Freq,
                      onChanged: (v) => setState(() => _hhsQ1Freq = v),
                    ),
                  const SizedBox(height: 10),
                  _YesNo(
                    label: 'In the past 30 days, did anyone go to sleep hungry because there was not enough food?',
                    value: _hhsQ2WentToBedHungry,
                    onChanged: (v) => setState(() {
                      _hhsQ2WentToBedHungry = v;
                      if (v == false) _hhsQ2Freq = null;
                    }),
                  ),
                  if (_hhsQ2WentToBedHungry == true)
                    _FreqPicker(
                      label: 'How often did this happen?',
                      value: _hhsQ2Freq,
                      onChanged: (v) => setState(() => _hhsQ2Freq = v),
                    ),
                  const SizedBox(height: 10),
                  _YesNo(
                    label: 'In the past 30 days, did anyone go a WHOLE DAY and night without eating anything?',
                    value: _hhsQ3WholeDayNoFood,
                    onChanged: (v) => setState(() {
                      _hhsQ3WholeDayNoFood = v;
                      if (v == false) _hhsQ3Freq = null;
                    }),
                  ),
                  if (_hhsQ3WholeDayNoFood == true)
                    _FreqPicker(
                      label: 'How often did this happen?',
                      value: _hhsQ3Freq,
                      onChanged: (v) => setState(() => _hhsQ3Freq = v),
                    ),
                  const SizedBox(height: 12),
                  _ScorePill(
                    title: 'HHS Score',
                    value: '${hhs['score']} (${hhs['category']})',
                    icon: Icons.calculate_outlined,
                  ),
                  const SizedBox(height: 18),

                  _SectionHeader(title: 'Caregiver stress (PSS)', icon: Icons.psychology_outlined),
                  const SizedBox(height: 8),
                  _PssQuestion(
                    label: 'In the last month, how often have you been upset because of something that happened unexpectedly?',
                    value: _pss1,
                    onChanged: (v) => setState(() => _pss1 = v),
                  ),
                  _PssQuestion(
                    label: 'In the last month, how often have you felt unable to control important things in your life?',
                    value: _pss2,
                    onChanged: (v) => setState(() => _pss2 = v),
                  ),
                  _PssQuestion(
                    label: 'In the last month, how often have you felt nervous and stressed?',
                    value: _pss3,
                    onChanged: (v) => setState(() => _pss3 = v),
                  ),
                  _PssQuestion(
                    label: 'In the last month, how often have you felt confident about your ability to handle personal problems?',
                    value: _pss4,
                    onChanged: (v) => setState(() => _pss4 = v),
                  ),
                  _PssQuestion(
                    label: 'In the last month, how often have you felt that things were going your way?',
                    value: _pss5,
                    onChanged: (v) => setState(() => _pss5 = v),
                  ),
                  const SizedBox(height: 12),
                  _ScorePill(
                    title: 'PSS Score',
                    value: '${pss['score']} (${pss['category']})',
                    icon: Icons.calculate_outlined,
                  ),
                  const SizedBox(height: 10),
                  Card(
                    color: cs.surfaceVariant,
                    child: const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'Next: we will implement ALL questions from the Word form (WASH, IYCF, morbidity, disability, protection) + add validation rules and skip logic.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
              ),
            ],
          ),
          if (_saving)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black26,
                  alignment: Alignment.center,
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text('Saving...', style: TextStyle(fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text('Please wait', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 18, color: cs.onPrimaryContainer),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      ],
    );
  }
}

class _YesNo extends StatelessWidget {
  final String label;
  final bool? value;
  final ValueChanged<bool?> onChanged;

  const _YesNo({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: const Text('No'),
                value: false,
                groupValue: value,
                onChanged: onChanged,
              ),
            ),
            Expanded(
              child: RadioListTile<bool>(
                contentPadding: EdgeInsets.zero,
                title: const Text('Yes'),
                value: true,
                groupValue: value,
                onChanged: onChanged,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FreqPicker extends StatelessWidget {
  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  const _FreqPicker({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, top: 8),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: 'rarely', child: Text('Rarely (1–2 times)')),
          DropdownMenuItem(value: 'sometimes', child: Text('Sometimes (3–10 times)')),
          DropdownMenuItem(value: 'often', child: Text('Often (>10 times)')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _PssQuestion extends StatelessWidget {
  final String label;
  final int? value;
  final ValueChanged<int?> onChanged;

  const _PssQuestion({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DropdownButtonFormField<int>(
        value: value,
        decoration: InputDecoration(labelText: label),
        items: const [
          DropdownMenuItem(value: 0, child: Text('Never (0)')),
          DropdownMenuItem(value: 1, child: Text('Sometimes (1)')),
          DropdownMenuItem(value: 2, child: Text('Often (2)')),
        ],
        onChanged: onChanged,
      ),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _ScorePill({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const Spacer(),
          Text(value, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _EnrollSuccessSheet extends StatelessWidget {
  final String queueId;

  const _EnrollSuccessSheet({required this.queueId});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cs.secondaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.check_circle_outline, color: cs.onSecondaryContainer),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Enrollment queued',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Queue ID: $queueId',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QueueInspectorScreen()),
              );
            },
            icon: const Icon(Icons.list_alt_outlined),
            label: const Text('Open queue inspector'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
