import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_api.dart';
import '../widgets/acf_brand.dart';
import '../widgets/app_version_badge.dart';

/// Sign in screen.
///
/// Backend URL is fixed in code and is no longer user-editable.
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
      'facilityCode',
      'facilityName',
    ]).toLowerCase();
    final newFacility = _valueFrom(newUser, [
      'facilityId',
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
      Navigator.pushReplacementNamed(context, '/home');
    } on DioException catch (e) {
      if (!mounted) return;

      final status = e.response?.statusCode;
      final data = e.response?.data;
      String serverMsg = '';
      if (data is Map && data['message'] != null) {
        serverMsg = data['message'].toString();
      }

      final pretty = serverMsg.isNotEmpty
          ? 'Login failed (${status ?? 'no status'}): $serverMsg'
          : 'Login failed (${status ?? 'no status'}): ${e.message ?? e.toString()}';

      _show(pretty);
    } catch (e) {
      if (!mounted) return;
      _show('Login failed: $e');
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

    return Scaffold(
      appBar: const AcfAppBar(title: 'Sign in', showLogo: true),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const AcfLogo(size: 72),
                          const SizedBox(height: 12),
                          const Text(
                            'Action Against Hunger',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'LMIS and Clinical Mobile App',
                            style: TextStyle(
                              fontSize: 13,
                              color: cs.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          const AppVersionBadge(),
                          const SizedBox(height: 8),
                          Text(
                            'Sign in to continue.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Credentials',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _emailCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined),
                            ),
                            keyboardType: TextInputType.emailAddress,
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
                                onPressed: _loggingIn
                                    ? null
                                    : () => setState(() => _hidePassword = !_hidePassword),
                                icon: Icon(
                                  _hidePassword ? Icons.visibility : Icons.visibility_off,
                                ),
                              ),
                            ),
                            obscureText: _hidePassword,
                            enabled: !_loggingIn,
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.lock_outline, size: 18, color: cs.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Powered By AAHDMS',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _loggingIn ? null : _login,
                    icon: _loggingIn
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.login),
                    label: Text(_loggingIn ? 'Signing in...' : 'Sign in'),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _loggingIn ? null : _clearSession,
                    icon: const Icon(Icons.cleaning_services_outlined),
                    label: const Text('Clear local session'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
