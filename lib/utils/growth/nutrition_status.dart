/// Nutrition status used in the UI for wasting classification.
///
/// Severity order (most severe first):
/// Severe wasting -> Moderate wasting -> At risk -> Normal.
enum NutritionStatus {
  severeWasting,
  moderateWasting,
  atRiskOfWasting,
  normal,
  unknown,
}

extension NutritionStatusLabel on NutritionStatus {
  String get label {
    switch (this) {
      case NutritionStatus.severeWasting:
        return 'Severe Wasting';
      case NutritionStatus.moderateWasting:
        return 'Moderate Wasting';
      case NutritionStatus.atRiskOfWasting:
        return 'At risk of Wasting';
      case NutritionStatus.normal:
        return 'Normal';
      case NutritionStatus.unknown:
        return 'Unknown';
    }
  }

  int get severityRank {
    switch (this) {
      case NutritionStatus.severeWasting:
        return 0;
      case NutritionStatus.moderateWasting:
        return 1;
      case NutritionStatus.atRiskOfWasting:
        return 2;
      case NutritionStatus.normal:
        return 3;
      case NutritionStatus.unknown:
        return 99;
    }
  }
}

NutritionStatus classifyByWhz(double? whz) {
  if (whz == null || whz.isNaN || whz.isInfinite) return NutritionStatus.unknown;
  if (whz < -3) return NutritionStatus.severeWasting;
  if (whz < -2) return NutritionStatus.moderateWasting;
  if (whz < -1) return NutritionStatus.atRiskOfWasting;
  return NutritionStatus.normal;
}

NutritionStatus classifyByMuac(int? muacMm) {
  if (muacMm == null) return NutritionStatus.unknown;
  if (muacMm < 115) return NutritionStatus.severeWasting;
  if (muacMm < 125) return NutritionStatus.moderateWasting;
  if (muacMm < 135) return NutritionStatus.atRiskOfWasting;
  return NutritionStatus.normal;
}

/// When WHZ and MUAC disagree, pick the most severe.
NutritionStatus mostSevere(NutritionStatus a, NutritionStatus b) {
  return a.severityRank <= b.severityRank ? a : b;
}
