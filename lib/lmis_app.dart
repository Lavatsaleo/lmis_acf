import 'package:flutter/material.dart';

import 'core/acf_theme.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

class LmisApp extends StatelessWidget {
  const LmisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LMIS ACF',
      debugShowCheckedModeBanner: false,
      theme: buildAcfTheme(brightness: Brightness.light),
      darkTheme: buildAcfTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}
