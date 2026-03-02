import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../data/local/clinical/clinical_child_repo.dart';
import '../data/local/clinical/clinical_assessment_repo.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../data/local/isar/clinical_child.dart';
import '../data/local/isar/clinical_assessment.dart';
import 'clinical_child_detail_screen.dart';
import '../widgets/acf_brand.dart';

class ClinicalFindChildScreen extends StatefulWidget {
  const ClinicalFindChildScreen({super.key});

  @override
  State<ClinicalFindChildScreen> createState() => _ClinicalFindChildScreenState();
}

class _ClinicalFindChildScreenState extends State<ClinicalFindChildScreen> {
  final _repo = ClinicalChildRepo();
  final _assessRepo = ClinicalAssessmentRepo();
  final _settingsRepo = AppSettingsRepo();
  final _connectivity = Connectivity();
  final _uuid = const Uuid();

  final _q = TextEditingController();
  int _mode = 0; // 0=Local, 1=Server

  bool _loading = false;
  List<ClinicalChild> _results = const [];
  List<Map<String, dynamic>> _remote = const [];


  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  
Future<void> _search(String query) async {
  setState(() => _loading = true);
  try {
    if (_mode == 0) {
      final list = await _repo.search(query, limit: 50);
      if (!mounted) return;
      setState(() {
        _results = list;
        _remote = const [];
      });
    } else {
      final results = await _connectivity.checkConnectivity();
      final online = !results.contains(ConnectivityResult.none);
      if (!online) {
        if (!mounted) return;
        setState(() {
          _remote = const [];
          _results = const [];
        });
        return;
      }

      final baseUrl = await _settingsRepo.getBaseUrl();
      final api = ApiClient.create(baseUrl: baseUrl);

      final resp = await api.request(
        method: 'GET',
        path: '/api/clinical/children/search?q=${Uri.encodeQueryComponent(query)}',
      );

      final data = resp.data;
      final list = <Map<String, dynamic>>[];
      if (data is List) {
        for (final e in data) {
          if (e is Map) {
            list.add(e.cast<String, dynamic>());
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _remote = list;
        _results = const [];
      });
    }
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

Future<void> _importRemote(Map<String, dynamic> remote) async {
  try {
    final id = (remote['id'] ?? '').toString();
    if (id.isEmpty) return;

    final baseUrl = await _settingsRepo.getBaseUrl();
    final api = ApiClient.create(baseUrl: baseUrl);
    final resp = await api.request(method: 'GET', path: '/api/clinical/children/$id/summary');
    final m = (resp.data is Map) ? (resp.data as Map).cast<String, dynamic>() : null;
    if (m == null) return;
    // IMPORTANT: backend /summary returns a FLAT child object (not nested under `child`).
    // It contains a nested `caregiver` object and arrays for `inDepthAssessments` and `visits`.
    final child = m;
    final caregiver = (m['caregiver'] is Map)
        ? (m['caregiver'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    String normalizeSex(dynamic v) {
      final s = (v ?? '').toString().trim().toUpperCase();
      if (s.startsWith('F')) return 'FEMALE';
      if (s.startsWith('M')) return 'MALE';
      return 'UNKNOWN';
    }

    final remoteChildId = (child['id'] ?? id).toString();

    // If this child already exists locally (synced before), UPDATE that local record instead of
    // creating a duplicate local child.
    ClinicalChild? existing = await _repo.findByRemoteChildId(remoteChildId);
    if (existing == null) {
      final u = (child['uniqueChildNumber'] ?? '').toString().trim();
      if (u.isNotEmpty) {
        existing = await _repo.findByUniqueChildNumber(u);
      }
    }

    final localChildId = existing?.localChildId ?? _uuid.v4();

DateTime? parseDt(dynamic v) {
  if (v == null) return null;
  final s = v.toString().trim();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

    final c = existing ?? ClinicalChild()..localChildId = localChildId;

    // Only set createdAt on first create.
    c.createdAt = existing?.createdAt ?? DateTime.now();
    c.updatedAt = DateTime.now();

    c.firstName = (child['firstName'] ?? child['childFirstName'] ?? '').toString();
    c.lastName = (child['lastName'] ?? child['childLastName'] ?? '').toString();
    c.sex = normalizeSex(child['sex']);

    final cwc = (child['cwcNumber'] ?? '').toString().trim();
    c.cwcNumber = cwc.isEmpty ? null : cwc;

    c.caregiverName = (caregiver['fullName'] ?? caregiver['caregiverName'] ?? '').toString();
    c.caregiverContacts = (caregiver['contacts'] ?? caregiver['caregiverContacts'] ?? '').toString();

    final vill = (child['village'] ?? '').toString().trim();
    c.village = vill.isEmpty ? null : vill;

    c.dateOfBirth = parseDt(child['dateOfBirth'] ?? child['dob'] ?? child['date_of_birth']);
    c.enrollmentDate = parseDt(child['enrollmentDate'] ?? child['enrolledAt'] ?? child['createdAt']) ?? DateTime.now();

    c.remoteChildId = remoteChildId;

    final uniq = (child['uniqueChildNumber'] ?? '').toString().trim();
    c.uniqueChildNumber = uniq.isEmpty ? null : uniq;

    c.status = 'SYNCED';

    await _repo.upsert(c);

    // Import assessments + visits so the child detail screen is not blank.
    // 1) In-depth assessments
    final List<dynamic> ida = (m['inDepthAssessments'] is List)
        ? (m['inDepthAssessments'] as List)
        : (m['inDepthAssessment'] != null ? [m['inDepthAssessment']] : const []);

    for (final rawA in ida) {
      if (rawA is! Map) continue;
      final a = rawA.cast<String, dynamic>();

      final remoteAssessmentId = (a['id'] ?? '').toString().trim();
      final existingA = remoteAssessmentId.isEmpty ? null : await _assessRepo.findByRemoteAssessmentId(remoteAssessmentId);

      final assessmentDate = parseDt(a['assessmentDate'] ?? a['assessedAt'] ?? a['createdAt']) ?? DateTime.now();
      final assessmentType = (a['assessmentType'] ?? '').toString().toUpperCase();
      final encounterType = (assessmentType == 'DISCHARGE') ? 'DISCHARGE' : 'ENROLLMENT';

      final data = <String, dynamic>{
        'encounterType': encounterType,
        'assessmentType': assessmentType,
        'data': (a['data'] is Map) ? (a['data'] as Map).cast<String, dynamic>() : const <String, dynamic>{},
      };

      final ca = existingA ?? ClinicalAssessment()..localAssessmentId = _uuid.v4();
      ca.localChildId = localChildId;
      ca.assessmentDate = assessmentDate;
      ca.dataJson = jsonEncode(data);
      ca.muacMm = (a['muacMm'] is int) ? a['muacMm'] as int : int.tryParse('${a['muacMm']}');
      ca.weightKg = (a['weightKg'] is num) ? (a['weightKg'] as num).toDouble() : double.tryParse('${a['weightKg']}');
      ca.heightCm = (a['heightCm'] is num) ? (a['heightCm'] as num).toDouble() : double.tryParse('${a['heightCm']}');
      ca.householdHungerScore = (a['householdHungerScore'] is int) ? a['householdHungerScore'] as int : int.tryParse('${a['householdHungerScore']}');
      ca.householdHungerCategory = a['householdHungerCategory']?.toString();
      ca.pssScore = (a['pssScore'] is int) ? a['pssScore'] as int : int.tryParse('${a['pssScore']}');
      ca.pssCategory = a['pssCategory']?.toString();
      ca.status = 'SYNCED';
      ca.remoteAssessmentId = remoteAssessmentId.isEmpty ? ca.remoteAssessmentId : remoteAssessmentId;
      ca.createdAt = existingA?.createdAt ?? DateTime.now();
      ca.updatedAt = DateTime.now();

      await _assessRepo.upsert(ca);
    }

    // 2) Visits as FOLLOWUP entries (for charts/history)
    final rawVisits = (m['visits'] is List) ? (m['visits'] as List) : const [];
    for (final rv in rawVisits) {
      if (rv is! Map) continue;
      final v = rv.cast<String, dynamic>();
      final visitDate = parseDt(v['visitDate'] ?? v['date'] ?? v['createdAt']) ?? DateTime.now();

      final visitRemoteIdRaw = (v['id'] ?? '').toString().trim();
      final visitRemoteKey = visitRemoteIdRaw.isEmpty ? '' : 'visit:$visitRemoteIdRaw';
      final existingV = visitRemoteKey.isEmpty ? null : await _assessRepo.findByRemoteAssessmentId(visitRemoteKey);

      // Pick sachets from dispenses if present
      int sachets = 0;
      final disp = v['dispenses'];
      if (disp is List) {
        for (final d in disp.whereType<Map>()) {
          final mD = d.cast<String, dynamic>();
          final q = mD['quantitySachets'] ?? mD['sachetsGiven'] ?? mD['sachetsDispensed'];
          sachets += (q is int) ? q : int.tryParse('$q') ?? 0;
        }
      }

      final data = <String, dynamic>{
        'encounterType': 'FOLLOWUP',
        'visit': {
          'visitDate': visitDate.toIso8601String(),
          'quantitySachets': sachets,
        },
      };

      final ca = existingV ?? ClinicalAssessment()..localAssessmentId = _uuid.v4();
      ca.localChildId = localChildId;
      ca.assessmentDate = visitDate;
      ca.dataJson = jsonEncode(data);
      ca.muacMm = (v['muacMm'] is int) ? v['muacMm'] as int : int.tryParse('${v['muacMm']}');
      ca.weightKg = (v['weightKg'] is num) ? (v['weightKg'] as num).toDouble() : double.tryParse('${v['weightKg']}');
      ca.heightCm = (v['heightCm'] is num) ? (v['heightCm'] as num).toDouble() : double.tryParse('${v['heightCm']}');
      ca.status = 'SYNCED';
      ca.remoteAssessmentId = visitRemoteKey.isEmpty ? ca.remoteAssessmentId : visitRemoteKey;
      ca.createdAt = existingV?.createdAt ?? DateTime.now();
      ca.updatedAt = DateTime.now();
      await _assessRepo.upsert(ca);
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ClinicalChildDetailScreen(localChildId: localChildId)),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
  }
}

@override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: const AcfAppBar(title: 'Find child'),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<int>(
                    segments: const [
                      ButtonSegment(value: 0, label: Text('Local')),
                      ButtonSegment(value: 1, label: Text('Server')),
                    ],
                    selected: <int>{_mode},
                    onSelectionChanged: (s) {
                      setState(() => _mode = s.first);
                      _search(_q.text.trim());
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _q,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search by name, CWC number, caregiver, phone…',
                suffixIcon: _q.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _q.clear();
                          _search('');
                          setState(() {});
                        },
                      ),
              ),
              onChanged: (v) {
                setState(() {});
                _search(v);
              },
            ),
            const SizedBox(height: 12),
Expanded(
  child: _loading
      ? const Center(child: CircularProgressIndicator())
      : (_mode == 0)
          ? (_results.isEmpty
              ? Center(child: Text('No matches', style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final c = _results[i];
                    return ListTile(
                      tileColor: cs.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('${c.firstName} ${c.lastName}', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        [
                          if ((c.uniqueChildNumber ?? '').isNotEmpty) 'Reg#: ${c.uniqueChildNumber}',
                          if ((c.cwcNumber ?? '').isNotEmpty) 'CWC: ${c.cwcNumber}',
                          'Caregiver: ${c.caregiverName}',
                          if ((c.caregiverContacts).isNotEmpty) 'Tel: ${c.caregiverContacts}',
                        ].join(' • '),
                      ),
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
                ))
          : (_remote.isEmpty
              ? Center(
                  child: Text(
                    'No server matches (or offline)',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                )
              : ListView.separated(
                  itemCount: _remote.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = _remote[i];
                    final fn = (r['firstName'] ?? r['childFirstName'] ?? '').toString();
                    final ln = (r['lastName'] ?? r['childLastName'] ?? '').toString();
                    final cwc = (r['cwcNumber'] ?? '').toString();
                    final reg = (r['uniqueChildNumber'] ?? '').toString();
                    return ListTile(
                      tileColor: cs.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('$fn $ln', style: const TextStyle(fontWeight: FontWeight.w900)),
                      subtitle: Text(
                        [
                          if (reg.isNotEmpty) 'Reg#: $reg',
                          if (cwc.isNotEmpty) 'CWC: $cwc',
                        ].join(' • '),
                      ),
                      trailing: IconButton(
                        tooltip: 'Download to device',
                        icon: const Icon(Icons.download),
                        onPressed: () => _importRemote(r),
                      ),
                    );
                  },
                )),
),
          ],
        ),
      ),
    );
  }
}
