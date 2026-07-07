import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../core/sync/sync_service.dart';
import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/local/isar/sync_queue_item.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/clinical_remote_sync_service.dart';
import '../widgets/acf_brand.dart';

class ClinicalEditChildScreen extends StatefulWidget {
  final String localChildId;

  const ClinicalEditChildScreen({super.key, required this.localChildId});

  @override
  State<ClinicalEditChildScreen> createState() => _ClinicalEditChildScreenState();
}

class _ClinicalEditChildScreenState extends State<ClinicalEditChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final _childRepo = ClinicalChildRepo();
  final _queueRepo = SyncQueueRepo();
  final _remoteSync = ClinicalRemoteSyncService();
  final _syncService = SyncService();
  final _connectivity = Connectivity();
  final _uuid = const Uuid();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _caregiverName = TextEditingController();
  final _caregiverContacts = TextEditingController();
  final _village = TextEditingController();
  final _cwcNumber = TextEditingController();
  final _chpName = TextEditingController();
  final _chpContacts = TextEditingController();

  ClinicalChild? _child;
  DateTime? _dob;
  DateTime? _enrollmentDate;
  String _sex = 'UNKNOWN';
  bool _loading = true;
  bool _saving = false;
  bool _submitted = false;
  String? _dobError;
  String? _enrollmentDateError;

  bool get _hasRemoteChild => (_child?.remoteChildId ?? '').trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _caregiverName.dispose();
    _caregiverContacts.dispose();
    _village.dispose();
    _cwcNumber.dispose();
    _chpName.dispose();
    _chpContacts.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final child = await _childRepo.findByLocalId(widget.localChildId);
    if (!mounted) return;
    if (child != null) {
      _child = child;
      _firstName.text = child.firstName;
      _lastName.text = child.lastName;
      _caregiverName.text = child.caregiverName;
      _caregiverContacts.text = child.caregiverContacts;
      _village.text = child.village ?? '';
      _cwcNumber.text = child.cwcNumber ?? '';
      _chpName.text = child.chpName ?? '';
      _chpContacts.text = child.chpContacts ?? '';
      _dob = child.dateOfBirth;
      _enrollmentDate = child.enrollmentDate;
      _sex = child.sex;
    }
    setState(() => _loading = false);
  }

  Future<void> _pickDob() async {
    final initial = _dob ?? DateTime.now().subtract(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2018),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobError = null;
      _enrollmentDateError = null;
      if (_enrollmentDate != null && _enrollmentDate!.isBefore(picked)) {
        _enrollmentDate = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _pickEnrollmentDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final first = _dob == null ? DateTime(now.year - 3, 1, 1) : DateTime(_dob!.year, _dob!.month, _dob!.day);
    final current = _enrollmentDate ?? today;
    final initial = current.isBefore(first)
        ? first
        : current.isAfter(today)
            ? today
            : current;

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
    final today = DateTime(now.year, now.month, now.day);
    String? dobError;
    String? enrollmentError;

    if (_dob == null) {
      dobError = 'Date of birth is required.';
    }
    if (_enrollmentDate == null) {
      enrollmentError = 'Enrollment date is required.';
    }

    if (_dob != null && _enrollmentDate != null) {
      final dobDay = DateTime(_dob!.year, _dob!.month, _dob!.day);
      final enrollmentDay = DateTime(_enrollmentDate!.year, _enrollmentDate!.month, _enrollmentDate!.day);
      if (enrollmentDay.isAfter(today)) {
        enrollmentError = 'Enrollment date cannot be in the future.';
      } else if (enrollmentDay.isBefore(dobDay)) {
        enrollmentError = 'Enrollment date cannot be before date of birth.';
      } else {
        final ageMonths = _ageInMonths(dobDay, enrollmentDay);
        if (ageMonths < 6 || ageMonths > 23) {
          enrollmentError = 'Child must be 6–23 months at enrollment. Current age at enrollment: $ageMonths months.';
        }
      }
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

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);

    final formOk = _formKey.currentState?.validate() ?? false;
    final datesOk = _validateDateFields();
    if (!formOk || !datesOk) return;

    final child = _child;
    if (child == null) return;

    final payload = _buildUpdatePayload();

    setState(() => _saving = true);
    try {
      if (_hasRemoteChild) {
        final results = await _connectivity.checkConnectivity();
        final online = !results.contains(ConnectivityResult.none);

        if (online) {
          final localChildId = await _remoteSync.updateRemoteChild(
            remoteChildId: child.remoteChildId!,
            payload: payload,
          );
          if (!mounted) return;
          Navigator.pop(context, localChildId);
          return;
        }

        _applyPayloadToLocalChild(child);
        await _childRepo.upsert(child);
        await _queueRemoteChildUpdate(child, payload);
        await _syncService.syncNow(ignoreBackoff: true);

        if (!mounted) return;
        Navigator.pop(context, child.localChildId);
        return;
      }

      // Local child not yet on the server: update the local child and any queued
      // enrollment payload so the corrected details are sent during enrollment sync.
      _applyPayloadToLocalChild(child);
      await _childRepo.upsert(child);
      await _updateQueuedEnrollmentPayload(child);

      if (!mounted) return;
      Navigator.pop(context, child.localChildId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Map<String, dynamic> _buildUpdatePayload() {
    return {
      'firstName': _firstName.text.trim(),
      'lastName': _lastName.text.trim(),
      'sex': _sex,
      'dateOfBirth': _fmtDate(_dob!),
      'enrollmentDate': _fmtDate(_enrollmentDate!),
      'cwcNumber': _cwcNumber.text.trim(),
      'caregiverName': _caregiverName.text.trim(),
      'caregiverContacts': _caregiverContacts.text.trim(),
      'village': _village.text.trim(),
      'chpName': _chpName.text.trim(),
      'chpContacts': _chpContacts.text.trim(),
    };
  }

  void _applyPayloadToLocalChild(ClinicalChild child) {
    child.firstName = _firstName.text.trim();
    child.lastName = _lastName.text.trim();
    child.sex = _sex;
    child.dateOfBirth = _dob;
    child.enrollmentDate = DateTime(_enrollmentDate!.year, _enrollmentDate!.month, _enrollmentDate!.day);
    child.cwcNumber = _cwcNumber.text.trim().isEmpty ? null : _cwcNumber.text.trim();
    child.caregiverName = _caregiverName.text.trim();
    child.caregiverContacts = _caregiverContacts.text.trim();
    child.village = _village.text.trim().isEmpty ? null : _village.text.trim();
    child.chpName = _chpName.text.trim().isEmpty ? null : _chpName.text.trim();
    child.chpContacts = _chpContacts.text.trim().isEmpty ? null : _chpContacts.text.trim();
    child.updatedAt = DateTime.now();
  }

  Future<void> _queueRemoteChildUpdate(ClinicalChild child, Map<String, dynamic> payload) async {
    final item = SyncQueueItem.build(
      queueId: 'child-update-${child.localChildId}',
      entityType: 'clinical_child_update',
      localEntityId: child.localChildId,
      dependsOnLocalEntityId: child.localChildId,
      method: 'PATCH',
      endpoint: '/api/clinical/children/{childId}',
      operation: SyncOperation.update,
      payloadJson: jsonEncode(payload),
      idempotencyKey: 'child-update-${child.localChildId}-${_uuid.v4()}',
    );
    await _queueRepo.enqueueOrReplace(item);
  }

  Future<void> _updateQueuedEnrollmentPayload(ClinicalChild child) async {
    final item = await _queueRepo.findLatestForEntity('clinical_enroll', child.localChildId);
    if (item == null || (item.payloadJson ?? '').trim().isEmpty) return;

    try {
      final payload = (jsonDecode(item.payloadJson!) as Map).cast<String, dynamic>();
      payload['caregiverName'] = child.caregiverName;
      payload['caregiverContacts'] = child.caregiverContacts;
      payload['village'] = child.village;
      payload['childFirstName'] = child.firstName;
      payload['childLastName'] = child.lastName;
      payload['sex'] = child.sex;
      payload['dateOfBirth'] = child.dateOfBirth == null ? null : _fmtDate(child.dateOfBirth!);
      payload['enrollmentDate'] = _fmtDate(child.enrollmentDate);
      payload['cwcNumber'] = child.cwcNumber;
      payload['chpName'] = child.chpName;
      payload['chpContacts'] = child.chpContacts;

      item.payloadJson = jsonEncode(payload);
      item.status = SyncStatus.pending;
      item.attempts = 0;
      item.lastAttemptAt = null;
      item.lastError = null;
      await _queueRepo.enqueueOrReplace(item);
    } catch (_) {
      // If the queued payload cannot be decoded, keep the local edit. The user can
      // still re-open the child and sync queue for review.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_child == null) {
      return const Scaffold(body: Center(child: Text('Child not found')));
    }

    return Scaffold(
      appBar: const AcfAppBar(title: 'Edit enrollment details'),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
            child: ListView(
              padding: const EdgeInsets.all(16),
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
                      const Text('Enrollment and child details', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        _hasRemoteChild
                            ? 'Changes are saved to the server when online. If offline, the correction is queued and will sync automatically.'
                            : 'This child is not yet synced. Changes will update the local enrollment record and any pending enrollment queue item.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _DatePickerTile(
                  icon: Icons.event_available_outlined,
                  label: 'Enrollment date *',
                  value: _enrollmentDate == null ? 'Tap to pick' : _fmtDate(_enrollmentDate!),
                  errorText: _enrollmentDateError,
                  onTap: _pickEnrollmentDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Child first name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Child first name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Child last name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Child last name is required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(labelText: 'Sex *'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                  ],
                  onChanged: (v) => setState(() => _sex = v ?? 'UNKNOWN'),
                ),
                const SizedBox(height: 12),
                _DatePickerTile(
                  icon: Icons.cake_outlined,
                  label: 'Date of birth *',
                  value: _dob == null ? 'Tap to pick' : _fmtDate(_dob!),
                  errorText: _dobError,
                  onTap: _pickDob,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cwcNumber,
                  decoration: const InputDecoration(labelText: 'CWC number *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'CWC number is required' : null,
                ),
                const SizedBox(height: 20),
                const Text('Caregiver', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caregiverName,
                  decoration: const InputDecoration(labelText: 'Caregiver name *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Caregiver name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caregiverContacts,
                  decoration: const InputDecoration(labelText: 'Caregiver contacts *'),
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Caregiver contact is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _village,
                  decoration: const InputDecoration(labelText: 'Village'),
                ),
                const SizedBox(height: 20),
                const Text('CHP details', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _chpName,
                  decoration: const InputDecoration(labelText: 'CHP name'),
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
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save enrollment details'),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
          if (_saving)
            const Positioned(top: 0, left: 0, right: 0, child: LinearProgressIndicator()),
        ],
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
