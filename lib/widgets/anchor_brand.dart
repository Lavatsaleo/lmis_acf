import 'package:flutter/material.dart';

import '../core/colors.dart';

/// Anchor brand helpers (logo mark, full logo, app bar).
///
/// Assets: `assets/images/anchor_mark.png` (icon only, transparent) and
/// `assets/images/anchor_logo.png` (icon + "ANCHOR" wordmark, transparent).

class AnchorLogo extends StatelessWidget {
  final double size;

  /// Adds the "ANCHOR" wordmark next to the mark (for headers with room).
  final bool showText;

  const AnchorLogo({super.key, this.size = 28, this.showText = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final mark = Image.asset(
      'assets/images/anchor_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: showText ? null : 'Anchor',
      errorBuilder: (_, _, _) => Icon(Icons.anchor, color: cs.primary, size: size),
    );

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: size * 0.3),
        const Flexible(child: AnchorWordmark()),
      ],
    );
  }
}

/// "ANCHOR" set in the brand style (the logo uses a wide geometric sans).
class AnchorWordmark extends StatelessWidget {
  final double fontSize;

  const AnchorWordmark({super.key, this.fontSize = 18});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      'ANCHOR',
      maxLines: 1,
      overflow: TextOverflow.fade,
      softWrap: false,
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w800,
        letterSpacing: fontSize * 0.12,
        color: isDark ? Theme.of(context).colorScheme.primary : anchorTeal,
      ),
    );
  }
}

/// Full logo (mark above the wordmark) for the login and splash moments.
class AnchorFullLogo extends StatelessWidget {
  final double width;

  const AnchorFullLogo({super.key, this.width = 140});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/anchor_logo.png',
      width: width,
      fit: BoxFit.contain,
      semanticLabel: 'Anchor',
      errorBuilder: (_, _, _) => const AnchorLogo(size: 56, showText: true),
    );
  }
}

class AnchorAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showLogo;

  const AnchorAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showLogo = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    // Pushed screens get the back button; root screens show the Anchor mark.
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    return AppBar(
      leading: showLogo && !canPop
          ? const Padding(
              padding: EdgeInsets.only(left: 12),
              child: Center(child: AnchorLogo(size: 28)),
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
