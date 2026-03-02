import 'dart:math' as math;

import 'growth_loader.dart';
import 'growth_models.dart';

class WhzResult {
  final double? z;
  final GrowthRefType? refType;
  final bool outOfRange;
  final String? note;

  const WhzResult({required this.z, required this.refType, required this.outOfRange, this.note});
}

/// Computes Weight-for-(Length/Height) z-score (WHZ) using WHO LMS parameters.
///
/// Selection logic:
/// - If ageMonths is known: <24 => WFL, otherwise WFH.
/// - If ageMonths is unknown: fallback using height threshold (approx 87cm).
///
/// Returns null z-score when required fields are missing.
class WhzCalculator {
  const WhzCalculator();

  Future<WhzResult> compute({
    required GrowthSex sex,
    required double? heightCm,
    required double? weightKg,
    required int? ageMonths,
  }) async {
    if (heightCm == null || weightKg == null) {
      return const WhzResult(z: null, refType: null, outOfRange: false);
    }

    GrowthRefType type;
    String? note;
    if (ageMonths != null) {
      type = ageMonths < 24 ? GrowthRefType.wfl : GrowthRefType.wfh;
    } else {
      // Fallback: approximate boundary between <2y (length) and >=2y (height)
      type = heightCm < 87 ? GrowthRefType.wfl : GrowthRefType.wfh;
      note = 'Age missing: reference selected using height threshold.';
    }

    final ds = await GrowthLoader.instance.load(GrowthRefKey(sex, type));
    if (ds.rows.isEmpty) {
      return WhzResult(z: null, refType: type, outOfRange: false, note: 'Reference table not loaded');
    }

    // Find bounding rows for interpolation.
    final x = heightCm;
    final rows = ds.rows;
    bool outOfRange = false;

    if (x <= rows.first.x) {
      outOfRange = x < rows.first.x;
      final z = _zFromLms(weightKg, rows.first.L, rows.first.M, rows.first.S);
      return WhzResult(z: z, refType: type, outOfRange: outOfRange, note: note);
    }
    if (x >= rows.last.x) {
      outOfRange = x > rows.last.x;
      final z = _zFromLms(weightKg, rows.last.L, rows.last.M, rows.last.S);
      return WhzResult(z: z, refType: type, outOfRange: outOfRange, note: note);
    }

    // Binary search.
    int lo = 0;
    int hi = rows.length - 1;
    while (lo <= hi) {
      final mid = (lo + hi) >> 1;
      final v = rows[mid].x;
      if (v == x) {
        final z = _zFromLms(weightKg, rows[mid].L, rows[mid].M, rows[mid].S);
        return WhzResult(z: z, refType: type, outOfRange: false, note: note);
      }
      if (v < x) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    final i1 = math.max(0, hi);
    final i2 = math.min(rows.length - 1, hi + 1);
    final r1 = rows[i1];
    final r2 = rows[i2];
    final t = (x - r1.x) / (r2.x - r1.x);

    final L = _lerp(r1.L, r2.L, t);
    final M = _lerp(r1.M, r2.M, t);
    final S = _lerp(r1.S, r2.S, t);
    final z = _zFromLms(weightKg, L, M, S);
    return WhzResult(z: z, refType: type, outOfRange: false, note: note);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  static double _zFromLms(double x, double L, double M, double S) {
    if (S == 0) return double.nan;
    if (L.abs() < 1e-12) {
      return math.log(x / M) / S;
    }
    return (math.pow(x / M, L) - 1) / (L * S);
  }
}
