import 'package:flutter/material.dart';
import 'package:lmis_acf/core/colors.dart';

ThemeData buildAcfTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: acfBlue);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
    ),

    // Flutter's ThemeData.cardTheme expects CardThemeData on newer versions.
    // Keep this non-const (safer across Flutter versions) and use const values inside.
    cardTheme: CardThemeData(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        side: BorderSide(color: Colors.black12),
      ),
    ),
  );
}
