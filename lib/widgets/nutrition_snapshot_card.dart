import 'package:flutter/material.dart';

import '../data/local/isar/clinical_assessment.dart';
import '../data/local/isar/clinical_child.dart';
import '../utils/growth/growth_models.dart';
import '../utils/growth/nutrition_status.dart';
import '../utils/growth/whz_calculator.dart';

class NutritionSnapshotCard extends StatelessWidget {
  final ClinicalChild child;
  final ClinicalAssessment latest;

  const NutritionSnapshotCard({super.key, required this.child, required this.latest});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final sex = _parseSex(child.sex);
    final ageMonths = _ageMonths(child.dateOfBirth, latest.assessmentDate);

    return FutureBuilder<WhzResult>(
      future: const WhzCalculator().compute(
        sex: sex,
        heightCm: latest.heightCm,
        weightKg: latest.weightKg,
        ageMonths: ageMonths,
      ),
      builder: (context, snap) {
        final whz = snap.data?.z;
        final whzStatus = classifyByWhz(whz);
        final muacStatus = classifyByMuac(latest.muacMm);

        // If one is unknown, use the other; if both known, choose most severe.
        NutritionStatus finalStatus;
        if (whzStatus == NutritionStatus.unknown && muacStatus == NutritionStatus.unknown) {
          finalStatus = NutritionStatus.unknown;
        } else if (whzStatus == NutritionStatus.unknown) {
          finalStatus = muacStatus;
        } else if (muacStatus == NutritionStatus.unknown) {
          finalStatus = whzStatus;
        } else {
          finalStatus = mostSevere(whzStatus, muacStatus);
        }

        final disagree = (whzStatus != NutritionStatus.unknown && muacStatus != NutritionStatus.unknown && whzStatus != muacStatus);
        final color = _statusColor(context, finalStatus);

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
                  Icon(Icons.health_and_safety, color: color),
                  const SizedBox(width: 8),
                  const Text('Nutrition Snapshot', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(_fmtDate(latest.assessmentDate), style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Nutritional status: ${finalStatus.label}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color),
              ),
              const SizedBox(height: 10),

              _metricLine(
                label: 'WHZ',
                value: whz == null ? 'Not available' : '${whz.toStringAsFixed(2)} SD',
                status: whzStatus == NutritionStatus.unknown ? '' : whzStatus.label,
              ),
              const SizedBox(height: 6),
              _metricLine(
                label: 'MUAC',
                value: latest.muacMm == null ? 'Not recorded' : '${latest.muacMm} mm',
                status: muacStatus == NutritionStatus.unknown ? '' : muacStatus.label,
              ),

              if (disagree) ...[
                const SizedBox(height: 10),
                Text(
                  'WHZ and MUAC differ: showing the most severe classification.',
                  style: TextStyle(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic),
                ),
              ],
              if ((snap.data?.outOfRange ?? false) && whz != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Note: height/length is outside the WHO reference range. WHZ may be less reliable.',
                  style: TextStyle(color: cs.onSurfaceVariant),
                ),
              ],
              if ((snap.data?.note ?? '').isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(snap.data!.note!, style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ],
          ),
        );
      },
    );
  }

  static Widget _metricLine({required String label, required String value, required String status}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 54, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900))),
        Expanded(
          child: Text(
            status.isEmpty ? value : '$value → $status',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
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

  static Color _statusColor(BuildContext context, NutritionStatus s) {
    final cs = Theme.of(context).colorScheme;
    switch (s) {
      case NutritionStatus.severeWasting:
        return Colors.red.shade700;
      case NutritionStatus.moderateWasting:
        return Colors.orange.shade700;
      case NutritionStatus.atRiskOfWasting:
        return Colors.amber.shade800;
      case NutritionStatus.normal:
        return cs.primary;
      case NutritionStatus.unknown:
        return cs.onSurfaceVariant;
    }
  }

  static String _fmtDate(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
