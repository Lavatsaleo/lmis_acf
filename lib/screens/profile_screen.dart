import 'package:flutter/material.dart';

import '../data/local/auth/session_store.dart';
import '../data/local/auth/token_store.dart';
import '../data/local/settings/app_settings_repo.dart';
import '../widgets/acf_brand.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SessionStore _sessionStore = SessionStore();
  final TokenStore _tokenStore = const TokenStore();
  final AppSettingsRepo _settingsRepo = AppSettingsRepo();

  bool _loading = true;
  Map<String, dynamic>? _me;
  String _baseUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final me = await _sessionStore.readUserJson();
    final baseUrl = await _settingsRepo.getBaseUrl();
    if (!mounted) return;
    setState(() {
      _me = me;
      _baseUrl = baseUrl;
      _loading = false;
    });
  }

  Future<void> _logout() async {
    await _tokenStore.clear();
    await _sessionStore.clear();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final me = _me ?? <String, dynamic>{};
    final name = (me['name'] ?? me['email'] ?? 'User').toString();
    final email = (me['email'] ?? '').toString();
    final role = (me['role'] ?? '').toString();
    final facilityName = (me['facilityName'] ?? '').toString();

    return Scaffold(
      appBar: AcfAppBar(
        title: 'Profile',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const AcfLogo(size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        if (email.isNotEmpty) Text(email, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        if (role.isNotEmpty) Text(role, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        if (facilityName.isNotEmpty)
                          Text(facilityName, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backend', style: TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(height: 6),
                  Text(
                    _baseUrl,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'To change the backend URL, go to Login screen → Advanced settings.',
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(height: 14),
          Text(
            'Next: we will add “Register Boxes” against your existing Box table (no duplication), then add Warehouse Receive + Adjustment, and finally link to clinical dispensing + in-depth assessment.',
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
