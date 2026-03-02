/// WHO Growth Standards reference row for Weight-for-Length/Height.
///
/// `x` is length/height in cm.
/// `L`, `M`, `S` are LMS parameters.
/// `sd*` are the precomputed weights (kg) for the z-score curves.
class GrowthRow {
  final double x;
  final double L;
  final double M;
  final double S;

  final double sd3neg;
  final double sd2neg;
  final double sd1neg;
  final double sd0;
  final double sd1;
  final double sd2;
  final double sd3;

  const GrowthRow({
    required this.x,
    required this.L,
    required this.M,
    required this.S,
    required this.sd3neg,
    required this.sd2neg,
    required this.sd1neg,
    required this.sd0,
    required this.sd1,
    required this.sd2,
    required this.sd3,
  });

  factory GrowthRow.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v is num) ? v.toDouble() : double.parse(v.toString());
    return GrowthRow(
      x: d(j['x']),
      L: d(j['L']),
      M: d(j['M']),
      S: d(j['S']),
      sd3neg: d(j['sd3neg']),
      sd2neg: d(j['sd2neg']),
      sd1neg: d(j['sd1neg']),
      sd0: d(j['sd0']),
      sd1: d(j['sd1']),
      sd2: d(j['sd2']),
      sd3: d(j['sd3']),
    );
  }
}

/// A loaded reference dataset.
class GrowthDataset {
  final List<GrowthRow> rows;
  const GrowthDataset(this.rows);

  double get minX => rows.isEmpty ? 0 : rows.first.x;
  double get maxX => rows.isEmpty ? 0 : rows.last.x;

  double get minY {
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sd3neg).reduce((a, b) => a < b ? a : b);
  }

  double get maxY {
    if (rows.isEmpty) return 0;
    return rows.map((r) => r.sd3).reduce((a, b) => a > b ? a : b);
  }
}

enum GrowthSex { male, female }

enum GrowthRefType { wfl, wfh }

class GrowthRefKey {
  final GrowthSex sex;
  final GrowthRefType type;
  const GrowthRefKey(this.sex, this.type);
}
