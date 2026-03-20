import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../local/clinical/clinical_assessment_repo.dart';
import '../local/clinical/clinical_child_repo.dart';
import '../local/isar/clinical_assessment.dart';
import '../local/isar/clinical_child.dart';
import '../local/settings/app_settings_repo.dart';
import 'api_client.dart';

class ClinicalRemoteSyncService {
  final ClinicalChildRepo _childRepo;
  final ClinicalAssessmentRepo _assessRepo;
  final AppSettingsRepo _settingsRepo;
  final Uuid _uuid;

  ClinicalRemoteSyncService({
    ClinicalChildRepo? childRepo,
    ClinicalAssessmentRepo? assessRepo,
    AppSettingsRepo? settingsRepo,
    Uuid? uuid,
  })  : _childRepo = childRepo ?? ClinicalChildRepo(),
        _assessRepo = assessRepo ?? ClinicalAssessmentRepo(),
        _settingsRepo = settingsRepo ?? AppSettingsRepo(),
        _uuid = uuid ?? const Uuid();

  Future<ApiClient> _api() async {
    final baseUrl = await _settingsRepo.getBaseUrl();
    return ApiClient.create(baseUrl: baseUrl);
  }

  Future<List<Map<String, dynamic>>> searchChildren(String query) async {
    final api = await _api();
    final resp = await api.request(
      method: 'GET',
      path: '/api/clinical/children/search?q=${Uri.encodeQueryComponent(query)}',
    );

    final data = resp.data;
    final list = <Map<String, dynamic>>[];
    if (data is List) {
      for (final e in data) {
        if (e is Map) list.add(e.cast<String, dynamic>());
      }
    }
    return list;
  }

  Future<List<Map<String, dynamic>>> fetchFacilityAppointments(DateTime date) async {
    final api = await _api();
    final resp = await api.request(
      method: 'GET',
      path: '/api/clinical/facility/appointments?date=${_fmtDate(date)}',
    );

    final data = _asMap(resp.data) ?? const <String, dynamic>{};
    final rows = data['rows'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<List<Map<String, dynamic>>> fetchRecentFacilityChildren({DateTime? date, int take = 50}) async {
    final api = await _api();
    final qs = <String>['take=$take'];
    if (date != null) qs.add('date=${_fmtDate(date)}');
    final resp = await api.request(
      method: 'GET',
      path: '/api/clinical/facility/children/recent?${qs.join('&')}',
    );

    final data = _asMap(resp.data) ?? const <String, dynamic>{};
    final rows = data['rows'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<String> importChildByRemoteId(String remoteChildId) async {
    final id = remoteChildId.trim();
    if (id.isEmpty) {
      throw Exception('Remote child id is required.');
    }

    final api = await _api();
    final resp = await api.request(method: 'GET', path: '/api/clinical/children/$id/summary');
    final summary = _asMap(resp.data);
    if (summary == null) {
      throw Exception('Child summary response was empty.');
    }

    return importChildSummaryMap(summary);
  }

  Future<String?> importChildSummaryByRemoteId(String remoteChildId) async {
    final id = remoteChildId.trim();
    if (id.isEmpty) return null;
    return importChildByRemoteId(id);
  }

  Future<String> updateRemoteChild({
    required String remoteChildId,
    required Map<String, dynamic> payload,
  }) async {
    final id = remoteChildId.trim();
    if (id.isEmpty) {
      throw Exception('Remote child id is required.');
    }

    final api = await _api();
    final resp = await api.request(
      method: 'PATCH',
      path: '/api/clinical/children/$id',
      data: payload,
    );

    final root = _asMap(resp.data);
    final summary = root == null
        ? null
        : (root['child'] is Map)
            ? (root['child'] as Map).cast<String, dynamic>()
            : root;

    if (summary == null) {
      throw Exception('Updated child response was empty.');
    }

    return importChildSummaryMap(summary);
  }

  Future<String> importChildSummaryMap(Map<String, dynamic> m) async {
    final child = m;
    final caregiver = (m['caregiver'] is Map)
        ? (m['caregiver'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final remoteChildId = (child['id'] ?? '').toString().trim();
    if (remoteChildId.isEmpty) {
      throw Exception('Child summary did not contain a remote id.');
    }

    final existing = await _findExistingChild(child, remoteChildId);
    final localChildId = existing?.localChildId ?? _uuid.v4();

    final c = existing ?? ClinicalChild()..localChildId = localChildId;
    c.createdAt = existing?.createdAt ?? DateTime.now();
    c.updatedAt = DateTime.now();
    c.firstName = (child['firstName'] ?? child['childFirstName'] ?? '').toString();
    c.lastName = (child['lastName'] ?? child['childLastName'] ?? '').toString();
    c.sex = _normalizeSex(child['sex']);

    final cwc = (child['cwcNumber'] ?? '').toString().trim();
    c.cwcNumber = cwc.isEmpty ? null : cwc;

    c.caregiverName = (caregiver['fullName'] ?? caregiver['caregiverName'] ?? '').toString();
    c.caregiverContacts = (caregiver['contacts'] ?? caregiver['caregiverContacts'] ?? '').toString();

    final vill = (caregiver['village'] ?? child['village'] ?? '').toString().trim();
    c.village = vill.isEmpty ? null : vill;

    c.dateOfBirth = _parseDt(child['dateOfBirth'] ?? child['dob'] ?? child['date_of_birth']);
    c.enrollmentDate = _parseDt(child['enrollmentDate'] ?? child['enrolledAt'] ?? child['createdAt']) ?? DateTime.now();
    c.remoteChildId = remoteChildId;
    c.uniqueChildNumber = _stringOrNull(child['uniqueChildNumber']);
    c.chpName = _stringOrNull(child['chpName']);
    c.chpContacts = _stringOrNull(child['chpContacts']);
    c.status = 'SYNCED';

    await _childRepo.upsert(c);

    await _importAssessments(localChildId: localChildId, summary: m);
    await _importVisits(localChildId: localChildId, summary: m);

    return localChildId;
  }

  Future<ClinicalChild?> _findExistingChild(Map<String, dynamic> child, String remoteChildId) async {
    ClinicalChild? existing = await _childRepo.findByRemoteChildId(remoteChildId);
    if (existing != null) return existing;

    final uniqueChildNumber = (child['uniqueChildNumber'] ?? '').toString().trim();
    if (uniqueChildNumber.isNotEmpty) {
      existing = await _childRepo.findByUniqueChildNumber(uniqueChildNumber);
      if (existing != null) return existing;
    }

    final cwc = (child['cwcNumber'] ?? '').toString().trim();
    if (cwc.isNotEmpty) {
      existing = await _childRepo.findByCwcNumber(cwc);
      if (existing != null) return existing;
    }

    return null;
  }

  Future<void> _importAssessments({
    required String localChildId,
    required Map<String, dynamic> summary,
  }) async {
    final List<dynamic> ida = (summary['inDepthAssessments'] is List)
        ? (summary['inDepthAssessments'] as List)
        : (summary['inDepthAssessment'] != null ? [summary['inDepthAssessment']] : const []);

    for (final rawA in ida) {
      if (rawA is! Map) continue;
      final a = rawA.cast<String, dynamic>();

      final remoteAssessmentId = (a['id'] ?? '').toString().trim();
      final existingA = remoteAssessmentId.isEmpty ? null : await _assessRepo.findByRemoteAssessmentId(remoteAssessmentId);

      final assessmentDate = _parseDt(a['assessmentDate'] ?? a['assessedAt'] ?? a['createdAt']) ?? DateTime.now();
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
      ca.muacMm = _toInt(a['muacMm']);
      ca.weightKg = _toDouble(a['weightKg']);
      ca.heightCm = _toDouble(a['heightCm']);
      ca.householdHungerScore = _toInt(a['householdHungerScore']);
      ca.householdHungerCategory = a['householdHungerCategory']?.toString();
      ca.pssScore = _toInt(a['pssScore']);
      ca.pssCategory = a['pssCategory']?.toString();
      ca.status = 'SYNCED';
      ca.remoteAssessmentId = remoteAssessmentId.isEmpty ? ca.remoteAssessmentId : remoteAssessmentId;
      ca.createdAt = existingA?.createdAt ?? DateTime.now();
      ca.updatedAt = DateTime.now();

      await _assessRepo.upsert(ca);
    }
  }

  Future<void> _importVisits({
    required String localChildId,
    required Map<String, dynamic> summary,
  }) async {
    final rawVisits = (summary['visits'] is List) ? (summary['visits'] as List) : const [];
    for (final rv in rawVisits) {
      if (rv is! Map) continue;
      final v = rv.cast<String, dynamic>();
      final visitDate = _parseDt(v['visitDate'] ?? v['date'] ?? v['createdAt']) ?? DateTime.now();

      final visitRemoteIdRaw = (v['id'] ?? '').toString().trim();
      final visitRemoteKey = visitRemoteIdRaw.isEmpty ? '' : 'visit:$visitRemoteIdRaw';
      final existingV = visitRemoteKey.isEmpty ? null : await _assessRepo.findByRemoteAssessmentId(visitRemoteKey);

      int sachets = 0;
      final disp = v['dispenses'];
      if (disp is List) {
        for (final d in disp.whereType<Map>()) {
          final md = d.cast<String, dynamic>();
          final q = md['quantitySachets'] ?? md['sachetsGiven'] ?? md['sachetsDispensed'];
          sachets += _toInt(q) ?? 0;
        }
      }

      final data = <String, dynamic>{
        'encounterType': 'FOLLOWUP',
        'visit': {
          'visitDate': visitDate.toIso8601String(),
          'quantitySachets': sachets,
          if (v['nextAppointmentDate'] != null) 'nextAppointmentDate': v['nextAppointmentDate'],
          if ((v['notes'] ?? '').toString().trim().isNotEmpty) 'notes': v['notes'].toString(),
        },
      };

      final ca = existingV ?? ClinicalAssessment()..localAssessmentId = _uuid.v4();
      ca.localChildId = localChildId;
      ca.assessmentDate = visitDate;
      ca.dataJson = jsonEncode(data);
      ca.muacMm = _toInt(v['muacMm']);
      ca.weightKg = _toDouble(v['weightKg']);
      ca.heightCm = _toDouble(v['heightCm']);
      ca.status = 'SYNCED';
      ca.remoteAssessmentId = visitRemoteKey.isEmpty ? ca.remoteAssessmentId : visitRemoteKey;
      ca.createdAt = existingV?.createdAt ?? DateTime.now();
      ca.updatedAt = DateTime.now();
      await _assessRepo.upsert(ca);
    }
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return data.cast<String, dynamic>();
    if (data is String && data.trim().isNotEmpty) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return decoded.cast<String, dynamic>();
    }
    return null;
  }

  String _normalizeSex(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s.startsWith('F')) return 'FEMALE';
    if (s.startsWith('M')) return 'MALE';
    return 'UNKNOWN';
  }

  DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse(v.toString());
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  String? _stringOrNull(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
