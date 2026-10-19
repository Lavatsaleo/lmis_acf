import 'package:flutter/material.dart';

/// Small ACF brand helpers (logo + app bar).
///
/// Note: `assets/images/acf_logo.png` is a placeholder logo shipped with the repo.
/// You can replace that file with the official ACF logo (same filename) without
/// changing any code.

class AcfLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const AcfLogo({super.key, this.size = 28, this.showText = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final logo = Image.asset(
      'assets/images/acf_logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: cs.primaryContainer,
          borderRadius: BorderRadius.circular(size / 3),
        ),
        child: Icon(Icons.favorite, color: cs.onPrimaryContainer, size: size * 0.62),
      ),
    );

    if (!showText) return logo;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        logo,
        const SizedBox(width: 10),
        const Flexible(
          child: Text(
            'Action Against Hunger',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ],
    );
  }
}

class AcfAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;

  const AcfAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: showLogo
          ? Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Center(child: AcfLogo(size: 26)),
            )
          : null,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      actions: actions,
    );
  }
}
