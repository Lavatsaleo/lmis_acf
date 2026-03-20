import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/isar/clinical_child.dart';
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
  final _remoteSync = ClinicalRemoteSyncService();
  final _connectivity = Connectivity();

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
  String _sex = 'UNKNOWN';
  bool _loading = true;
  bool _saving = false;

  bool get _canEditSyncedChild {
    final c = _child;
    if (c == null) return false;
    return (c.remoteChildId ?? '').trim().isNotEmpty && c.status == 'SYNCED';
  }

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
    setState(() => _dob = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth.')),
      );
      return;
    }

    final child = _child;
    if (child == null) return;
    if (!_canEditSyncedChild) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only synced children can be edited here.')),
      );
      return;
    }

    final results = await _connectivity.checkConnectivity();
    final online = !results.contains(ConnectivityResult.none);
    if (!online) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Editing synced child details requires internet connection.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final localChildId = await _remoteSync.updateRemoteChild(
        remoteChildId: child.remoteChildId!,
        payload: {
          'firstName': _firstName.text.trim(),
          'lastName': _lastName.text.trim(),
          'sex': _sex,
          'dateOfBirth': _fmtDate(_dob!),
          'cwcNumber': _cwcNumber.text.trim(),
          'caregiverName': _caregiverName.text.trim(),
          'caregiverContacts': _caregiverContacts.text.trim(),
          'village': _village.text.trim(),
          'chpName': _chpName.text.trim(),
          'chpContacts': _chpContacts.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.pop(context, localChildId);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
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

    if (_child == null) {
      return const Scaffold(body: Center(child: Text('Child not found')));
    }

    return Scaffold(
      appBar: const AcfAppBar(title: 'Edit child'),
      body: Stack(
        children: [
          Form(
            key: _formKey,
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
                      const Text('Synced child edit', style: TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 6),
                      Text(
                        _canEditSyncedChild
                            ? 'These changes are saved online first, then refreshed back into this phone.'
                            : 'This screen is only for children who are already synced to the server.',
                        style: TextStyle(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _firstName,
                  decoration: const InputDecoration(labelText: 'Child first name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _lastName,
                  decoration: const InputDecoration(labelText: 'Child last name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: const InputDecoration(labelText: 'Sex'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    DropdownMenuItem(value: 'UNKNOWN', child: Text('Unknown')),
                  ],
                  onChanged: _canEditSyncedChild ? (v) => setState(() => _sex = v ?? 'UNKNOWN') : null,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _canEditSyncedChild ? _pickDob : null,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of birth',
                      suffixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(_dob == null ? 'Select date' : _fmtDate(_dob!)),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _cwcNumber,
                  decoration: const InputDecoration(labelText: 'CWC number'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 20),
                const Text('Caregiver', style: TextStyle(fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caregiverName,
                  decoration: const InputDecoration(labelText: 'Caregiver name'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _caregiverContacts,
                  decoration: const InputDecoration(labelText: 'Caregiver contacts'),
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _canEditSyncedChild && !_saving ? _save : null,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save changes'),
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
