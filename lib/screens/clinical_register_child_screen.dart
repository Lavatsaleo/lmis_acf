import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/local/auth/session_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_child.dart';
import 'clinical_child_detail_screen.dart';
import 'clinical_find_child_screen.dart';
import 'clinical_enrollment_visit_screen.dart';
import '../widgets/acf_brand.dart';

class ClinicalRegisterChildScreen extends StatefulWidget {
  const ClinicalRegisterChildScreen({super.key});

  @override
  State<ClinicalRegisterChildScreen> createState() => _ClinicalRegisterChildScreenState();
}

class _ClinicalRegisterChildScreenState extends State<ClinicalRegisterChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _session = SessionStore();
  final _settingsRepo = AppSettingsRepo();
  final _connectivity = Connectivity();
  final _childRepo = ClinicalChildRepo();
  bool _saving = false;

  // Caregiver
  final _caregiverName = TextEditingController();
  final _caregiverContacts = TextEditingController();
  final _village = TextEditingController();

  // Child
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _cwcNumber = TextEditingController();
  DateTime? _dob;
  DateTime _enrollmentDate = DateTime.now();
  String _sex = 'FEMALE';

  // CHP
  final _chpName = TextEditingController();
  final _chpContacts = TextEditingController();

  // SUPER ADMIN acting at different facility
  final _facilityCode = TextEditingController();

  Map<String, dynamic>? _user;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    // SessionStore persists the user profile as JSON.
    final u = await _session.readUserJson();
    if (!mounted) return;
    setState(() => _user = u);
  }

  bool get _isSuperAdmin {
    final r = (_user?['role'] ?? '').toString().toUpperCase();
    return r == 'SUPER_ADMIN';
  }

  bool get _needsFacilityCode {
    // Your backend resolves facility from user.facilityId. For SUPER_ADMIN without facilityId,
    // we require a facilityCode.
    final facilityId = (_user?['facilityId'] ?? '').toString();
    return _isSuperAdmin && facilityId.isEmpty;
  }

  @override
  void dispose() {
    _caregiverName.dispose();
    _caregiverContacts.dispose();
    _village.dispose();
    _firstName.dispose();
    _lastName.dispose();
    _cwcNumber.dispose();
    _chpName.dispose();
    _chpContacts.dispose();
    _facilityCode.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 1, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 18, 1, 1),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      if (_enrollmentDate.isBefore(picked)) {
        _enrollmentDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _pickEnrollmentDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = _dob == null
        ? DateTime(now.year - 3, 1, 1)
        : DateTime(_dob!.year, _dob!.month, _dob!.day);
    final initial = _enrollmentDate.isBefore(first)
        ? first
        : _enrollmentDate.isAfter(today)
            ? today
            : _enrollmentDate;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: today,
    );
    if (picked == null) return;
    setState(() => _enrollmentDate = picked);
  }

  int _ageInMonths(DateTime dob, DateTime onDate) {
    int months = (onDate.year - dob.year) * 12 + (onDate.month - dob.month);
    if (onDate.day < dob.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  Future<void> _continueToEnrollmentVisit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Date of Birth')));
      return;
    }

    final enrollmentDay = DateTime(_enrollmentDate.year, _enrollmentDate.month, _enrollmentDate.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    final dobDay = DateTime(_dob!.year, _dob!.month, _dob!.day);

    if (enrollmentDay.isAfter(todayDay)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enrollment date cannot be in the future')));
      return;
    }

    if (enrollmentDay.isBefore(dobDay)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enrollment date cannot be before date of birth')));
      return;
    }

    // Programme eligibility: only children 6–23 months are eligible for enrollment.
    final ageMonths = _ageInMonths(_dob!, enrollmentDay);
    if (ageMonths < 6 || ageMonths > 23) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This programme is for children 6–23 months at enrollment. Child was $ageMonths months old on ${_fmtDate(enrollmentDay)}.')),
      );
      return;
    }

    // Duplicate prevention (local): CWC number is treated as the unique identifier.
    final cwc = _cwcNumber.text.trim();
    if (cwc.isNotEmpty) {
      final existing = await _childRepo.findByCwcNumber(cwc);
      if (existing != null) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Child already registered'),
            content: Text('A child with CWC number "$cwc" already exists locally.\n\nOpen the existing record instead of registering again.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClinicalChildDetailScreen(localChildId: existing.localChildId),
                    ),
                  );
                },
                child: const Text('Open record'),
              ),
            ],
          ),
        );
        return;
      }
}

// Duplicate prevention (server): when online, check if this CWC already exists on the backend.
// This reduces duplicates across devices when local DB is cleared after sync.
if (cwc.isNotEmpty) {
  try {
    final results = await _connectivity.checkConnectivity();
    final online = !results.contains(ConnectivityResult.none);
    if (online) {
      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);

      final resp = await api.request(
        method: 'GET',
        path: '/api/clinical/children/search?q=${Uri.encodeQueryComponent(cwc)}',
      );

      if ((resp.statusCode ?? 0) >= 200 && (resp.statusCode ?? 0) < 300) {
        final data = resp.data;
        if (data is List) {
          final exists = data.any((e) {
            if (e is Map) {
              final v = (e['cwcNumber'] ?? '').toString().trim();
              return v.isNotEmpty && v.toLowerCase() == cwc.toLowerCase();
            }
            return false;
          });

          if (exists && mounted) {
            await showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Possible duplicate'),
                content: Text('A child with CWC number "$cwc" already exists on the server.\n\nUse Search to open the existing record instead of registering again.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const ClinicalFindChildScreen()),
                      );
                    },
                    child: const Text('Search'),
                  ),
                ],
              ),
            );
            return;
          }
        }
      }
    }
  } catch (_) {
    // If the check fails, we still allow local enrollment (offline-first).
  }
}

setState(() => _saving = true);
    try {
      final localChildId = _uuid.v4();
      final child = ClinicalChild()
        ..localChildId = localChildId
        ..caregiverName = _caregiverName.text.trim()
        ..caregiverContacts = _caregiverContacts.text.trim()
        ..village = _village.text.trim().isEmpty ? null : _village.text.trim()
        ..firstName = _firstName.text.trim()
        ..lastName = _lastName.text.trim()
        ..sex = _sex
        ..dateOfBirth = _dob
        ..cwcNumber = _cwcNumber.text.trim().isEmpty ? null : _cwcNumber.text.trim()
        ..enrollmentDate = DateTime(_enrollmentDate.year, _enrollmentDate.month, _enrollmentDate.day)
        ..chpName = _chpName.text.trim().isEmpty ? null : _chpName.text.trim()
        ..chpContacts = _chpContacts.text.trim().isEmpty ? null : _chpContacts.text.trim()
        ..facilityCode = _facilityCode.text.trim().isEmpty ? null : _facilityCode.text.trim()
        ..status = 'DRAFT'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now();

      await _childRepo.upsert(child);

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ClinicalEnrollmentVisitScreen(
            localChildId: localChildId,
            draftEnrollmentJson: jsonEncode(_buildEnrollPayload(child)),
            onFinalizeQueued: () async {
              // Mark as queued once the enrollment visit has queued the enrollment.
              child.status = 'QUEUED';
              await _childRepo.upsert(child);
            },
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Base enrollment payload. The next screen adds the simple enrollment visit and queues the enrollment.
  Map<String, dynamic> _buildEnrollPayload(ClinicalChild c) {
    String fmt(DateTime d) {
      final y = d.year.toString().padLeft(4, '0');
      final m = d.month.toString().padLeft(2, '0');
      final day = d.day.toString().padLeft(2, '0');
      return '$y-$m-$day';
    }

    return {
      'caregiverName': c.caregiverName,
      'caregiverContacts': c.caregiverContacts,
      'village': c.village,
      'childFirstName': c.firstName,
      'childLastName': c.lastName,
      'sex': c.sex,
      'dateOfBirth': c.dateOfBirth != null ? fmt(c.dateOfBirth!) : null,
      'cwcNumber': c.cwcNumber,
      'enrollmentDate': fmt(c.enrollmentDate),
      'chpName': c.chpName,
      'chpContacts': c.chpContacts,
      if (c.facilityCode != null && c.facilityCode!.isNotEmpty) 'facilityCode': c.facilityCode,
    };
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AcfAppBar(title: 'Enroll child'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(title: 'Caregiver'),
              TextFormField(
                controller: _caregiverName,
                decoration: const InputDecoration(labelText: 'Caregiver name *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _caregiverContacts,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: const InputDecoration(labelText: 'Caregiver contacts (phone)'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _village,
                decoration: const InputDecoration(labelText: 'Village / location'),
              ),

              const SizedBox(height: 16),
              _Section(title: 'Child'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _firstName,
                      decoration: const InputDecoration(labelText: 'First name *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _lastName,
                      decoration: const InputDecoration(labelText: 'Last name *'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: _sex,
                items: const [
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                ],
                onChanged: (v) => setState(() => _sex = v ?? 'UNKNOWN'),
                decoration: const InputDecoration(labelText: 'Sex'),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickDob,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                    color: cs.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _dob == null ? 'Date of birth * (tap to pick)' : 'DOB: ${_fmtDate(_dob!)}',
                          style: TextStyle(color: cs.onSurface),
                        ),
                      ),
                      const Icon(Icons.edit_calendar),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _pickEnrollmentDate,
                borderRadius: BorderRadius.circular(12),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cs.outlineVariant),
                    color: cs.surface,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_outlined, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Enrollment date: ${_fmtDate(_enrollmentDate)}',
                          style: TextStyle(color: cs.onSurface),
                        ),
                      ),
                      const Icon(Icons.edit_calendar),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Use the actual date the child entered the programme. This can be backdated for paper records.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cwcNumber,
                decoration: const InputDecoration(labelText: 'CWC number'),
              ),

              const SizedBox(height: 16),
              _Section(title: 'CHP (optional)'),
              TextFormField(
                controller: _chpName,
                decoration: const InputDecoration(labelText: 'CHP name'),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _chpContacts,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                decoration: const InputDecoration(labelText: 'CHP contacts'),
              ),

              if (_needsFacilityCode) ...[
                const SizedBox(height: 16),
                _Section(title: 'Facility (Super Admin only)'),
                TextFormField(
                  controller: _facilityCode,
                  decoration: const InputDecoration(labelText: 'Facility Code *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required for Super Admin' : null,
                ),
              ],

              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _saving ? null : _continueToEnrollmentVisit,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.arrow_forward),
                label: const Text('Continue to anthropometry & dispensing'),
              ),
              const SizedBox(height: 8),
              Text(
                'Note: We save locally first. The next screen captures only anthropometry and dispensing, then the app syncs automatically when online.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}

class _Section extends StatelessWidget {
  final String title;

  const _Section({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(99))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
