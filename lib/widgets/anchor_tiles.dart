import 'package:flutter/material.dart';

/// Consistent, overflow-safe tiles used across the app.

class AcfActionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;
  final Color? iconBg;

  /// If you want all tiles to align nicely in a Row, keep the same height.
  final double minHeight;

  const AcfActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.enabled = true,
    this.onTap,
    this.iconBg,
    this.minHeight = 92,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final bg = enabled ? cs.surface : cs.surfaceVariant.withOpacity(0.55);
    final border = cs.outlineVariant;

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        height: minHeight,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg ?? (enabled ? cs.primaryContainer : cs.surfaceContainerHighest),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: enabled ? cs.onPrimaryContainer : cs.onSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: enabled ? cs.onSurfaceVariant : cs.onSurfaceVariant.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
