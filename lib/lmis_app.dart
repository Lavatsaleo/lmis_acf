import 'package:flutter/material.dart';

import 'core/acf_theme.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

class LmisApp extends StatelessWidget {
  const LmisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LMIS ACF',
      debugShowCheckedModeBanner: false,
      theme: buildAcfTheme(),
      home: const LoginScreen(), // change to HomeScreen() if needed
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const HomeScreen(),
      },
    );
  }
}
