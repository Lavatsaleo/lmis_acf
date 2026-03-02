import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import '../core/config/app_config.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_api.dart';
import '../widgets/acf_brand.dart';

/// Step 4: Real login.
///
/// - Uses your backend: POST /api/auth/login
/// - Then fetches enriched profile: GET /api/me
/// - Saves token securely + user profile in prefs
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();
  final TokenStore _tokenStore = const TokenStore();
  final SessionStore _sessionStore = SessionStore();

  final TextEditingController _baseUrlCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();

  bool _loading = true;
  bool _loggingIn = false;
  bool _showAdvanced = false;
  bool _hidePassword = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final baseUrl = await _settingsRepo.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _baseUrlCtrl.text = baseUrl;
      _loading = false;
    });
  }

  Future<void> _login() async {
    if (_loggingIn) return;

    final baseUrl = _baseUrlCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (baseUrl.isEmpty) {
      _show('Backend Base URL is required');
      return;
    }
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
      // Persist baseUrl first.
      await _settingsRepo.setBaseUrl(baseUrl);

      // Fresh login: clear old session/token.
      await _tokenStore.clear();
      await _sessionStore.clear();

      final api = ApiClient.create(baseUrl: baseUrl);
      final auth = AuthApi(api);

      final loginRes = await auth.login(email: email, password: password);
      if (loginRes.token.trim().isEmpty) {
        throw Exception('Login did not return a token');
      }
      await _tokenStore.saveAccessToken(loginRes.token);

      // Fetch enriched session (warehouseId, facilityType, etc.).
      // If this call fails (e.g., transient network issue), we still allow login
      // using the login payload and continue.
      Map<String, dynamic> userJson = loginRes.user;
      try {
        final me = await auth.fetchMe(accessToken: loginRes.token);
        if (me.isNotEmpty) userJson = me;
      } catch (_) {
        // Ignore: we can continue with loginRes.user.
      }

      await _sessionStore.saveUserJson(userJson);

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
    _baseUrlCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: const AcfAppBar(title: 'Sign in', showLogo: true),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const AcfLogo(size: 46),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Welcome back', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Sign in to continue (offline-first, sync later).',
                                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: cs.onSurface),
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
                                      icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                                    ),
                                  ),
                                  obscureText: _hidePassword,
                                  enabled: !_loggingIn,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Card(
                          child: ExpansionTile(
                            initiallyExpanded: _showAdvanced,
                            onExpansionChanged: (v) => setState(() => _showAdvanced = v),
                            title:                                    Text('Advanced (Backend URL)', style: TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text(
                              _baseUrlCtrl.text.trim().isEmpty ? 'Not set' : _baseUrlCtrl.text.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _baseUrlCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'Backend Base URL',
                                        hintText: AppConfig.defaultBaseUrl,
                                        prefixIcon: Icon(Icons.link),
                                      ),
                                      keyboardType: TextInputType.url,
                                      enabled: !_loggingIn,
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Tip: Emulator uses http://10.0.2.2:PORT. On a real phone, use your PC LAN IP.\n'
                                      'Example: http://192.168.1.10:8080',
                                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        FilledButton.icon(
                          onPressed: _loggingIn ? null : _login,
                          icon: _loggingIn
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.login),
                          label:                                    Text('Sign in'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _loggingIn ? null : _clearSession,
                          icon: const Icon(Icons.delete_outline),
                          label:                                    Text('Clear saved session'),
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
