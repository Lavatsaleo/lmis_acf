import 'package:flutter/material.dart';

import 'core/anchor_theme.dart';
import 'screens/auth_gate.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';

class LmisApp extends StatelessWidget {
  const LmisApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anchor',
      debugShowCheckedModeBanner: false,
      theme: buildAnchorTheme(brightness: Brightness.light),
      darkTheme: buildAnchorTheme(brightness: Brightness.dark),
      themeMode: ThemeMode.system,
      builder: (context, child) {
        // Screens are designed for phones. On tablets keep them in a readable
        // centred column instead of stretching forms edge to edge, and cap very
        // large system text so layouts stay intact (still up to 1.3x larger).
        final bg = Theme.of(context).scaffoldBackgroundColor;
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: ColoredBox(
            color: bg,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 840),
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
      home: const AuthGate(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home': (_) => const MainShell(),
      },
    );
  }
}
