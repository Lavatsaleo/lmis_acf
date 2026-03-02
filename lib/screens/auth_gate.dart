import 'package:flutter/material.dart';

import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import 'main_shell.dart';
import 'login_screen.dart';

/// Decides whether to show Login or Home based on existing session.
///
/// Offline-first friendly:
/// - If the user already logged in before (token + cached profile), they can continue even if offline.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final TokenStore _tokenStore = const TokenStore();
  final SessionStore _sessionStore = SessionStore();

  bool _loading = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final token = await _tokenStore.readAccessToken();
    final user = await _sessionStore.readUserJson();
    if (!mounted) return;
    setState(() {
      _hasSession = (token != null && token.trim().isNotEmpty && user != null && user.isNotEmpty);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_hasSession) {
      return const MainShell();
    }
    return const LoginScreen();
  }
}
