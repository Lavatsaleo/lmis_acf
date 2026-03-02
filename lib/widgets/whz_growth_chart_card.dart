import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import '../utils/growth/growth_loader.dart';
import '../utils/growth/growth_models.dart';

class WhzGrowthChartCard extends StatelessWidget {
  final ClinicalChild child;
  final List<ClinicalAssessment> assessments;

  const WhzGrowthChartCard({super.key, required this.child, required this.assessments});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final sex = _parseSex(child.sex);
    // Use latest assessment to decide WFL vs WFH.
    final latest = assessments.isEmpty ? null : assessments.first;
    final ageMonths = (latest != null) ? _ageMonths(child.dateOfBirth, latest.assessmentDate) : null;
    final type = _selectType(ageMonths: ageMonths, heightCm: latest?.heightCm);

    return FutureBuilder<GrowthDataset>(
      future: GrowthLoader.instance.load(GrowthRefKey(sex, type)),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: cs.outlineVariant),
            ),
            child: const Center(child: CircularProgressIndicator()),
          );
        }

        final ds = snap.data!;
        if (ds.rows.isEmpty) {
          return _emptyCard(context, 'Growth reference table is empty');
        }

        // Use ascending order for trend line.
        final points = assessments
            .where((a) => a.heightCm != null && a.weightKg != null)
            .toList()
          ..sort((a, b) => a.assessmentDate.compareTo(b.assessmentDate));

        final childSpots = <FlSpot>[];
        for (final a in points) {
          final x = a.heightCm!;
          final y = a.weightKg!;
          // Only plot if within chart bounds.
          if (x >= ds.minX && x <= ds.maxX && y >= ds.minY && y <= ds.maxY) {
            childSpots.add(FlSpot(x, y));
          }
        }

        if (childSpots.isEmpty) {
          return _emptyCard(context, 'No valid height/weight points to plot yet.');
        }

        final refLines = _buildReferenceLines(context, ds);
        final childLine = _buildChildLine(context, childSpots);

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.show_chart),
                  const SizedBox(width: 8),
                  Text(
                    'WHZ Growth Chart (${type == GrowthRefType.wfl ? 'WFL' : 'WFH'})',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 260,
                child: LineChart(
                  LineChartData(
                    minX: ds.minX,
                    maxX: ds.maxX,
                    minY: ds.minY,
                    maxY: ds.maxY,
                    gridData: FlGridData(show: true),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 5,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toStringAsFixed(0), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10));
                          },
                        ),
                        axisNameWidget: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('Length/Height (cm)', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                        ),
                        axisNameSize: 22,
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2,
                          reservedSize: 40,
                          getTitlesWidget: (value, meta) {
                            return Text(value.toStringAsFixed(0), style: TextStyle(color: cs.onSurfaceVariant, fontSize: 10));
                          },
                        ),
                        axisNameWidget: Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text('Weight (kg)', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                        ),
                        axisNameSize: 24,
                      ),
                    ),
                    borderData: FlBorderData(show: true, border: Border.all(color: cs.outlineVariant)),
                    lineBarsData: [...refLines, childLine],
                    lineTouchData: LineTouchData(
                      enabled: true,
                      touchTooltipData: LineTouchTooltipData(
                        getTooltipItems: (touchedSpots) {
                          // Only show tooltip for child line.
                          return touchedSpots.map<LineTooltipItem?>((s) {
                            if (s.barIndex != refLines.length) return null;
                            return LineTooltipItem(
                              'H: ${s.x.toStringAsFixed(1)} cm\nW: ${s.y.toStringAsFixed(1)} kg',
                              TextStyle(color: cs.onSurface, fontWeight: FontWeight.w800),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Curves show WHO reference lines (-3 to +3 SD). Child points show recorded measurements.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }

  static Widget _emptyCard(BuildContext context, String msg) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Text(msg, style: TextStyle(color: cs.onSurfaceVariant)),
    );
  }

  static GrowthSex _parseSex(String v) {
    final s = v.toUpperCase();
    if (s.contains('FEMALE')) return GrowthSex.female;
    return GrowthSex.male;
  }

  static int? _ageMonths(DateTime? dob, DateTime onDate) {
    if (dob == null) return null;
    int months = (onDate.year - dob.year) * 12 + (onDate.month - dob.month);
    if (onDate.day < dob.day) months -= 1;
    if (months < 0) months = 0;
    return months;
  }

  static GrowthRefType _selectType({required int? ageMonths, required double? heightCm}) {
    if (ageMonths != null) {
      return ageMonths < 24 ? GrowthRefType.wfl : GrowthRefType.wfh;
    }
    if (heightCm != null && heightCm < 87) return GrowthRefType.wfl;
    return GrowthRefType.wfh;
  }

  static List<LineChartBarData> _buildReferenceLines(BuildContext context, GrowthDataset ds) {
    final cs = Theme.of(context).colorScheme;
    final rows = ds.rows;

    List<FlSpot> spotsFor(double Function(GrowthRow r) f) {
      return rows.map((r) => FlSpot(r.x, f(r))).toList();
    }

    LineChartBarData mk(List<FlSpot> s, {bool bold = false}) {
      return LineChartBarData(
        spots: s,
        isCurved: false,
        barWidth: bold ? 2.2 : 1.2,
        color: bold ? cs.primary.withOpacity(0.55) : cs.outline.withOpacity(0.45),
        dotData: const FlDotData(show: false),
      );
    }

    return [
      mk(spotsFor((r) => r.sd3neg)),
      mk(spotsFor((r) => r.sd2neg)),
      mk(spotsFor((r) => r.sd1neg)),
      mk(spotsFor((r) => r.sd0), bold: true),
      mk(spotsFor((r) => r.sd1)),
      mk(spotsFor((r) => r.sd2)),
      mk(spotsFor((r) => r.sd3)),
    ];
  }

  static LineChartBarData _buildChildLine(BuildContext context, List<FlSpot> childSpots) {
    final cs = Theme.of(context).colorScheme;
    return LineChartBarData(
      spots: childSpots,
      isCurved: false,
      barWidth: 2.4,
      color: cs.primary,
      dotData: FlDotData(
        show: true,
        getDotPainter: (spot, percent, bar, index) {
          final isLast = index == childSpots.length - 1;
          return FlDotCirclePainter(
            radius: isLast ? 5 : 3.5,
            color: cs.primary,
            strokeWidth: 2,
            strokeColor: cs.surface,
          );
        },
      ),
    );
  }
}
