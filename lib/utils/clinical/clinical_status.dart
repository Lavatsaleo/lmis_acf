import 'dart:convert';

import '../../data/local/isar/clinical_assessment.dart';

class ClinicalMeasurement {
  final DateTime visitDate;
  final double? weightKg;
  final double? heightCm;
  final int? muacMm;
  final double? whzScore;
  final String encounterType;
  final String? localAssessmentId;

  const ClinicalMeasurement({
    required this.visitDate,
    this.weightKg,
    this.heightCm,
    this.muacMm,
    this.whzScore,
    this.encounterType = '',
    this.localAssessmentId,
  });

  static ClinicalMeasurement? fromAssessment(ClinicalAssessment a) {
    Map<String, dynamic> data;
    try {
      final decoded = jsonDecode(a.dataJson);
      if (decoded is! Map) return null;
      data = decoded.cast<String, dynamic>();
    } catch (_) {
      return null;
    }

    final anthropometry = ((data['anthropometry'] ?? data['anthropometrics']) as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
    final visit = (data['visit'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};

    final visitDate = _tryParseDate((visit['visitDate'] ?? data['visitDate'])?.toString()) ?? a.assessmentDate;
    final weightKg = _toDouble(anthropometry['weightKg'] ?? anthropometry['weight'] ?? a.weightKg);
    final heightCm = _toDouble(anthropometry['heightCm'] ?? anthropometry['height'] ?? a.heightCm);
    final muacRaw = _toDouble(anthropometry['muacMm'] ?? anthropometry['muac'] ?? a.muacMm);
    final whzScore = _toDouble(anthropometry['whzScore'] ?? anthropometry['whz'] ?? data['whzScore'] ?? data['whz']);

    return ClinicalMeasurement(
      visitDate: visitDate,
      weightKg: weightKg,
      heightCm: heightCm,
      muacMm: muacRaw == null ? null : muacRaw.round(),
      whzScore: whzScore,
      encounterType: (data['encounterType'] ?? '').toString().toUpperCase(),
      localAssessmentId: a.localAssessmentId,
    );
  }

  static DateTime? _tryParseDate(String? value) {
    final s = (value ?? '').trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString().trim());
  }
}

class ClinicalStatusResult {
  final String nutritionalStatus;
  final bool? isRecovered;
  final String recoveryStatus;
  final bool isDeteriorating;
  final String progressStatus;
  final List<String> deteriorationReasons;
  final bool isExitEligible;
  final String exitEligibilityStatus;
  final int programmeDurationDays;
  final int programmeDurationMonths;
  final bool hasCompletedSixMonths;

  const ClinicalStatusResult({
    required this.nutritionalStatus,
    required this.isRecovered,
    required this.recoveryStatus,
    required this.isDeteriorating,
    required this.progressStatus,
    required this.deteriorationReasons,
    required this.isExitEligible,
    required this.exitEligibilityStatus,
    required this.programmeDurationDays,
    required this.programmeDurationMonths,
    required this.hasCompletedSixMonths,
  });

  Map<String, dynamic> toJson() {
    return {
      'nutritionalStatus': nutritionalStatus,
      'isRecovered': isRecovered,
      'recoveryStatus': recoveryStatus,
      'isDeteriorating': isDeteriorating,
      'progressStatus': progressStatus,
      'deteriorationReasons': deteriorationReasons,
      'isExitEligible': isExitEligible,
      'exitEligibilityStatus': exitEligibilityStatus,
      'programmeDurationDays': programmeDurationDays,
      'programmeDurationMonths': programmeDurationMonths,
      'hasCompletedSixMonths': hasCompletedSixMonths,
      'recoveryCriteria': {
        'muacMmAtLeast': 135,
        'whzScoreAtLeast': -1,
      },
      'exitCriteria': {
        'requiresRecovered': true,
        'requiresProgrammeDurationMonthsAtLeast': 6,
      },
    };
  }

  List<String> get alertMessages {
    final messages = <String>[];
    if (isDeteriorating) {
      messages.add('Deterioration alert: this child is doing worse compared to the previous visit.');
    }
    if (isExitEligible) {
      messages.add('Exit eligibility alert: the child has recovered and has completed at least 6 months in the programme.');
    } else if (isRecovered == true) {
      messages.add('Recovery alert: the child has met the MUAC and WHZ recovery criteria.');
    }
    return messages;
  }
}

class ClinicalStatusCalculator {
  static const int recoveryMuacMm = 135;
  static const double recoveryWhzScore = -1;

  static ClinicalStatusResult evaluate({
    required ClinicalMeasurement current,
    required ClinicalMeasurement? previous,
    required DateTime enrollmentDate,
    required DateTime visitDate,
    required String? nutritionalStatus,
  }) {
    final normalizedEnrollment = DateTime(enrollmentDate.year, enrollmentDate.month, enrollmentDate.day);
    final normalizedVisit = DateTime(visitDate.year, visitDate.month, visitDate.day);

    final programmeDurationDays = normalizedVisit.difference(normalizedEnrollment).inDays < 0
        ? 0
        : normalizedVisit.difference(normalizedEnrollment).inDays;
    final programmeDurationMonths = _monthsBetween(normalizedEnrollment, normalizedVisit);
    final sixMonthsDate = DateTime(normalizedEnrollment.year, normalizedEnrollment.month + 6, normalizedEnrollment.day);
    final hasCompletedSixMonths = !normalizedVisit.isBefore(sixMonthsDate);

    bool? isRecovered;
    if (current.muacMm != null && current.whzScore != null) {
      isRecovered = current.muacMm! >= recoveryMuacMm && current.whzScore! >= recoveryWhzScore;
    }

    final recoveryStatus = isRecovered == null
        ? 'Cannot determine recovery'
        : isRecovered
            ? 'Recovered'
            : 'Not recovered';

    final deteriorationReasons = <String>[];
    if (previous != null) {
      if (current.weightKg != null && previous.weightKg != null && current.weightKg! < previous.weightKg!) {
        deteriorationReasons.add('Weight reduced from ${previous.weightKg!.toStringAsFixed(1)} kg to ${current.weightKg!.toStringAsFixed(1)} kg.');
      }
      if (current.muacMm != null && previous.muacMm != null && current.muacMm! < previous.muacMm!) {
        deteriorationReasons.add('MUAC reduced from ${previous.muacMm} mm to ${current.muacMm} mm.');
      }
      if (current.whzScore != null && previous.whzScore != null && current.whzScore! < previous.whzScore!) {
        deteriorationReasons.add('WHZ reduced from ${previous.whzScore!.toStringAsFixed(2)} to ${current.whzScore!.toStringAsFixed(2)}.');
      }
    }

    final isDeteriorating = deteriorationReasons.isNotEmpty;
    final progressStatus = previous == null
        ? 'No previous visit for comparison'
        : isDeteriorating
            ? 'Deteriorating'
            : 'Stable or improving';

    final isExitEligible = isRecovered == true && hasCompletedSixMonths;
    final exitEligibilityStatus = isRecovered == null
        ? 'Cannot determine exit eligibility'
        : isExitEligible
            ? 'Exit eligible'
            : isRecovered
                ? 'Recovered but not yet exit eligible'
                : 'Not exit eligible';

    return ClinicalStatusResult(
      nutritionalStatus: nutritionalStatus ?? 'Unknown',
      isRecovered: isRecovered,
      recoveryStatus: recoveryStatus,
      isDeteriorating: isDeteriorating,
      progressStatus: progressStatus,
      deteriorationReasons: deteriorationReasons,
      isExitEligible: isExitEligible,
      exitEligibilityStatus: exitEligibilityStatus,
      programmeDurationDays: programmeDurationDays,
      programmeDurationMonths: programmeDurationMonths,
      hasCompletedSixMonths: hasCompletedSixMonths,
    );
  }

  static ClinicalMeasurement? findPreviousMeasurement(
    List<ClinicalAssessment> items, {
    required DateTime beforeOrOnDate,
    String? excludeLocalAssessmentId,
  }) {
    final normalizedCurrent = DateTime(beforeOrOnDate.year, beforeOrOnDate.month, beforeOrOnDate.day, 23, 59, 59);
    final measurements = <ClinicalMeasurement>[];

    for (final item in items) {
      if (excludeLocalAssessmentId != null && item.localAssessmentId == excludeLocalAssessmentId) continue;
      final m = ClinicalMeasurement.fromAssessment(item);
      if (m == null) continue;
      final t = m.encounterType.toUpperCase();
      if (t != 'ENROLLMENT' && t != 'FOLLOWUP') continue;
      if (m.visitDate.isAfter(normalizedCurrent)) continue;
      measurements.add(m);
    }

    measurements.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return measurements.isEmpty ? null : measurements.first;
  }

  static ClinicalMeasurement? latestMeasurement(List<ClinicalAssessment> items) {
    final measurements = <ClinicalMeasurement>[];
    for (final item in items) {
      final m = ClinicalMeasurement.fromAssessment(item);
      if (m == null) continue;
      final t = m.encounterType.toUpperCase();
      if (t != 'ENROLLMENT' && t != 'FOLLOWUP') continue;
      measurements.add(m);
    }
    measurements.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    return measurements.isEmpty ? null : measurements.first;
  }

  static int _monthsBetween(DateTime start, DateTime end) {
    int months = (end.year - start.year) * 12 + (end.month - start.month);
    if (end.day < start.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }
}
