import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';

/// Action Against Hunger (ACF) theme.
///
/// Goal:
/// - Clean, executive-friendly UI
/// - Consistent spacing + rounded corners
/// - Works well in both Light and Dark mode
ThemeData buildAcfTheme({Brightness brightness = Brightness.light}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: acfBlue,
    brightness: brightness,
  );

  // Ensure we use ACF green as the accent/secondary.
  final scheme = baseScheme.copyWith(secondary: acfGreen);

  final isDark = brightness == Brightness.dark;

  final scaffoldBg = isDark ? const Color(0xFF0B0F17) : const Color(0xFFF6F7F9);
  final cardBg = isDark ? const Color(0xFF121826) : Colors.white;

  final borderColor = isDark ? Colors.white12 : Colors.black12;

  final radius = BorderRadius.circular(16);

  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffoldBg,

    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: scaffoldBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
    ),

    // Flutter uses CardThemeData (not the CardTheme widget) inside ThemeData.
    cardTheme: CardThemeData(
      elevation: 0,
      color: cardBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: borderColor),
      ),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: DividerThemeData(color: borderColor, thickness: 1),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF0F1522) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: inputBorder(borderColor),
      focusedBorder: inputBorder(scheme.primary),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withOpacity(0.8)),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: borderColor),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF121826) : const Color(0xFF111827),
      contentTextStyle: const TextStyle(color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      side: BorderSide(color: borderColor),
      labelStyle: TextStyle(color: scheme.onSurface),
    ),

    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}
