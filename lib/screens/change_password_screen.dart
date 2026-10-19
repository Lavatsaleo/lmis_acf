import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../core/config/app_config.dart';
import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/sync/sync_queue_repo.dart';
import '../data/remote/api_client.dart';
import '../data/remote/auth_api.dart';
import '../widgets/anchor_brand.dart';
import '../widgets/anchor_ui.dart';

/// Lets the signed-in user choose their own password.
///
/// [required] is true when an admin created the account or reset its password:
/// the server blocks everything else until this is done, so there is no way
/// back except signing out. Otherwise it is opened from the profile screen.
class ChangePasswordScreen extends StatefulWidget {
  final bool required;

  /// The password just used to sign in, so the user is not asked for it twice.
  final String? currentPassword;

  const ChangePasswordScreen({
    super.key,
    this.required = false,
    this.currentPassword,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TokenStore _tokenStore = const TokenStore();
  final SessionStore _sessionStore = SessionStore();
  final SyncQueueRepo _syncQueueRepo = SyncQueueRepo();

  late final TextEditingController _currentCtrl =
      TextEditingController(text: widget.currentPassword ?? '');
  final TextEditingController _newCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  bool _saving = false;
  bool _hide = true;
  String? _error;

  bool get _knowsCurrent => (widget.currentPassword ?? '').isNotEmpty;

  Future<void> _save() async {
    if (_saving) return;
    final current = _currentCtrl.text;
    final next = _newCtrl.text;

    String? problem;
    if (current.isEmpty) problem = 'Enter your current password.';
    if (problem == null && next.length < 8) problem = 'The new password must be at least 8 characters.';
    if (problem == null && next != _confirmCtrl.text) problem = 'The new passwords do not match.';
    if (problem == null && next == current) problem = 'Choose a password different from the current one.';
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final api = ApiClient.create(baseUrl: AppConfig.defaultBaseUrl);
      final result = await AuthApi(api).changePassword(currentPassword: current, newPassword: next);

      // Every other session was signed out; keep this one with the new tokens.
      await _tokenStore.saveTokens(accessToken: result.accessToken, refreshToken: result.refreshToken);
      final existing = await _sessionStore.readUserJson() ?? <String, dynamic>{};
      await _sessionStore.saveUserJson({...existing, ...result.user, 'mustChangePassword': false});
      await _syncQueueRepo.resetRetryWindowsForAllPendingAndFailed();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed')));
      if (widget.required) {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
      } else {
        Navigator.of(context).pop();
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final message = data is Map && data['message'] != null
          ? data['message'].toString()
          : 'Could not change the password. Check your connection and try again.';
      if (mounted) setState(() => _error = message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not change the password: ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    final counts = await _syncQueueRepo.counts();
    if (counts.pending > 0 || counts.failed > 0) {
      if (!mounted) return;
      setState(() => _error =
          'This phone has ${counts.pending + counts.failed} unsynced item(s). Change your password so they can sync before signing out.');
      return;
    }
    await _tokenStore.clear();
    await _sessionStore.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: IconButton(
          tooltip: _hide ? 'Show passwords' : 'Hide passwords',
          onPressed: () => setState(() => _hide = !_hide),
          icon: Icon(_hide ? Icons.visibility : Icons.visibility_off),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !widget.required,
      child: Scaffold(
        appBar: widget.required ? null : const AnchorAppBar(title: 'Change password'),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.required) ...[
                      const SizedBox(height: 12),
                      const Center(child: AnchorFullLogo(width: 120)),
                      const SizedBox(height: 20),
                    ],
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              widget.required ? 'Set your own password' : 'Change password',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: cs.onSurface),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.required
                                  ? 'Your password was set by an administrator. Choose a new one that only you know before continuing.'
                                  : 'You will stay signed in on this phone. Other devices will be signed out.',
                              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
                            ),
                            const SizedBox(height: 14),
                            if (!_knowsCurrent) ...[
                              TextField(
                                controller: _currentCtrl,
                                obscureText: _hide,
                                enabled: !_saving,
                                decoration: _decoration('Current password', Icons.lock_outline),
                              ),
                              const SizedBox(height: 12),
                            ],
                            TextField(
                              controller: _newCtrl,
                              obscureText: _hide,
                              enabled: !_saving,
                              decoration: _decoration('New password', Icons.lock_reset),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _confirmCtrl,
                              obscureText: _hide,
                              enabled: !_saving,
                              decoration: _decoration('Confirm new password', Icons.lock_reset),
                              onSubmitted: (_) => _save(),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'At least 8 characters.',
                              style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: cs.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(_error!, style: TextStyle(color: cs.onErrorContainer)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving...' : 'Save new password'),
                    ),
                    if (widget.required) ...[
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _saving ? null : _signOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
