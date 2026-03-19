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

    final data = (resp.data is Map) ? (resp.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
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

    final data = (resp.data is Map) ? (resp.data as Map).cast<String, dynamic>() : const <String, dynamic>{};
    final rows = data['rows'];
    if (rows is! List) return const [];
    return rows.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
  }

  Future<String?> importChildSummaryByRemoteId(String remoteChildId) async {
    final id = remoteChildId.trim();
    if (id.isEmpty) return null;

    final api = await _api();
    final resp = await api.request(method: 'GET', path: '/api/clinical/children/$id/summary');
    final data = (resp.data is Map) ? (resp.data as Map).cast<String, dynamic>() : null;
    if (data == null) return null;
    return importChildSummaryMap(data);
  }

  Future<String?> importChildSummaryMap(Map<String, dynamic> m) async {
    final child = m;
    final caregiver = (m['caregiver'] is Map)
        ? (m['caregiver'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};

    final remoteChildId = (child['id'] ?? '').toString().trim();
    if (remoteChildId.isEmpty) return null;

    ClinicalChild? existing = await _childRepo.findByRemoteChildId(remoteChildId);
    if (existing == null) {
      final uniq = (child['uniqueChildNumber'] ?? '').toString().trim();
      if (uniq.isNotEmpty) {
        existing = await _childRepo.findByUniqueChildNumber(uniq);
      }
    }

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

    final vill = (child['village'] ?? '').toString().trim();
    c.village = vill.isEmpty ? null : vill;

    c.dateOfBirth = _parseDt(child['dateOfBirth'] ?? child['dob'] ?? child['date_of_birth']);
    c.enrollmentDate = _parseDt(child['enrollmentDate'] ?? child['enrolledAt'] ?? child['createdAt']) ?? DateTime.now();
    c.remoteChildId = remoteChildId;

    final uniq = (child['uniqueChildNumber'] ?? '').toString().trim();
    c.uniqueChildNumber = uniq.isEmpty ? null : uniq;
    c.status = 'SYNCED';

    await _childRepo.upsert(c);

    final List<dynamic> ida = (m['inDepthAssessments'] is List)
        ? (m['inDepthAssessments'] as List)
        : (m['inDepthAssessment'] != null ? [m['inDepthAssessment']] : const []);

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
      ca.muacMm = _asInt(a['muacMm']);
      ca.weightKg = _asDouble(a['weightKg']);
      ca.heightCm = _asDouble(a['heightCm']);
      ca.householdHungerScore = _asInt(a['householdHungerScore']);
      ca.householdHungerCategory = a['householdHungerCategory']?.toString();
      ca.pssScore = _asInt(a['pssScore']);
      ca.pssCategory = a['pssCategory']?.toString();
      ca.status = 'SYNCED';
      ca.remoteAssessmentId = remoteAssessmentId.isEmpty ? ca.remoteAssessmentId : remoteAssessmentId;
      ca.createdAt = existingA?.createdAt ?? DateTime.now();
      ca.updatedAt = DateTime.now();

      await _assessRepo.upsert(ca);
    }

    final rawVisits = (m['visits'] is List) ? (m['visits'] as List) : const [];
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
          final mD = d.cast<String, dynamic>();
          final q = mD['quantitySachets'] ?? mD['sachetsGiven'] ?? mD['sachetsDispensed'];
          sachets += _asInt(q) ?? 0;
        }
      }

      final nextAppointmentDate = (v['nextAppointmentDate'] ?? '').toString().trim();
      final data = <String, dynamic>{
        'encounterType': 'FOLLOWUP',
        'visit': {
          'visitDate': visitDate.toIso8601String(),
          'quantitySachets': sachets,
          if (nextAppointmentDate.isNotEmpty) 'nextAppointmentDate': nextAppointmentDate,
          if ((v['notes'] ?? '').toString().trim().isNotEmpty) 'notes': v['notes'].toString(),
        },
      };

      final ca = existingV ?? ClinicalAssessment()..localAssessmentId = _uuid.v4();
      ca.localChildId = localChildId;
      ca.assessmentDate = visitDate;
      ca.dataJson = jsonEncode(data);
      ca.muacMm = _asInt(v['muacMm']);
      ca.weightKg = _asDouble(v['weightKg']);
      ca.heightCm = _asDouble(v['heightCm']);
      ca.status = 'SYNCED';
      ca.remoteAssessmentId = visitRemoteKey.isEmpty ? ca.remoteAssessmentId : visitRemoteKey;
      ca.createdAt = existingV?.createdAt ?? DateTime.now();
      ca.updatedAt = DateTime.now();
      await _assessRepo.upsert(ca);
    }

    return localChildId;
  }

  static DateTime? _parseDt(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static String _normalizeSex(dynamic v) {
    final s = (v ?? '').toString().trim().toUpperCase();
    if (s.startsWith('F')) return 'FEMALE';
    if (s.startsWith('M')) return 'MALE';
    return 'UNKNOWN';
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    return int.tryParse('${v ?? ''}');
  }

  static double? _asDouble(dynamic v) {
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse('${v ?? ''}');
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
