import 'package:flutter/material.dart';
import 'package:lmis_acf/core/acf_theme.dart';
import 'package:lmis_acf/screens/home_screen.dart';

class LmisApp extends StatelessWidget {
  const LmisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LMIS ACF',
      debugShowCheckedModeBanner: false,
      theme: buildAcfTheme(),
      home: const HomeScreen(),
    );
  }
}
