import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../core/session/active_facility_context.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../widgets/acf_brand.dart';
import 'clinical_child_detail_screen.dart';
import 'clinical_enrollment_visit_screen.dart';

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
  Map<String, dynamic>? _duplicateReview;
  bool _submitted = false;
  String? _dobError;
  String? _enrollmentDateError;

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

  ActiveFacilityContext get _facilityContext => ActiveFacilityScope.fromUser(_user);

  String get _effectiveFacilityCode {
    final manual = _facilityCode.text.trim();
    if (manual.isNotEmpty) return manual;
    return _facilityContext.facilityCode;
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
      _dobError = null;
      _enrollmentDateError = null;
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
    setState(() {
      _enrollmentDate = picked;
      _enrollmentDateError = null;
    });
  }

  bool _validateDateFields() {
    final now = DateTime.now();
    final todayDay = DateTime(now.year, now.month, now.day);
    final enrollmentDay = DateTime(_enrollmentDate.year, _enrollmentDate.month, _enrollmentDate.day);

    String? dobError;
    String? enrollmentError;

    if (_dob == null) {
      dobError = 'Date of birth is required.';
    } else {
      final dobDay = DateTime(_dob!.year, _dob!.month, _dob!.day);
      if (enrollmentDay.isBefore(dobDay)) {
        enrollmentError = 'Enrollment date cannot be before date of birth.';
      }
    }

    if (enrollmentDay.isAfter(todayDay)) {
      enrollmentError = 'Enrollment date cannot be in the future.';
    }

    setState(() {
      _dobError = dobError;
      _enrollmentDateError = enrollmentError;
    });

    return dobError == null && enrollmentError == null;
  }

  int _ageInMonths(DateTime dob, DateTime onDate) {
    int months = (onDate.year - dob.year) * 12 + (onDate.month - dob.month);
    if (onDate.day < dob.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  Future<void> _continueToEnrollmentVisit() async {
    if (_saving) return;

    setState(() => _submitted = true);

    final formOk = _formKey.currentState?.validate() ?? false;
    final datesOk = _validateDateFields();
    if (!formOk || !datesOk) return;

    final enrollmentDay = DateTime(_enrollmentDate.year, _enrollmentDate.month, _enrollmentDate.day);

    // Programme eligibility: only children 6–23 months are eligible for enrollment.
    final ageMonths = _ageInMonths(_dob!, enrollmentDay);
    if (ageMonths < 6 || ageMonths > 23) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('This programme is for children 6–23 months at enrollment. Child was $ageMonths months old on ${_fmtDate(enrollmentDay)}.')),
      );
      return;
    }

    final cwc = _cwcNumber.text.trim();

    // Same-facility local duplicate: open the existing record. This still lets the
    // user continue service delivery, but prevents two local records for the same
    // CWC in the same facility.
    if (cwc.isNotEmpty) {
      final existing = await _childRepo.findByCwcNumber(cwc, facilityCode: _effectiveFacilityCode);
      if (existing != null) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Child already enrolled here'),
            content: Text('A child with CWC number "$cwc" already exists locally for this facility. Open the existing record and continue from there.'),
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

    // Cross-facility duplicate check: non-blocking.
    // If online, show possible matches and let the user choose Same child,
    // Different child, or Not sure. The answer is stored in the enrollment payload
    // so the dashboard can review later. If offline/check fails, continue.
    final duplicateReview = await _runDuplicateCheck();
    if (!mounted) return;
    if ((duplicateReview?['status'] ?? '') == 'CANCELLED_AFTER_DUPLICATE_REVIEW') {
      return;
    }
    _duplicateReview = duplicateReview;

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
        ..facilityCode = _effectiveFacilityCode.isEmpty ? null : _effectiveFacilityCode
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

  Future<Map<String, dynamic>?> _runDuplicateCheck() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final online = !results.contains(ConnectivityResult.none);
      if (!online) {
        return {
          'status': 'PENDING_SERVER_CHECK',
          'reason': 'Device was offline during enrollment.',
          'checkedAt': DateTime.now().toIso8601String(),
        };
      }

      final params = <String, String>{
        if (_cwcNumber.text.trim().isNotEmpty) 'cwcNumber': _cwcNumber.text.trim(),
        if (_firstName.text.trim().isNotEmpty) 'firstName': _firstName.text.trim(),
        if (_lastName.text.trim().isNotEmpty) 'lastName': _lastName.text.trim(),
        if (_dob != null) 'dateOfBirth': _fmtDate(_dob!),
        if (_sex.trim().isNotEmpty) 'sex': _sex.trim(),
        if (_caregiverName.text.trim().isNotEmpty) 'caregiverName': _caregiverName.text.trim(),
        if (_caregiverContacts.text.trim().isNotEmpty) 'caregiverContacts': _caregiverContacts.text.trim(),
        if (_village.text.trim().isNotEmpty) 'village': _village.text.trim(),
        if (_effectiveFacilityCode.trim().isNotEmpty) 'facilityCode': _effectiveFacilityCode.trim(),
      };

      if (params.length <= 1 && !params.containsKey('cwcNumber')) return null;

      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);
      final query = Uri(queryParameters: params).query;

      final resp = await api.request(
        method: 'GET',
        path: '/api/clinical/children/duplicate-check?$query',
      );

      final statusCode = resp.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) return null;

      final data = resp.data;
      final matches = _extractDuplicateMatches(data);
      if (matches.isEmpty) {
        return {
          'status': 'CHECKED_NO_MATCH',
          'checkedAt': DateTime.now().toIso8601String(),
        };
      }

      if (!mounted) return null;
      final decision = await _showDuplicateDialog(matches);
      if (decision == null) {
        return {
          'status': 'CANCELLED_AFTER_DUPLICATE_REVIEW',
          'checkedAt': DateTime.now().toIso8601String(),
          'candidateCount': matches.length,
          'candidateIds': matches.map((m) => (m['childId'] ?? m['id'] ?? '').toString()).where((v) => v.isNotEmpty).take(10).toList(),
        };
      }

      return {
        'status': 'POSSIBLE_DUPLICATE_REVIEWED_ON_MOBILE',
        'userDecision': decision,
        'checkedAt': DateTime.now().toIso8601String(),
        'candidateCount': matches.length,
        'candidateIds': matches.map((m) => (m['childId'] ?? m['id'] ?? '').toString()).where((v) => v.isNotEmpty).take(10).toList(),
        'topCandidate': _compactDuplicateCandidate(matches.first),
      };
    } catch (_) {
      // Never block enrollment because duplicate check failed. This is an offline-first service delivery app.
      return {
        'status': 'PENDING_SERVER_CHECK',
        'reason': 'Duplicate check failed or timed out.',
        'checkedAt': DateTime.now().toIso8601String(),
      };
    }
  }

  List<Map<String, dynamic>> _extractDuplicateMatches(dynamic data) {
    dynamic raw;
    if (data is Map) raw = data['matches'];
    if (raw == null && data is List) raw = data;
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .where((m) => ((m['score'] as num?)?.toDouble() ?? 0) >= 25)
        .take(5)
        .toList();
  }

  Map<String, dynamic> _compactDuplicateCandidate(Map<String, dynamic> m) {
    return {
      'childId': (m['childId'] ?? m['id'] ?? '').toString(),
      'facilityName': (m['facilityName'] ?? '').toString(),
      'facilityCode': (m['facilityCode'] ?? '').toString(),
      'childName': (m['childName'] ?? '').toString(),
      'cwcNumber': (m['cwcNumber'] ?? '').toString(),
      'dateOfBirth': (m['dateOfBirth'] ?? '').toString(),
      'sex': (m['sex'] ?? '').toString(),
      'score': m['score'],
      'reasons': m['reasons'],
    };
  }

  Future<String?> _showDuplicateDialog(List<Map<String, dynamic>> matches) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Possible duplicate found'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The system found a child with similar details. Review the details below. You can still continue recording services; this will be flagged for dashboard review.',
                  ),
                  const SizedBox(height: 12),
                  for (final match in matches.take(3)) _DuplicateCandidateCard(match: match),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, null),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'DIFFERENT_CHILD'),
              child: const Text('Different child'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'NOT_SURE'),
              child: const Text('Not sure'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, 'SAME_CHILD'),
              child: const Text('Same child'),
            ),
          ],
        );
      },
    );
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
      if (_duplicateReview != null) 'duplicateReview': _duplicateReview,
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
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Section(title: 'Enrollment'),
              _DatePickerTile(
                icon: Icons.event_available_outlined,
                label: 'Enrollment date *',
                value: _fmtDate(_enrollmentDate),
                errorText: _enrollmentDateError,
                onTap: _pickEnrollmentDate,
              ),
              const SizedBox(height: 6),
              Text(
                'Use the actual date the child entered the programme. This can be backdated for paper records.',
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 16),
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
                decoration: const InputDecoration(labelText: 'Caregiver contacts (phone) *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Caregiver contact is required' : null,
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
                decoration: const InputDecoration(labelText: 'Sex *'),
              ),
              const SizedBox(height: 10),
              _DatePickerTile(
                icon: Icons.cake_outlined,
                label: 'Date of birth *',
                value: _dob == null ? 'Tap to pick' : _fmtDate(_dob!),
                errorText: _dobError,
                onTap: _pickDob,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cwcNumber,
                decoration: const InputDecoration(labelText: 'CWC number *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'CWC number is required' : null,
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

class _DatePickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final String? errorText;

  const _DatePickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: errorText == null ? cs.outlineVariant : cs.error),
              color: cs.surface,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: errorText == null ? null : cs.error),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$label: $value',
                    style: TextStyle(
                      color: errorText == null ? cs.onSurface : cs.error,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(Icons.edit_calendar),
              ],
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              errorText!,
              style: TextStyle(color: cs.error, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ],
    );
  }
}

class _DuplicateCandidateCard extends StatelessWidget {
  final Map<String, dynamic> match;

  const _DuplicateCandidateCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reasons = match['reasons'];
    final reasonsText = reasons is List ? reasons.map((e) => e.toString()).join(', ') : reasons?.toString() ?? '';

    String value(String key) => (match[key] ?? '').toString().trim();

    final childName = value('childName').isNotEmpty
        ? value('childName')
        : '${value('firstName')} ${value('lastName')}'.trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  childName.isEmpty ? 'Possible matching child' : childName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              if (match['score'] != null)
                Text('Score ${match['score']}', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          _kv('Facility', [value('facilityName'), value('facilityCode')].where((v) => v.isNotEmpty).join(' • ')),
          _kv('CWC number', value('cwcNumber')),
          _kv('Sex / DOB', [value('sex'), value('dateOfBirth')].where((v) => v.isNotEmpty).join(' • ')),
          _kv('Caregiver', [value('caregiverName'), value('caregiverContactsMasked')].where((v) => v.isNotEmpty).join(' • ')),
          _kv('Village', value('village')),
          _kv('Last visit', value('lastVisitDate')),
          _kv('Last dispense', value('lastSachetsDispensed').isEmpty ? '' : '${value('lastSachetsDispensed')} sachets'),
          if (reasonsText.isNotEmpty) _kv('Why flagged', reasonsText),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    if (v.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text('$k: $v'),
    );
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
