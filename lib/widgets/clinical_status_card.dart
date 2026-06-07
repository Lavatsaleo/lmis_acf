import 'package:flutter/material.dart';

import '../utils/clinical/clinical_status.dart';

class ClinicalStatusCard extends StatelessWidget {
  final ClinicalStatusResult? result;
  final String emptyText;

  const ClinicalStatusCard({
    super.key,
    required this.result,
    this.emptyText = 'Enter weight, height and MUAC to calculate clinical status.',
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final r = result;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: r?.isDeteriorating == true || r?.isExitEligible == true ? cs.error : cs.outlineVariant),
      ),
      child: r == null
          ? Row(
              children: [
                const Icon(Icons.insights),
                const SizedBox(width: 10),
                Expanded(child: Text(emptyText, style: const TextStyle(fontWeight: FontWeight.w800))),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(r.isDeteriorating ? Icons.warning_amber_rounded : Icons.health_and_safety_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text('Clinical status', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _StatusLine(label: 'Nutritional status', value: r.nutritionalStatus),
                _StatusLine(label: 'Recovery status', value: r.recoveryStatus),
                _StatusLine(label: 'Progress', value: r.progressStatus),
                _StatusLine(label: 'Exit eligibility', value: r.exitEligibilityStatus),
                _StatusLine(label: 'Programme duration', value: '${r.programmeDurationMonths} months (${r.programmeDurationDays} days)'),
                if (r.alertMessages.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  for (final msg in r.alertMessages)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.notifications_active_outlined, size: 18, color: cs.error),
                          const SizedBox(width: 8),
                          Expanded(child: Text(msg, style: TextStyle(color: cs.error, fontWeight: FontWeight.w800))),
                        ],
                      ),
                    ),
                ],
                if (r.deteriorationReasons.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final reason in r.deteriorationReasons)
                    Padding(
                      padding: const EdgeInsets.only(left: 26, bottom: 4),
                      child: Text('• $reason', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
                    ),
                ],
              ],
            ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final String label;
  final String value;

  const _StatusLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(label, style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}
