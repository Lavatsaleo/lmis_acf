import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/colors.dart';

/// Shared building blocks for a consistent, plain-language interface.

/// Brand gradient used for the login header and the home greeting.
const LinearGradient anchorGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [anchorTealDark, anchorTeal],
);

/// Small title above a group of tiles or a form section.
class AnchorSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AnchorSectionTitle(this.title, {super.key, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: cs.onSurface)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A task the user can start. Shown in a two-column grid on phones.
class AnchorTask {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool needsInternet;

  const AnchorTask({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.needsInternet = false,
  });
}

class AnchorTaskGrid extends StatelessWidget {
  final List<AnchorTask> tasks;
  final bool online;

  const AnchorTaskGrid({super.key, required this.tasks, this.online = true});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final columns = c.maxWidth >= 560 ? 3 : 2;
      final w = (c.maxWidth - 12 * (columns - 1)) / columns;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [for (final t in tasks) SizedBox(width: w, child: _TaskTile(task: t, online: online))],
      );
    });
  }
}

class _TaskTile extends StatelessWidget {
  final AnchorTask task;
  final bool online;

  const _TaskTile({required this.task, required this.online});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final blocked = task.needsInternet && !online;
    return Material(
      color: cs.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: blocked
            ? () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${task.title} needs internet. Connect and try again.')),
                )
            : task.onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 128),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: blocked ? cs.surfaceContainerHighest : cs.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(task.icon, color: blocked ? cs.onSurfaceVariant : cs.primary),
                  ),
                  const Spacer(),
                  if (blocked) Icon(Icons.wifi_off, size: 16, color: cs.onSurfaceVariant),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: blocked ? cs.onSurfaceVariant : cs.onSurface),
              ),
              const SizedBox(height: 3),
              Text(
                task.subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Online / offline indicator.
class AnchorConnectionChip extends StatelessWidget {
  final List<ConnectivityResult> conn;
  final bool onDark;

  const AnchorConnectionChip({super.key, required this.conn, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final online = conn.isNotEmpty && !conn.contains(ConnectivityResult.none);
    final fg = onDark ? Colors.white : (online ? const Color(0xFF1B7F4B) : Theme.of(context).colorScheme.onSurfaceVariant);
    final bg = onDark
        ? Colors.white.withValues(alpha: 0.18)
        : (online ? const Color(0xFF1B7F4B).withValues(alpha: 0.10) : Theme.of(context).colorScheme.surfaceContainerHighest);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(online ? Icons.wifi : Icons.wifi_off, size: 14, color: fg),
          const SizedBox(width: 5),
          Text(online ? 'Online' : 'Offline', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: fg)),
        ],
      ),
    );
  }
}

/// A short explanation or warning inside a screen.
class AnchorNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  final bool warning;

  const AnchorNotice(this.text, {super.key, this.icon = Icons.info_outline, this.warning = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = warning ? const Color(0xFFB45309) : cs.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: cs.onSurface, height: 1.35))),
        ],
      ),
    );
  }
}

/// Numbered step header used in forms ("1  Choose where it goes").
class AnchorStep extends StatelessWidget {
  final int number;
  final String title;
  final String? hint;
  final bool done;

  const AnchorStep({super.key, required this.number, required this.title, this.hint, this.done = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: done ? const Color(0xFF1B7F4B) : cs.primary, shape: BoxShape.circle),
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
                if (hint != null) ...[
                  const SizedBox(height: 2),
                  Text(hint!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Big number with a label (stock figures, sync counts).
class AnchorStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  const AnchorStat({super.key, required this.label, required this.value, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = color ?? cs.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.onSurface)),
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Thousands separators without pulling in intl.
String formatCount(num n) {
  final s = n.round().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0 && s[i - 1] != '-') b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// A readable message for a failed request: the server's own message when it
/// sent one, otherwise a plain explanation (never a raw exception dump).
String friendlyError(Object e, {String action = 'That'}) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && (data['message'] ?? '').toString().trim().isNotEmpty) {
      return data['message'].toString().trim();
    }
    if (e.response == null) return 'No connection to the server. Check your internet and try again.';
    final code = e.response?.statusCode;
    if (code == 401) return 'Your session has ended. Sign in again.';
    if (code == 403) return 'Your account is not allowed to do this.';
    return '$action did not work (server error $code). Try again.';
  }
  final s = e.toString().replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
  return s.length > 200 ? '${s.substring(0, 200)}…' : s;
}
