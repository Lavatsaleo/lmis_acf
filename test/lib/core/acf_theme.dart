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
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.black12),
      ),
    ),
  );
}
