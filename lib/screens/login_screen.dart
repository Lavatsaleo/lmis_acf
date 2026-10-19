import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_api.dart';
import '../core/colors.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';
import '../widgets/app_version_badge.dart';
import 'change_password_screen.dart';

/// Sign in screen.
///
/// Brand header, one sign-in card, and a single footer credit. The backend URL
/// is fixed in code (a test build shows which server it uses).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TokenStore _tokenStore = const TokenStore();
  final SessionStore _sessionStore = SessionStore();
  final SyncQueueRepo _syncQueueRepo = SyncQueueRepo();

  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _loggingIn = false;
  bool _hidePassword = true;

  String _valueFrom(Map<String, dynamic>? json, List<String> keys) {
    if (json == null) return '';
    for (final key in keys) {
      final value = json[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  bool _sameUserAndFacility(
    Map<String, dynamic>? currentUser,
    Map<String, dynamic> newUser,
  ) {
    if (currentUser == null || currentUser.isEmpty) return true;

    final currentUserId = _valueFrom(currentUser, ['id', 'userId']);
    final newUserId = _valueFrom(newUser, ['id', 'userId']);

    final currentEmail = _valueFrom(currentUser, ['email']).toLowerCase();
    final newEmail = _valueFrom(newUser, ['email']).toLowerCase();

    final currentFacility = _valueFrom(currentUser, [
      'facilityId',
      'implementationId',
      'facilityCode',
      'facilityName',
    ]).toLowerCase();
    final newFacility = _valueFrom(newUser, [
      'facilityId',
      'implementationId',
      'facilityCode',
      'facilityName',
    ]).toLowerCase();

    final sameUser = currentUserId.isNotEmpty && newUserId.isNotEmpty
        ? currentUserId == newUserId
        : currentEmail.isNotEmpty && newEmail.isNotEmpty && currentEmail == newEmail;

    final sameFacility = currentFacility.isEmpty ||
        newFacility.isEmpty ||
        currentFacility == newFacility;

    return sameUser && sameFacility;
  }

  Future<void> _login() async {
    if (_loggingIn) return;

    final baseUrl = AppConfig.defaultBaseUrl;
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (email.isEmpty) {
      _show('Email is required');
      return;
    }
    if (password.isEmpty) {
      _show('Password is required');
      return;
    }

    setState(() => _loggingIn = true);
    try {
      final existingUser = await _sessionStore.readUserJson();
      final queueCounts = await _syncQueueRepo.counts();
      final hasUnsentData = queueCounts.pending > 0 || queueCounts.failed > 0;

      final api = ApiClient.create(baseUrl: baseUrl);
      final auth = AuthApi(api);

      final loginRes = await auth.login(email: email, password: password);

      if (loginRes.accessToken.trim().isEmpty || loginRes.refreshToken.trim().isEmpty) {
        throw Exception('Login did not return tokens');
      }

      Map<String, dynamic> userJson = loginRes.user;
      try {
        final me = await auth.fetchMe(accessToken: loginRes.accessToken);
        if (me.isNotEmpty) userJson = me;
      } catch (_) {
        // Keep the login payload if /api/me cannot be reached immediately.
      }

      // Safety guard for shared phones:
      // If there is unsynced local data, do not allow the phone to switch to a
      // different user/facility. Otherwise offline records may sync under the
      // wrong account/facility.
      if (hasUnsentData && !_sameUserAndFacility(existingUser, userJson)) {
        if (!mounted) return;
        _show(
          'This phone has ${queueCounts.pending + queueCounts.failed} unsynced item(s). '
          'Please login with the same facility account and sync first before switching accounts.',
        );
        return;
      }

      await _tokenStore.saveTokens(
        accessToken: loginRes.accessToken,
        refreshToken: loginRes.refreshToken,
      );
      await _sessionStore.saveUserJson(userJson);

      // Important: after a successful login, reset queue retry windows
      // so previously failed/pending items can sync immediately.
      await _syncQueueRepo.resetRetryWindowsForAllPendingAndFailed();

      if (!mounted) return;
      // An admin set this password: the user must choose their own first
      // (the server refuses everything else until they do).
      if (loginRes.user['mustChangePassword'] == true || userJson['mustChangePassword'] == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ChangePasswordScreen(required: true, currentPassword: password),
          ),
        );
        return;
      }
      Navigator.pushReplacementNamed(context, '/home');
    } on DioException catch (e) {
      if (!mounted) return;

      final status = e.response?.statusCode;
      final data = e.response?.data;
      String serverMsg = '';
      if (data is Map && data['message'] != null) {
        serverMsg = data['message'].toString();
      }

      final String pretty;
      if (status == null) {
        pretty = 'Cannot reach the server. Check your internet connection and try again.';
      } else if (status == 401 || status == 400) {
        pretty = 'Wrong email or password.';
      } else if (status == 423) {
        pretty = serverMsg.isNotEmpty ? serverMsg : 'This account is locked for a few minutes after too many wrong passwords.';
      } else if (status == 429) {
        pretty = 'Too many sign-in attempts. Wait a few minutes and try again.';
      } else if (status == 403) {
        pretty = serverMsg.isNotEmpty ? serverMsg : 'This account cannot sign in. Contact your administrator.';
      } else {
        pretty = serverMsg.isNotEmpty ? serverMsg : 'Sign-in failed (error $status). Try again.';
      }

      _show(pretty);
    } catch (e) {
      if (!mounted) return;
      _show('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _loggingIn = false);
    }
  }

  Future<void> _clearSession() async {
    final queueCounts = await _syncQueueRepo.counts();
    final hasUnsentData = queueCounts.pending > 0 || queueCounts.failed > 0;

    if (hasUnsentData) {
      if (!mounted) return;
      _show(
        'Cannot clear session. This phone has ${queueCounts.pending + queueCounts.failed} unsynced item(s). Sync first.',
      );
      return;
    }

    await _tokenStore.clear();
    await _sessionStore.clear();
    if (!mounted) return;
    _show('Session cleared');
  }

  void _show(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand header
            Container(
              decoration: const BoxDecoration(
                gradient: anchorGradient,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
              ),
              padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 36, 24, 64),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: const AnchorFullLogo(width: 112),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Track every box, from warehouse to child',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),

            // Sign-in card, overlapping the header
            Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Sign in', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: cs.onSurface)),
                              const SizedBox(height: 4),
                              Text('Use the email and password from your administrator.',
                                  style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                              if (AppConfig.isTestServer) ...[
                                const SizedBox(height: 12),
                                AnchorNotice('Test server: ${AppConfig.defaultBaseUrl}', icon: Icons.science_outlined, warning: true),
                              ],
                              const SizedBox(height: 18),
                              TextFormField(
                                controller: _emailCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username, AutofillHints.email],
                                autocorrect: false,
                                enabled: !_loggingIn,
                              ),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _passwordCtrl,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    tooltip: _hidePassword ? 'Show password' : 'Hide password',
                                    onPressed: _loggingIn ? null : () => setState(() => _hidePassword = !_hidePassword),
                                    icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                                  ),
                                ),
                                obscureText: _hidePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onFieldSubmitted: (_) => _login(),
                                enabled: !_loggingIn,
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                height: 52,
                                child: FilledButton(
                                  onPressed: _loggingIn ? null : _login,
                                  child: _loggingIn
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                            SizedBox(width: 12),
                                            Text('Signing in…'),
                                          ],
                                        )
                                      : const Text('Sign in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'Forgot your password? Ask your administrator to reset it.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  Text(
                    'by Action Against Hunger',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: isDark ? cs.onSurfaceVariant : anchorInk),
                  ),
                  const SizedBox(height: 4),
                  const AppVersionBadge(),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _loggingIn ? null : _clearSession,
                    style: TextButton.styleFrom(foregroundColor: cs.onSurfaceVariant, textStyle: const TextStyle(fontSize: 12)),
                    child: const Text('Trouble signing in? Reset this phone\'s session'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
